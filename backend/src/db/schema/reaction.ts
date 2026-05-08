import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  unique,
  index,
} from "drizzle-orm/pg-core";
import { posts } from "./post.js";
import { users } from "./user.js";

export const reactions = pgTable(
  "reactions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    postId: uuid("post_id")
      .references(() => posts.id, { onDelete: "cascade" })
      .notNull(),
    userId: uuid("user_id")
      .references(() => users.id, { onDelete: "cascade" })
      .notNull(),
    // varchar(64) accommodates ZWJ sequences (family / profession glyphs),
    // skin-tone modifiers, regional indicators, and variation selectors
    // while still capping the unique-keyed row's emoji column. The
    // application-layer limit lives in `validators.ts > MAX_EMOJI_LENGTH`
    // — keep both in sync.
    emoji: varchar("emoji", { length: 64 }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [
    unique().on(t.postId, t.userId, t.emoji),
    // The unique constraint above creates an index ordered by
    // (post_id, user_id, emoji), but the aggregate query
    // `Post.reactionCounts` (`WHERE post_id = ? GROUP BY emoji ORDER BY
    // count(*) DESC LIMIT 5`) filters on post_id alone. A dedicated
    // single-column index keeps that path cheap as the table grows and
    // as `varchar(64)` makes the unique-index entries up to 6.4× wider
    // than under the previous `varchar(10)`.
    index("reactions_post_id_idx").on(t.postId),
  ],
);
