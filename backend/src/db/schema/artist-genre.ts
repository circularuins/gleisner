import { pgTable, uuid, integer, primaryKey } from "drizzle-orm/pg-core";
import { artists } from "./artist.js";
import { genres } from "./genre.js";

export const artistGenres = pgTable(
  "artist_genres",
  {
    artistId: uuid("artist_id")
      .references(() => artists.id, { onDelete: "cascade" })
      .notNull(),
    genreId: uuid("genre_id")
      .references(() => genres.id, { onDelete: "cascade" })
      .notNull(),
    position: integer("position").default(0).notNull(),
  },
  (t) => [primaryKey({ columns: [t.artistId, t.genreId] })],
);
