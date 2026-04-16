CREATE TABLE "post_media" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"post_id" uuid NOT NULL,
	"media_url" text NOT NULL,
	"position" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "post_media" ADD CONSTRAINT "post_media_post_id_posts_id_fk" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "post_media_post_id_position_idx" ON "post_media" USING btree ("post_id","position");--> statement-breakpoint
-- Backfill: migrate existing image posts' mediaUrl to post_media
INSERT INTO "post_media" ("post_id", "media_url", "position")
SELECT "id", "media_url", 0 FROM "posts"
WHERE "media_type" = 'image' AND "media_url" IS NOT NULL;