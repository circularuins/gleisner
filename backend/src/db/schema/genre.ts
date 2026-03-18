import { pgTable, uuid, varchar, boolean, timestamp } from "drizzle-orm/pg-core";

export const genres = pgTable("genres", {
  id: uuid("id").defaultRandom().primaryKey(),
  name: varchar("name", { length: 50 }).unique().notNull(),
  normalizedName: varchar("normalized_name", { length: 50 }).unique().notNull(),
  isPromoted: boolean("is_promoted").default(false).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
