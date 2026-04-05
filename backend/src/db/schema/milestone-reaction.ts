import { pgTable, uuid, varchar, timestamp, unique } from "drizzle-orm/pg-core";
import { artistMilestones } from "./artist-milestone.js";
import { users } from "./user.js";

export const milestoneReactions = pgTable(
  "milestone_reactions",
  {
    id: uuid("id").defaultRandom().primaryKey(),
    milestoneId: uuid("milestone_id")
      .references(() => artistMilestones.id, { onDelete: "cascade" })
      .notNull(),
    userId: uuid("user_id")
      .references(() => users.id, { onDelete: "cascade" })
      .notNull(),
    emoji: varchar("emoji", { length: 10 }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [unique().on(t.milestoneId, t.userId, t.emoji)],
);
