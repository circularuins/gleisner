import { pgTable, uuid, varchar, timestamp, index } from "drizzle-orm/pg-core";
import { users } from "./user.js";

export const invites = pgTable(
  "invites",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    code: varchar("code", { length: 20 }).unique().notNull(),
    email: varchar("email", { length: 255 }),
    createdBy: uuid("created_by").references(() => users.id, {
      onDelete: "set null",
    }),
    usedBy: uuid("used_by").references(() => users.id, {
      onDelete: "set null",
    }),
    usedAt: timestamp("used_at", { withTimezone: true }),
    expiresAt: timestamp("expires_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [index("invites_created_by_idx").on(table.createdBy)],
);
