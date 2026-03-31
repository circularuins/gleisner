import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  jsonb,
  index,
} from "drizzle-orm/pg-core";

export const analyticsEvents = pgTable(
  "analytics_events",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    eventType: varchar("event_type", { length: 50 }).notNull(),
    userId: uuid("user_id"), // nullable — tracks anonymous visitors too
    sessionId: varchar("session_id", { length: 64 }).notNull(),
    metadata: jsonb("metadata"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    index("analytics_event_type_created_idx").on(
      table.eventType,
      table.createdAt,
    ),
  ],
);
