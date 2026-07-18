import assert from 'node:assert/strict';
import test from 'node:test';
import {
  LeaderboardPaginationQuery,
  get_leaderboard_offset,
  paginate_leaderboard,
} from './leaderboard_pagination';

test('leaderboard pagination preserves the compatibility defaults', () => {
  assert.deepEqual(LeaderboardPaginationQuery.parse({}), {
    page: 0,
    limit: 10,
  });
});

test('leaderboard pagination coerces valid query strings', () => {
  assert.deepEqual(
    LeaderboardPaginationQuery.parse({ page: '2', limit: '25' }),
    { page: 2, limit: 25 }
  );
});

test('leaderboard pagination rejects invalid and excessive values', () => {
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '-1', limit: '25' }).success,
    false
  );
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '0', limit: '0' }).success,
    false
  );
  assert.equal(
    LeaderboardPaginationQuery.safeParse({ page: '0', limit: '101' }).success,
    false
  );
});

test('get_leaderboard_offset uses zero-based pages', () => {
  assert.equal(get_leaderboard_offset({ page: 3, limit: 25 }), 75);
});

test('leaderboard pagination accepts the website page size', () => {
  const parsed = LeaderboardPaginationQuery.parse({
    page: '1',
    limit: '25',
  });

  assert.equal(parsed.limit, 25);
  assert.equal(get_leaderboard_offset(parsed), 25);
});

test('paginate_leaderboard preserves order and reports the unsliced total', () => {
  const result = paginate_leaderboard(
    ['first', 'second', 'third', 'fourth', 'fifth'],
    { page: 1, limit: 2 }
  );

  assert.deepEqual(result, {
    rows: ['third', 'fourth'],
    total: 5,
  });
});

test('paginate_leaderboard can expose every overall entry across pages', () => {
  const entries = Array.from({ length: 53 }, (_, index) => ({
    rank: index + 1,
  }));

  const first = paginate_leaderboard(entries, { page: 0, limit: 25 });
  const last = paginate_leaderboard(entries, { page: 2, limit: 25 });

  assert.equal(first.rows.length, 25);
  assert.equal(last.rows.length, 3);
  assert.equal(last.rows[0].rank, 51);
  assert.equal(last.total, 53);
});
