import { GraphQLError } from "graphql";
import { builder } from "../builder.js";
import { UserType, type UserShape, userColumns } from "./user.js";
import { db } from "../../db/index.js";
import { users } from "../../db/schema/index.js";
import { eq } from "drizzle-orm";
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
      },
      resolve: async (_parent, args) => {
        // Validate
        if (args.email.length > 255) {
          throw new GraphQLError("Email must be 255 characters or less");
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(args.email)) {
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

        // Generate keys and credentials
        const { publicKey, privateKey } = generateEdKeyPair();
        const passwordSalt = generateSalt();
        const encryptionSalt = generateSalt();
        const passwordHashValue = hashPassword(args.password, passwordSalt);
        const encryptedPrivateKey = encryptPrivateKey(
          privateKey,
          args.password,
          encryptionSalt,
        );

        // Insert user — DID uses the generated UUID
        const [{ id: userId }] = await db
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
            did: "pending", // Temporary, updated after we have the ID
          })
          .returning({ id: users.id });

        // Update DID and return safe columns in one query
        const did = generateDid(userId);
        const [safeUser] = await db
          .update(users)
          .set({ did })
          .where(eq(users.id, userId))
          .returning(userColumns);

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

        // Strip password fields via destructuring
        const { passwordSalt: _ps, passwordHash: _ph, ...user } = row;
        const token = await signToken(user.id);
        return { token, user };
      },
    }),
  }),
});
