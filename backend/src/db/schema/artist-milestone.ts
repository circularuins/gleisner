import {
  pgTable,
  uuid,
  varchar,
  text,
  integer,
  timestamp,
  date,
  pgEnum,
  index,
} from "drizzle-orm/pg-core";
import { artists } from "./artist.js";

export const milestoneCategoryEnum = pgEnum("milestone_category", [
  "award",
  "release",
  "event",
  "affiliation",
  "education",
  "other",
]);

export const artistMilestones = pgTable(
  "artist_milestones",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    artistId: uuid("artist_id")
      .references(() => artists.id, { onDelete: "cascade" })
      .notNull(),
    category: milestoneCategoryEnum("category").notNull(),
    title: varchar("title", { length: 255 }).notNull(),
    description: text("description"),
    date: date("date").notNull(),
    position: integer("position").default(0).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [index("artist_milestones_artist_id_idx").on(table.artistId)],
);
