import {
  boolean,
  pgTable,
  primaryKey,
  text,
  timestamp,
  integer,
  pgEnum,
  index,
  real,
} from 'drizzle-orm/pg-core';
import { AIM_SCENARIOS } from '../aim_leaderboard';

export const run_mode = pgEnum('mode', ['bhop', 'target']);
export const aim_scenario = pgEnum('aim_scenario', AIM_SCENARIOS);

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

export const aim_scores = pgTable(
  'aim_scores',
  {
    steam_id: text('steam_id').notNull(),
    username: text('username').notNull(),
    scenario: aim_scenario('scenario').notNull(),
    score: integer('score').notNull(),
    hits: integer('hits').notNull(),
    misses: integer('misses').notNull(),
    accuracy: real('accuracy').notNull(),
    avg_reaction_ms: integer('avg_reaction_ms').notNull(),
    created_at: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.steam_id, table.scenario] }),
    index('aim_scores_scenario_score_idx').on(
      table.scenario,
      table.score,
      table.accuracy,
      table.avg_reaction_ms
    ),
  ]
);

export const admins = pgTable('admins', {
  steam_id: text('steam_id').notNull().primaryKey(),
});

export const endless_runs = pgTable(
  'endless_runs',
  {
    map_name: text('map_name').notNull(),
    steam_id: text('steam_id').notNull(),
    username: text('username').notNull(),
    seed: text('seed').notNull(),
    blocks_reached: integer('blocks_reached').notNull(),
    created_at: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.map_name, table.steam_id] }),
    index('endless_runs_map_blocks_idx').on(
      table.map_name,
      table.blocks_reached
    ),
  ]
);

export const banned_values = pgTable('banned_values', {
  value: text('value').unique().notNull(), // can either be steam_id or ip
});
