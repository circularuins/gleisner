CREATE TABLE "milestone_reactions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"milestone_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"emoji" varchar(10) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "milestone_reactions_milestone_id_user_id_emoji_unique" UNIQUE("milestone_id","user_id","emoji")
);
--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "event_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "thumbnail_url" text;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "birth_year_month" varchar(7);--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "guardian_id" uuid;--> statement-breakpoint
ALTER TABLE "milestone_reactions" ADD CONSTRAINT "milestone_reactions_milestone_id_artist_milestones_id_fk" FOREIGN KEY ("milestone_id") REFERENCES "public"."artist_milestones"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "milestone_reactions" ADD CONSTRAINT "milestone_reactions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "users" ADD CONSTRAINT "users_guardian_id_users_id_fk" FOREIGN KEY ("guardian_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;