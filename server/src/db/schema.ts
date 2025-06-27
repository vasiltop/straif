import { uuid, pgTable, primaryKey, varchar, text, timestamp, pgEnum, integer, customType, bigint } from "drizzle-orm/pg-core";

const bytea = customType<{ data: Buffer; notNull: false; default: false }>({
  dataType() {
    return "bytea";
  },
});

export const runs = pgTable("runs", {
	time_ms: integer("time_ms").notNull(),
	recording: text().notNull(),
	map_name: text("map_name").notNull(),
	steam_id: bigint("steam_id", { mode: "number" }).notNull(),
	username: text("username").notNull(),
	created_at: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
}, (table) => [
	primaryKey({ columns: [table.map_name, table.steam_id] }),
]);
