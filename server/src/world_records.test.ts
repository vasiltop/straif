import assert from 'node:assert/strict';
import test from 'node:test';
import {
  is_new_world_record,
  parse_world_record_cursor,
  world_record_lock_key,
} from './world_records';

test('accepts the first run as a world record', () => {
  assert.equal(is_new_world_record(null, 12_345, true), true);
});

test('accepts a strictly faster run as a world record', () => {
  assert.equal(is_new_world_record(12_345, 12_344, true), true);
});

test('rejects an equal run as a world record', () => {
  assert.equal(is_new_world_record(12_345, 12_345, true), false);
});

test('rejects a slower run as a world record', () => {
  assert.equal(is_new_world_record(12_345, 12_346, true), false);
});

test('rejects a run that did not update the player record', () => {
  assert.equal(is_new_world_record(null, 12_345, false), false);
});

test('treats an absent world-record cursor as bootstrap', () => {
  assert.deepEqual(parse_world_record_cursor(undefined), {
    success: true,
    cursor: null,
  });
});

test('accepts a non-negative integer world-record cursor', () => {
  assert.deepEqual(parse_world_record_cursor('42'), {
    success: true,
    cursor: 42,
  });
});

for (const invalid_cursor of ['-1', '1.5', 'record-1', '']) {
  test(`rejects malformed world-record cursor "${invalid_cursor}"`, () => {
    assert.deepEqual(parse_world_record_cursor(invalid_cursor), {
      success: false,
    });
  });
}

test('uses one stable lock key for a map and mode', () => {
  assert.equal(
    world_record_lock_key('target', 'Taurus'),
    'world-record:target:Taurus'
  );
});
