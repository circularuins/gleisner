import { pgTable, uuid, varchar, text, timestamp } from "drizzle-orm/pg-core";
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
  headerImageUrl: text("header_image_url"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
