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
      },
      resolve: async (_parent, args) => {
        // Validate
        if (args.password.length < 8) {
          throw new GraphQLError("Password must be at least 8 characters");
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
