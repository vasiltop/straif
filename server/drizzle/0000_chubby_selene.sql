CREATE TYPE "public"."aim_scenario" AS ENUM('gridshot', 'flick', 'tracking');--> statement-breakpoint
CREATE TABLE "aim_scores" (
	"steam_id" text NOT NULL,
	"username" text NOT NULL,
	"scenario" "aim_scenario" NOT NULL,
	"score" integer NOT NULL,
	"hits" integer NOT NULL,
	"misses" integer NOT NULL,
	"accuracy" real NOT NULL,
	"avg_reaction_ms" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "aim_scores_steam_id_scenario_pk" PRIMARY KEY("steam_id","scenario")
);
CREATE INDEX "aim_scores_scenario_score_idx" ON "aim_scores" USING btree ("scenario","score","accuracy","avg_reaction_ms");