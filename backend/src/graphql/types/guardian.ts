import { GraphQLError } from "graphql";
import { randomBytes } from "node:crypto";
import { builder } from "../builder.js";
import { UserType, type UserShape, userColumns } from "./user.js";
import { db } from "../../db/index.js";
import { users } from "../../db/schema/index.js";
import { and, eq, sql } from "drizzle-orm";
import {
  generateEdKeyPair,
  generateSalt,
  verifyPassword,
  encryptPrivateKey,
} from "../../auth/crypto.js";
import { generateDid } from "../../auth/did.js";
import { signToken } from "../../auth/jwt.js";

const MAX_PASSWORD_LENGTH = 128;

const MAX_CHILDREN_PER_GUARDIAN = 10;
const CHILD_EMAIL_DOMAIN = "@child.gleisner.local";
const BIRTH_YEAR_MONTH_REGEX = /^\d{4}-(0[1-9]|1[0-2])$/;

function validateBirthYearMonth(value: string): void {
  if (!BIRTH_YEAR_MONTH_REGEX.test(value)) {
    throw new GraphQLError("birthYearMonth must be in YYYY-MM format");
  }
  const year = parseInt(value.split("-")[0]);
  const currentYear = new Date().getFullYear();
  if (year < 1900 || year > currentYear) {
    throw new GraphQLError("Invalid birth year");
  }
}

// --- Payload types (must be defined before mutation fields reference them) ---

const SwitchPayload = builder.objectRef<{
  token: string;
  user: UserShape;
}>("SwitchPayload");

SwitchPayload.implement({
  fields: (t) => ({
    token: t.exposeString("token"),
    user: t.field({ type: UserType, resolve: (parent) => parent.user }),
  }),
});

// --- Queries ---

builder.queryFields((t) => ({
  myChildren: t.field({
    type: [UserType],
    resolve: async (_parent, _args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Child accounts cannot list children
      if (ctx.authUser.guardianId) {
        return [];
      }

      const children = await db
        .select(userColumns)
        .from(users)
        .where(eq(users.guardianId, ctx.authUser.userId));

      return children;
    },
  }),
}));

// --- Mutations ---

builder.mutationFields((t) => ({
  createChildAccount: t.field({
    type: UserType,
    args: {
      username: t.arg.string({ required: true }),
      displayName: t.arg.string(),
      birthYearMonth: t.arg.string({ required: true }),
      guardianPassword: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Child accounts cannot create child accounts (JWT-level check)
      if (ctx.authUser.guardianId) {
        throw new GraphQLError("Child accounts cannot create child accounts");
      }

      // DoS prevention: reject oversized passwords before scrypt
      if (args.guardianPassword.length > MAX_PASSWORD_LENGTH) {
        throw new GraphQLError("Invalid password");
      }

      // Verify guardian's password
      const [guardian] = await db
        .select({
          passwordSalt: users.passwordSalt,
          passwordHash: users.passwordHash,
        })
        .from(users)
        .where(eq(users.id, ctx.authUser.userId))
        .limit(1);
      if (
        !guardian ||
        !verifyPassword(
          args.guardianPassword,
          guardian.passwordSalt,
          guardian.passwordHash,
        )
      ) {
        throw new GraphQLError("Invalid password");
      }

      // Validate username
      if (args.username.length < 2 || args.username.length > 30) {
        throw new GraphQLError("Username must be between 2 and 30 characters");
      }
      if (!/^[a-zA-Z0-9_]+$/.test(args.username)) {
        throw new GraphQLError(
          "Username can only contain letters, numbers, and underscores",
        );
      }
      if (args.displayName != null && args.displayName.length > 50) {
        throw new GraphQLError("Display name must be 50 characters or less");
      }

      // Validate birthYearMonth
      validateBirthYearMonth(args.birthYearMonth);

      // Check username uniqueness
      const existingUsername = await db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.username, args.username))
        .limit(1);
      if (existingUsername.length > 0) {
        throw new GraphQLError("Username already taken");
      }

      // Generate child's key pair (CPU-bound, outside transaction)
      const { publicKey, privateKey } = generateEdKeyPair();
      // Random password hash/salt — child cannot login directly
      const childPasswordSalt = generateSalt();
      const childPasswordHash = randomBytes(64).toString("hex");
      // Encrypt child's private key with guardian's password
      // (preserves the key for future graduation to self-managed account)
      const encryptionSalt = generateSalt();
      const childEncryptedPrivateKey = encryptPrivateKey(
        privateKey,
        args.guardianPassword,
        encryptionSalt,
      );

      const childEmail = `${args.username}${CHILD_EMAIL_DOMAIN}`;

      const child = await db.transaction(async (tx) => {
        // Lock guardian row to prevent TOCTOU on child count
        await tx.execute(
          sql`SELECT 1 FROM users WHERE id = ${ctx.authUser!.userId} FOR UPDATE`,
        );

        // Count existing children
        const [countResult] = await tx
          .select({ count: sql<number>`count(*)::int` })
          .from(users)
          .where(eq(users.guardianId, ctx.authUser!.userId));
        if (countResult.count >= MAX_CHILDREN_PER_GUARDIAN) {
          throw new GraphQLError(
            `Maximum of ${MAX_CHILDREN_PER_GUARDIAN} child accounts allowed`,
          );
        }

        // Insert child user
        const [{ id: childId }] = await tx
          .insert(users)
          .values({
            email: childEmail,
            username: args.username,
            displayName: args.displayName ?? null,
            passwordHash: childPasswordHash,
            passwordSalt: childPasswordSalt,
            publicKey,
            encryptedPrivateKey: childEncryptedPrivateKey,
            encryptionSalt,
            profileVisibility: "private",
            birthYearMonth: args.birthYearMonth,
            guardianId: ctx.authUser!.userId,
            did: "pending",
          })
          .returning({ id: users.id });

        // Generate DID
        const did = generateDid(childId);
        const [childUser] = await tx
          .update(users)
          .set({ did })
          .where(eq(users.id, childId))
          .returning(userColumns);

        return childUser;
      });

      return child;
    },
  }),

  switchToChild: t.field({
    type: SwitchPayload,
    args: {
      childId: t.arg.string({ required: true }),
    },
    resolve: async (_parent, args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Already in child mode — cannot switch again
      if (ctx.authUser.guardianId) {
        throw new GraphQLError(
          "Cannot switch to child while already in child mode",
        );
      }

      // Verify the child belongs to this guardian (single query with both conditions)
      const [child] = await db
        .select(userColumns)
        .from(users)
        .where(
          and(
            eq(users.id, args.childId),
            eq(users.guardianId, ctx.authUser.userId),
          ),
        )
        .limit(1);

      if (!child) {
        throw new GraphQLError("Child account not found");
      }

      const token = await signToken(child.id, {
        guardianId: ctx.authUser.userId,
      });
      return { token, user: child };
    },
  }),

  switchBackToGuardian: t.field({
    type: SwitchPayload,
    args: {},
    resolve: async (_parent, _args, ctx) => {
      if (!ctx.authUser) {
        throw new GraphQLError("Authentication required");
      }

      // Must be in child mode (JWT has gid)
      if (!ctx.authUser.guardianId) {
        throw new GraphQLError(
          "Not in child mode — no guardian to switch back to",
        );
      }

      // Verify guardian still exists
      const [guardian] = await db
        .select(userColumns)
        .from(users)
        .where(eq(users.id, ctx.authUser.guardianId))
        .limit(1);

      if (!guardian || guardian.guardianId !== null) {
        // Guardian must exist and must not itself be a child account
        throw new GraphQLError("Guardian account not found");
      }

      const token = await signToken(guardian.id);
      return { token, user: guardian };
    },
  }),
}));
