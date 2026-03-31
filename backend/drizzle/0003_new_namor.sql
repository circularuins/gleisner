CREATE TABLE "invites" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code" varchar(20) NOT NULL,
	"email" varchar(255),
	"created_by" uuid,
	"used_by" uuid,
	"used_at" timestamp with time zone,
	"expires_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "invites_code_unique" UNIQUE("code")
);
--> statement-breakpoint
ALTER TABLE "artists" ADD COLUMN "profile_visibility" varchar(20) DEFAULT 'public' NOT NULL;--> statement-breakpoint
ALTER TABLE "posts" ADD COLUMN "visibility" varchar(20) DEFAULT 'public' NOT NULL;--> statement-breakpoint
ALTER TABLE "users" ADD COLUMN "profile_visibility" varchar(20) DEFAULT 'public' NOT NULL;--> statement-breakpoint
ALTER TABLE "invites" ADD CONSTRAINT "invites_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "invites" ADD CONSTRAINT "invites_used_by_users_id_fk" FOREIGN KEY ("used_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;