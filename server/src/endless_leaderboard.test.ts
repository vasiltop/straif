import assert from 'node:assert/strict';
import test from 'node:test';
import {
  bestPerPlayer,
  compareEndlessEntries,
  parseSeed,
  sortEndlessEntries,
  type EndlessEntry,
} from './endless_leaderboard';

test('parseSeed accepts only integer strings', () => {
  assert.equal(parseSeed('12345'), '12345');
  assert.equal(parseSeed('-42'), '-42');
  assert.equal(parseSeed('  9007199254740993  '), '9007199254740993');
  assert.equal(parseSeed('1.5'), null);
  assert.equal(parseSeed('abc'), null);
  assert.equal(parseSeed(''), null);
});

test('sortEndlessEntries orders by blocks desc then steam id', () => {
  const entries: EndlessEntry[] = [
    {
      steam_id: 'steam-b',
      username: 'Bravo',
      seed: '1',
      blocks_reached: 40,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-a',
      username: 'Alpha',
      seed: '2',
      blocks_reached: 40,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-c',
      username: 'Charlie',
      seed: '3',
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

test('bestPerPlayer keeps each player highest run and its seed', () => {
  const leaderboard = bestPerPlayer([
    {
      steam_id: 'steam-1',
      username: 'One',
      seed: 'seed-low',
      blocks_reached: 30,
      created_at: new Date('2026-01-01T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-1',
      username: 'One',
      seed: 'seed-high',
      blocks_reached: 75,
      created_at: new Date('2026-01-02T00:00:00.000Z'),
    },
    {
      steam_id: 'steam-2',
      username: 'Two',
      seed: 'seed-two',
      blocks_reached: 60,
      created_at: new Date('2026-01-03T00:00:00.000Z'),
    },
  ]);

  assert.deepEqual(
    leaderboard.map((e) => [e.steam_id, e.blocks_reached, e.seed]),
    [
      ['steam-1', 75, 'seed-high'],
      ['steam-2', 60, 'seed-two'],
    ]
  );
});
