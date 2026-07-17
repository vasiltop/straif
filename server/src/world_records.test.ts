import assert from 'node:assert/strict';
import test from 'node:test';
import {
  is_new_world_record,
  RecentWorldRecords,
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

test('uses one stable lock key for a map and mode', () => {
  assert.equal(
    world_record_lock_key('target', 'Taurus'),
    'world-record:target:Taurus'
  );
});

const world_record_input = {
  map_name: 'Taurus',
  mode: 'target',
  steam_id: '123',
  username: 'Alice',
  time_ms: 12_345,
};

test('publishes a world record to the recent cache', () => {
  const cache = new RecentWorldRecords(60_000);
  const record = cache.publish(world_record_input, 1_000);

  assert.deepEqual(cache.list(1_000), [record]);
});

test('assigns each cached world record a unique id', () => {
  const cache = new RecentWorldRecords(60_000);
  const first = cache.publish(world_record_input, 1_000);
  const second = cache.publish(world_record_input, 1_001);

  assert.notEqual(first.id, second.id);
});

test('expires cached world records after the ttl', () => {
  const cache = new RecentWorldRecords(60_000);
  cache.publish(world_record_input, 1_000);

  assert.equal(cache.list(60_999).length, 1);
  assert.equal(cache.list(61_000).length, 0);
});
