-- Step 1: Convert column to text temporarily
ALTER TABLE "posts" ALTER COLUMN "media_type" SET DATA TYPE text;--> statement-breakpoint

-- Step 2: Migrate existing 'text' posts to thought/article
-- article: has title OR uses delta format
-- thought: everything else (short plain text)
UPDATE "posts" SET "media_type" = 'article'
  WHERE "media_type" = 'text' AND ("title" IS NOT NULL OR "body_format" = 'delta');--> statement-breakpoint
UPDATE "posts" SET "media_type" = 'thought'
  WHERE "media_type" = 'text';--> statement-breakpoint

-- Step 3: Replace enum type
DROP TYPE "public"."media_type";--> statement-breakpoint
CREATE TYPE "public"."media_type" AS ENUM('thought', 'article', 'image', 'video', 'audio', 'link');--> statement-breakpoint

-- Step 4: Cast back to enum (all values are now valid)
ALTER TABLE "posts" ALTER COLUMN "media_type" SET DATA TYPE "public"."media_type" USING "media_type"::"public"."media_type";--> statement-breakpoint

-- Step 5: Add new columns
ALTER TABLE "posts" ADD COLUMN "article_genre" varchar(20);--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "external_publish" boolean DEFAULT false NOT NULL;
