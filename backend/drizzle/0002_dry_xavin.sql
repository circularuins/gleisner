CREATE TABLE "constellations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(100) NOT NULL,
	"artist_id" uuid NOT NULL,
	"anchor_post_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "constellations_anchor_post_id_unique" UNIQUE("anchor_post_id")
);
--> statement-breakpoint
ALTER TABLE "posts" DROP CONSTRAINT "posts_track_id_tracks_id_fk";
--> statement-breakpoint
ALTER TABLE "posts" ALTER COLUMN "track_id" DROP NOT NULL;--> statement-breakpoint
ALTER TABLE "constellations" ADD CONSTRAINT "constellations_artist_id_artists_id_fk" FOREIGN KEY ("artist_id") REFERENCES "public"."artists"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "constellations" ADD CONSTRAINT "constellations_anchor_post_id_posts_id_fk" FOREIGN KEY ("anchor_post_id") REFERENCES "public"."posts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "posts" ADD CONSTRAINT "posts_track_id_tracks_id_fk" FOREIGN KEY ("track_id") REFERENCES "public"."tracks"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "unique_artist_track_name" ON "tracks" USING btree ("artist_id",lower("name"));