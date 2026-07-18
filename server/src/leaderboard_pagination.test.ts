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
