import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildAimOverallLeaderboard,
  parseAimScenario,
  sortAimScoreEntries,
  type AimScoreEntry,
} from './aim_leaderboard';

test('parseAimScenario accepts only supported aim scenarios', () => {
  assert.equal(parseAimScenario('gridshot'), 'gridshot');
  assert.equal(parseAimScenario('flick'), 'flick');
  assert.equal(parseAimScenario('tracking'), 'tracking');
  assert.equal(parseAimScenario('GRIDSHOT'), null);
  assert.equal(parseAimScenario('target'), null);
  assert.equal(parseAimScenario(''), null);
});

test('sortAimScoreEntries orders ties deterministically', () => {
  const entries: AimScoreEntry[] = [
    {
      steam_id: 'steam-c',
      username: 'Charlie',
      scenario: 'gridshot',
      score: 250,
      hits: 100,
      misses: 10,
      accuracy: 90,
      avg_reaction_ms: 300,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-b',
      username: 'Bravo',
      scenario: 'gridshot',
      score: 250,
      hits: 100,
      misses: 10,
      accuracy: 90,
      avg_reaction_ms: 250,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-a',
      username: 'Alpha',
      scenario: 'gridshot',
      score: 250,
      hits: 100,
      misses: 10,
      accuracy: 95,
      avg_reaction_ms: 350,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-d',
      username: 'Delta',
      scenario: 'gridshot',
      score: 260,
      hits: 105,
      misses: 8,
      accuracy: 88,
      avg_reaction_ms: 320,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-aa',
      username: 'Alpha Again',
      scenario: 'gridshot',
      score: 250,
      hits: 100,
      misses: 10,
      accuracy: 90,
      avg_reaction_ms: 250,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
  ];

  assert.deepEqual(
    sortAimScoreEntries(entries).map((entry) => entry.steam_id),
    ['steam-d', 'steam-a', 'steam-aa', 'steam-b', 'steam-c']
  );
});

test('buildAimOverallLeaderboard aggregates totals and averages per player', () => {
  const leaderboard = buildAimOverallLeaderboard([
    {
      steam_id: 'steam-1',
      username: 'Player Zeta',
      scenario: 'gridshot',
      score: 100,
      hits: 50,
      misses: 5,
      accuracy: 90,
      avg_reaction_ms: 220,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-1',
      username: 'Player One',
      scenario: 'flick',
      score: 150,
      hits: 60,
      misses: 6,
      accuracy: 80,
      avg_reaction_ms: 200,
      created_at: new Date('2026-01-02T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-1',
      username: 'Player Alpha',
      scenario: 'tracking',
      score: 200,
      hits: 70,
      misses: 7,
      accuracy: 100,
      avg_reaction_ms: 180,
      created_at: new Date('2026-01-03T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-2',
      username: 'Player Two',
      scenario: 'gridshot',
      score: 300,
      hits: 80,
      misses: 8,
      accuracy: 75,
      avg_reaction_ms: 210,
      created_at: new Date('2026-01-03T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-2',
      username: 'Player Two',
      scenario: 'flick',
      score: 150,
      hits: 55,
      misses: 5,
      accuracy: 80,
      avg_reaction_ms: 215,
      created_at: new Date('2026-01-03T00:00:00.000Z'),
    },
  ]);

  assert.deepEqual(leaderboard, [
    {
      steam_id: 'steam-1',
      username: 'Player Zeta',
      total_score: 450,
      scenarios_completed: 3,
      accuracy: 90,
      avg_reaction_ms: 200,
    },
    {
      steam_id: 'steam-2',
      username: 'Player Two',
      total_score: 450,
      scenarios_completed: 2,
      accuracy: 77.5,
      avg_reaction_ms: 212.5,
    },
  ]);
});
