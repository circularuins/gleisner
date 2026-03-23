import {
  pgTable,
  uuid,
  timestamp,
  pgEnum,
  check,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";
import { posts } from "./post.js";

export const connectionTypeEnum = pgEnum("connection_type", [
  "reply",
  "remix",
  "reference",
  "evolution",
]);

export const connections = pgTable(
  "connections",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    sourceId: uuid("source_id")
      .references(() => posts.id, { onDelete: "cascade" })
      .notNull(),
    targetId: uuid("target_id")
      .references(() => posts.id, { onDelete: "cascade" })
      .notNull(),
    connectionType: connectionTypeEnum("connection_type").notNull(),
    groupId: uuid("group_id"),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [
    check("source_neq_target", sql`${t.sourceId} != ${t.targetId}`),
    uniqueIndex("unique_connection").on(
      t.sourceId,
      t.targetId,
      t.connectionType,
    ),
  ],
);
