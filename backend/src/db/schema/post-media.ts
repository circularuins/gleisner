import {
  pgTable,
  uuid,
  text,
  integer,
  timestamp,
  index,
} from "drizzle-orm/pg-core";
import { posts } from "./post.js";

export const postMedia = pgTable(
  "post_media",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    postId: uuid("post_id")
      .references(() => posts.id, { onDelete: "cascade" })
      .notNull(),
    mediaUrl: text("media_url").notNull(),
    position: integer("position").default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [index("post_media_post_id_position_idx").on(t.postId, t.position)],
);
