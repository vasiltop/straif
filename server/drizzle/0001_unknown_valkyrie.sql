CREATE TABLE "endless_runs" (
	"map_name" text NOT NULL,
	"steam_id" text NOT NULL,
	"username" text NOT NULL,
	"blocks_reached" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "endless_runs_map_name_steam_id_pk" PRIMARY KEY("map_name","steam_id")
);
--> statement-breakpoint
CREATE INDEX "endless_runs_map_blocks_idx" ON "endless_runs" USING btree ("map_name","blocks_reached");