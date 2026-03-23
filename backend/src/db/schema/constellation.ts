import { pgTable, uuid, varchar, timestamp } from "drizzle-orm/pg-core";
import { artists } from "./artist.js";
import { posts } from "./post.js";

export const constellations = pgTable("constellations", {
  id: uuid("id").defaultRandom().primaryKey(),
  name: varchar("name", { length: 100 }).notNull(),
  artistId: uuid("artist_id")
    .references(() => artists.id, { onDelete: "cascade" })
    .notNull(),
  anchorPostId: uuid("anchor_post_id")
    .references(() => posts.id, { onDelete: "cascade" })
    .notNull()
    .unique(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
});
