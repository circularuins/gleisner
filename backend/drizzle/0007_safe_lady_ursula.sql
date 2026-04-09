ALTER TABLE "posts" ALTER COLUMN "body" SET DATA TYPE jsonb;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "body_format" varchar(10) DEFAULT 'plain' NOT NULL;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "og_title" varchar(200);--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "og_description" text;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "og_image" text;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "og_site_name" varchar(100);--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "og_fetched_at" timestamp with time zone;