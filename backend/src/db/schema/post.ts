import { pgTable, uuid, varchar, text, real, integer, timestamp, pgEnum } from "drizzle-orm/pg-core";
import { tracks } from "./track.js";
import { users } from "./user.js";

export const mediaTypeEnum = pgEnum("media_type", [
  "text",
  "image",
  "video",
  "audio",
  "link",
]);

export const posts = pgTable("posts", {
  id: uuid("id").defaultRandom().primaryKey(),
  trackId: uuid("track_id")
    .references(() => tracks.id, { onDelete: "cascade" })
    .notNull(),
  authorId: uuid("author_id")
    .references(() => users.id, { onDelete: "cascade" })
    .notNull(),
  mediaType: mediaTypeEnum("media_type").notNull(),
  title: varchar("title", { length: 100 }),
  body: text("body"),
  mediaUrl: text("media_url"),
  importance: real("importance").default(0.5).notNull(),
  contentHash: varchar("content_hash", { length: 64 }),
  signature: text("signature"),
  layoutX: integer("layout_x").default(0).notNull(),
  layoutY: integer("layout_y").default(0).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});
