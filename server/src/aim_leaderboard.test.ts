import assert from 'node:assert/strict';
import test from 'node:test';
import { parseAimScenario } from './aim_leaderboard';

void test('parseAimScenario accepts only supported aim scenarios', () => {
  assert.equal(parseAimScenario('gridshot'), 'gridshot');
  assert.equal(parseAimScenario('flick'), 'flick');
  assert.equal(parseAimScenario('tracking'), 'tracking');
  assert.equal(parseAimScenario('GRIDSHOT'), null);
  assert.equal(parseAimScenario('target'), null);
  assert.equal(parseAimScenario(''), null);
});
