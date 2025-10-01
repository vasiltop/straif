import {
  pgTable,
  primaryKey,
  text,
  timestamp,
  integer,
  pgEnum,
  boolean,
} from 'drizzle-orm/pg-core';

export const run_mode = pgEnum('mode', ['bhop', 'target']);

export const runs = pgTable(
  'runs',
  {
    time_ms: integer('time_ms').notNull(),
    recording: text().notNull(),
    map_name: text('map_name').notNull(),
    steam_id: text('steam_id').notNull(),
    username: text('username').notNull(),
    mode: run_mode().default('target').notNull(),
    created_at: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.map_name, table.steam_id, table.mode] }),
  ]
);

export const admins = pgTable('admins', {
  steam_id: text('steam_id').notNull().primaryKey(),
});

export const banned_values = pgTable('banned_values', {
  value: text('value').unique().notNull(), // can either be steam_id or ip
});
