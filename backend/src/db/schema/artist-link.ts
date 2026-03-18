import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  timestamp,
  pgEnum,
} from "drizzle-orm/pg-core";
import { artists } from "./artist.js";

export const linkCategoryEnum = pgEnum("link_category", [
  "social",
  "music",
  "video",
  "website",
  "store",
  "other",
]);

export const artistLinks = pgTable("artist_links", {
  id: uuid("id").defaultRandom().primaryKey(),
  artistId: uuid("artist_id")
    .references(() => artists.id, { onDelete: "cascade" })
    .notNull(),
  linkCategory: linkCategoryEnum("link_category").notNull(),
  platform: varchar("platform", { length: 50 }).notNull(),
  url: text("url").notNull(),
  position: integer("position").default(0).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true })
    .defaultNow()
    .notNull(),
});
