import {
  pgTable,
  uuid,
  varchar,
  timestamp,
  unique,
  index,
} from "drizzle-orm/pg-core";
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
    // Mirror `reactions.emoji` (varchar(64)) so the validator (`validateEmoji`)
    // and the two reaction tables stay in lockstep. See `reaction.ts`.
    emoji: varchar("emoji", { length: 64 }).notNull(),
    createdAt: timestamp("created_at", { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (t) => [
    unique().on(t.milestoneId, t.userId, t.emoji),
    // Dedicated milestone_id index for aggregate queries on a single
    // milestone (mirrors `reactions_post_id_idx`).
    index("milestone_reactions_milestone_id_idx").on(t.milestoneId),
  ],
);
