import assert from 'node:assert/strict';
import test from 'node:test';
import {
  bestPerPlayer,
  compareEndlessEntries,
  sortEndlessEntries,
  type EndlessEntry,
} from './endless_leaderboard';

test('sortEndlessEntries orders by blocks desc then steam id', () => {
  const entries: EndlessEntry[] = [
    {
      steam_id: 'steam-b',
      username: 'Bravo',
      blocks_reached: 40,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-a',
      username: 'Alpha',
      blocks_reached: 40,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-c',
      username: 'Charlie',
      blocks_reached: 120,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
  ];

  assert.deepEqual(
    sortEndlessEntries(entries).map((e) => e.steam_id),
    ['steam-c', 'steam-a', 'steam-b']
  );
});

test('compareEndlessEntries is a strict ordering', () => {
  assert.ok(
    compareEndlessEntries(
      { steam_id: 'x', blocks_reached: 100 },
      { steam_id: 'y', blocks_reached: 50 }
    ) < 0
  );
  assert.equal(
    compareEndlessEntries(
      { steam_id: 'x', blocks_reached: 50 },
      { steam_id: 'x', blocks_reached: 50 }
    ),
    0
  );
});

test('bestPerPlayer keeps each player highest run', () => {
  const leaderboard = bestPerPlayer([
    {
      steam_id: 'steam-1',
      username: 'One',
      blocks_reached: 30,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-1',
      username: 'One',
      blocks_reached: 75,
      created_at: new Date('2026-01-02T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-2',
      username: 'Two',
      blocks_reached: 60,
      created_at: new Date('2026-01-03T00:00:00.000Z'),
    },
  ]);

  assert.deepEqual(
    leaderboard.map((e) => [e.steam_id, e.blocks_reached]),
    [
      ['steam-1', 75],
      ['steam-2', 60],
    ]
  );
});
