import {
  pgTable,
  uuid,
  varchar,
  text,
  real,
  integer,
  boolean,
  timestamp,
  pgEnum,
  jsonb,
  index,
} from "drizzle-orm/pg-core";
import { tracks } from "./track.js";
import { users } from "./user.js";

export const mediaTypeEnum = pgEnum("media_type", [
  "thought",
  "article",
  "image",
  "video",
  "audio",
  "link",
]);

export const posts = pgTable(
  "posts",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    trackId: uuid("track_id").references(() => tracks.id, {
      onDelete: "set null",
    }),
    authorId: uuid("author_id")
      .references(() => users.id, { onDelete: "cascade" })
      .notNull(),
    mediaType: mediaTypeEnum("media_type").notNull(),
    title: varchar("title", { length: 100 }),
    body: jsonb("body"),
    bodyFormat: varchar("body_format", { length: 10 })
      .default("plain")
      .notNull(),
    mediaUrl: text("media_url"),
    thumbnailUrl: text("thumbnail_url"),
    duration: integer("duration"),
    importance: real("importance").default(0.5).notNull(),
    visibility: varchar("visibility", { length: 20 })
      .default("public")
      .notNull(),
    contentHash: varchar("content_hash", { length: 64 }),
    signature: text("signature"),
    // OGP metadata (auto-fetched for link-type posts, not part of contentHash)
    ogTitle: varchar("og_title", { length: 200 }),
    ogDescription: text("og_description"),
    ogImage: text("og_image"),
    ogSiteName: varchar("og_site_name", { length: 100 }),
    ogFetchedAt: timestamp("og_fetched_at", { withTimezone: true }),
    articleGenre: varchar("article_genre", { length: 20 }),
    externalPublish: boolean("external_publish").default(false).notNull(),
    eventAt: timestamp("event_at", { withTimezone: true }),
    layoutX: integer("layout_x").default(0).notNull(),
    layoutY: integer("layout_y").default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    // OGP rate limit: count recent fetches per author
    index("posts_author_og_fetched_idx").on(table.authorId, table.ogFetchedAt),
    // OGP URL reuse: find existing OGP data for same URL
    index("posts_media_url_og_fetched_idx").on(
      table.mediaUrl,
      table.ogFetchedAt,
    ),
  ],
);
