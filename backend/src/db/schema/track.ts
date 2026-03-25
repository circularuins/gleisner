import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { artists } from "./artist.js";

export const tracks = pgTable(
  "tracks",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    artistId: uuid("artist_id")
      .references(() => artists.id, { onDelete: "cascade" })
      .notNull(),
    name: varchar("name", { length: 30 }).notNull(),
    color: varchar("color", { length: 7 }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [
    uniqueIndex("unique_artist_track_name").using(
      "btree",
      t.artistId,
      sql`lower(${t.name})`,
    ),
  ],
);
