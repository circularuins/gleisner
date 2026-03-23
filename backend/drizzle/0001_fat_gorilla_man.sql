ALTER TABLE "posts" ADD COLUMN "duration" integer;--> statement-breakpoint
CREATE UNIQUE INDEX "unique_connection" ON "connections" USING btree ("source_id","target_id","connection_type");