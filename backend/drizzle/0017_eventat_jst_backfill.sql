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
-- Idempotency:
--   This is a one-shot data fix. Running it twice would double-shift the
--   data. The migration runner records this as applied in
--   drizzle.__drizzle_migrations, so it will not re-run on the same DB.
UPDATE "posts"
SET "event_at" = "event_at" - INTERVAL '9 hours'
WHERE "event_at" IS NOT NULL;
