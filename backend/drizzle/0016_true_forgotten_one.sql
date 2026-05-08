-- Reaction emoji column expansion: varchar(10) -> varchar(64).
--
-- Supports ZWJ family / profession sequences (👨‍👩‍👧‍👦 = 11 code units),
-- skin-tone modifiers, regional indicators, and variation selectors.
-- See `validators.ts > MAX_EMOJI_LENGTH` for the application-layer limit.
--
-- Online safety: PostgreSQL 11+ widens varchar(N) without rewriting the
-- table or rebuilding the row (existing values, all <= 10 chars, fit
-- trivially into the new bound). No USING clause is required because the
-- conversion is purely a metadata change. The unique index
-- (post_id, user_id, emoji) keeps its existing rows; the additional
-- single-column indexes below are CREATE INDEX (not CONCURRENTLY) but
-- their tables are small enough at Phase 0 launch (~10² rows) that the
-- short ACCESS EXCLUSIVE lock is acceptable. Re-evaluate with
-- CREATE INDEX CONCURRENTLY before Phase 1 SNS expansion.
ALTER TABLE "milestone_reactions" ALTER COLUMN "emoji" SET DATA TYPE varchar(64);--> statement-breakpoint
ALTER TABLE "reactions" ALTER COLUMN "emoji" SET DATA TYPE varchar(64);--> statement-breakpoint
CREATE INDEX "milestone_reactions_milestone_id_idx" ON "milestone_reactions" USING btree ("milestone_id");--> statement-breakpoint
CREATE INDEX "reactions_post_id_idx" ON "reactions" USING btree ("post_id");