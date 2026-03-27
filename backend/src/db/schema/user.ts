import { pgTable, uuid, varchar, text, timestamp } from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: uuid("id").defaultRandom().primaryKey(),
  did: varchar("did", { length: 255 }).unique().notNull(),
  email: varchar("email", { length: 255 }).unique().notNull(),
  username: varchar("username", { length: 30 }).unique().notNull(),
  displayName: varchar("display_name", { length: 50 }),
  bio: text("bio"),
  avatarUrl: text("avatar_url"),
  profileVisibility: varchar("profile_visibility", { length: 20 })
    .default("public")
    .notNull(),
  passwordHash: text("password_hash").notNull(),
  passwordSalt: text("password_salt").notNull(),
  publicKey: text("public_key").notNull(),
  encryptedPrivateKey: text("encrypted_private_key").notNull(),
  encryptionSalt: text("encryption_salt").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
});
