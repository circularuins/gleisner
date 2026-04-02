import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { UserType, type UserShape, userColumns } from "./user.js";
import { db } from "../../db/index.js";
import { users, invites } from "../../db/schema/index.js";
import { eq, and, isNull, sql } from "drizzle-orm";
import { env } from "../../env.js";
import {
  generateEdKeyPair,
  generateSalt,
  hashPassword,
  verifyPassword,
  encryptPrivateKey,
} from "../../auth/crypto.js";
import { generateDid } from "../../auth/did.js";
import { signToken } from "../../auth/jwt.js";

const MAX_PASSWORD_LENGTH = 128;

const AuthPayload = builder.objectRef<{
  token: string;
  user: UserShape;
}>("AuthPayload");

AuthPayload.implement({
  fields: (t) => ({
    token: t.exposeString("token"),
    user: t.field({ type: UserType, resolve: (parent) => parent.user }),
  }),
});

builder.mutationType({
  fields: (t) => ({
    signup: t.field({
      type: AuthPayload,
      args: {
        email: t.arg.string({ required: true }),
        password: t.arg.string({ required: true }),
        username: t.arg.string({ required: true }),
        displayName: t.arg.string(),
        inviteCode: t.arg.string(),
      },
      resolve: async (_parent, args) => {
        // Validate
        if (args.email.length > 255) {
          throw new GraphQLError("Email must be 255 characters or less");
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(args.email)) {
          throw new GraphQLError("Invalid email format");
        }
        // Reject child placeholder email domain
        if (args.email.endsWith("@child.gleisner.local")) {
          throw new GraphQLError("Invalid email format");
        }
        if (
          args.password.length < 8 ||
          args.password.length > MAX_PASSWORD_LENGTH
        ) {
          throw new GraphQLError(
            `Password must be between 8 and ${MAX_PASSWORD_LENGTH} characters`,
          );
        }
        if (args.username.length < 2 || args.username.length > 30) {
          throw new GraphQLError(
            "Username must be between 2 and 30 characters",
          );
        }
        if (!/^[a-zA-Z0-9_]+$/.test(args.username)) {
          throw new GraphQLError(
            "Username can only contain letters, numbers, and underscores",
          );
        }
        if (args.displayName != null && args.displayName.length > 50) {
          throw new GraphQLError("Display name must be 50 characters or less");
        }

        // Check uniqueness
        const existing = await db
          .select({ id: users.id })
          .from(users)
          .where(eq(users.email, args.email))
          .limit(1);
        if (existing.length > 0) {
          throw new GraphQLError("Email already registered");
        }

        const existingUsername = await db
          .select({ id: users.id })
          .from(users)
          .where(eq(users.username, args.username))
          .limit(1);
        if (existingUsername.length > 0) {
          throw new GraphQLError("Username already taken");
        }

        // Validate invite code early (when required)
        if (env.REQUIRE_INVITE && !args.inviteCode) {
          throw new GraphQLError("Invite code is required");
        }

        // Generate keys and credentials (CPU-bound, outside transaction)
        const { publicKey, privateKey } = generateEdKeyPair();
        const passwordSalt = generateSalt();
        const encryptionSalt = generateSalt();
        const passwordHashValue = hashPassword(args.password, passwordSalt);
        const encryptedPrivateKey = encryptPrivateKey(
          privateKey,
          args.password,
          encryptionSalt,
        );

        // Transaction: user creation + invite claim are atomic.
        // If invite claim fails, user creation is automatically rolled back.
        const safeUser = await db.transaction(async (tx) => {
          const [{ id: userId }] = await tx
            .insert(users)
            .values({
              email: args.email,
              username: args.username,
              displayName: args.displayName ?? null,
              passwordHash: passwordHashValue,
              passwordSalt,
              publicKey,
              encryptedPrivateKey,
              encryptionSalt,
              did: "pending",
            })
            .returning({ id: users.id });

          const did = generateDid(userId);
          const [user] = await tx
            .update(users)
            .set({ did })
            .where(eq(users.id, userId))
            .returning(userColumns);

          // Atomically claim invite (all conditions in one UPDATE)
          if (env.REQUIRE_INVITE && args.inviteCode) {
            const [claimed] = await tx
              .update(invites)
              .set({ usedBy: userId, usedAt: new Date() })
              .where(
                and(
                  eq(invites.code, args.inviteCode),
                  isNull(invites.usedBy),
                  sql`(${invites.expiresAt} IS NULL OR ${invites.expiresAt} > NOW())`,
                  sql`(${invites.email} IS NULL OR ${invites.email} = ${args.email})`,
                ),
              )
              .returning({ id: invites.id });
            if (!claimed) {
              throw new GraphQLError("Invalid or already used invite code");
            }
          }

          return user;
        });

        const token = await signToken(safeUser.id);
        return { token, user: safeUser };
      },
    }),

    login: t.field({
      type: AuthPayload,
      args: {
        email: t.arg.string({ required: true }),
        password: t.arg.string({ required: true }),
      },
      resolve: async (_parent, args) => {
        // Reject oversized passwords before scrypt computation (DoS prevention)
        if (args.password.length > MAX_PASSWORD_LENGTH) {
          throw new GraphQLError("Invalid credentials");
        }

        // Fetch safe columns + password fields in one query
        const [row] = await db
          .select({
            ...userColumns,
            passwordSalt: users.passwordSalt,
            passwordHash: users.passwordHash,
          })
          .from(users)
          .where(eq(users.email, args.email))
          .limit(1);

        if (
          !row ||
          !verifyPassword(args.password, row.passwordSalt, row.passwordHash)
        ) {
          throw new GraphQLError("Invalid credentials");
        }

        // Child accounts cannot login directly (defense in depth — they also have random passwords)
        if (row.guardianId) {
          throw new GraphQLError("Invalid credentials");
        }

        // Strip password fields via destructuring
        const { passwordSalt: _ps, passwordHash: _ph, ...user } = row;
        const token = await signToken(user.id);
        return { token, user };
      },
    }),
  }),
});
