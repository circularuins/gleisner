-- Backfill posts.event_at to correct the JST-as-UTC bug.
--
-- Background:
--   The Flutter `EventAtPicker` returns a local DateTime (no timezone offset),
--   and the create/edit paths used to call `toIso8601String()` on it directly,
--   producing a naive ISO string like "2026-05-10T13:45:00.000". The backend
--   parsed this with `new Date(...)`, which on a UTC server treats it as UTC,
--   so a user inputting "13:45 JST" got stored as "13:45 UTC" (= 22:45 JST).
--
--   The frontend fix (toUtc().toIso8601String()) lands in the same release.
--   This migration shifts existing event_at values that were captured under
--   the buggy code path back to the user-intended absolute time.
--
-- Scope assumption:
--   Phase 0 launched 2026-05-06 as a family lifelog with all current users
--   in Asia/Tokyo (+09:00). Every event_at row currently in the DB was
--   written by the buggy path, so a uniform `-9 hours` shift restores the
--   intended absolute time for every existing row.
--
--   If/when Phase 1 onboards users in other timezones, this assumption
--   would no longer hold — but by then the buggy code path is gone, so
--   no further backfills are needed.
--
-- Idempotency / scope-limiting:
--   The Drizzle migration runner records this as applied in
--   drizzle.__drizzle_migrations and won't re-run it on the same DB.
--   But that table is per-DB; clones, restored backups, or environments
--   that run the migration after the frontend fix has already shipped
--   could in principle re-execute it. To make the SQL itself idempotent
--   we also gate on `created_at < '<frontend-fix cutoff>'` — rows newer
--   than the cutoff were written by the corrected (toUtc()) code path
--   and must NOT be shifted, regardless of how many times this runs.
--
--   Cutoff: 2026-05-10T12:00:00Z (= 21:00 JST on the day of the fix).
--   The PR is intended to deploy before that local-evening cutoff;
--   anything created after is on the corrected path. If the deploy
--   slips past 21:00 JST, push the cutoff forward and regenerate the
--   migration before applying — do not apply the migration with a
--   cutoff that's already in the past relative to live posts on the
--   buggy code path.
-- Runtime safety net: refuse to run if the cutoff is already in the past
-- relative to the migration apply time. This forces an explicit bump of
-- the cutoff (and a regenerated migration) rather than silently shifting
-- post-deploy rows that are already on the corrected code path.
DO $$
BEGIN
  IF '2026-05-10T12:00:00Z'::timestamptz <= now() THEN
    RAISE EXCEPTION
      'Backfill 0017 aborted: cutoff 2026-05-10T12:00:00Z is no longer in the future (now = %). '
      'Bump the cutoff in this migration to a time after the deploy and regenerate before applying.',
      now();
  END IF;
END $$;
--> statement-breakpoint
UPDATE "posts"
SET "event_at" = "event_at" - INTERVAL '9 hours'
WHERE "event_at" IS NOT NULL
  AND "created_at" < '2026-05-10T12:00:00Z';
