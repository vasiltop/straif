CREATE TABLE "world_records" (
	"id" serial PRIMARY KEY NOT NULL,
	"map_name" text NOT NULL,
	"mode" "mode" NOT NULL,
	"steam_id" text NOT NULL,
	"username" text NOT NULL,
	"time_ms" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
