import { pgTable, uuid, varchar, text, integer, timestamp } from "drizzle-orm/pg-core";
import { users } from "./user.js";

export const artists = pgTable("artists", {
  id: uuid("id").defaultRandom().primaryKey(),
  userId: uuid("user_id")
    .references(() => users.id, { onDelete: "cascade" })
    .unique()
    .notNull(),
  artistUsername: varchar("artist_username", { length: 30 }).unique().notNull(),
  displayName: varchar("display_name", { length: 50 }),
  bio: text("bio"),
  tagline: varchar("tagline", { length: 80 }),
  location: varchar("location", { length: 100 }),
  activeSince: integer("active_since"),
  avatarUrl: text("avatar_url"),
  coverImageUrl: text("cover_image_url"),
  tunedInCount: integer("tuned_in_count").default(0).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
