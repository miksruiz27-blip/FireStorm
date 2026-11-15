import assert from 'node:assert/strict';
import { test } from 'node:test';
import { closeness, grid, priority, scoreExperiment } from '../src/scoring.js';

const lunar = { o2_pct: 34, pressure_psia: 8.2, gravity_g: 0.166 };
const exp = { o2_range: [21, 35], pressure_kpa_range: [56.5, 101.3], gravity: 'micro', domain: ['prevention'] };

test('closeness: 1 inside, linear decay outside', () => {
  assert.equal(closeness(25, [20, 30], 10), 1);
  assert.equal(closeness(35, [20, 30], 10), 0.5);
  assert.equal(closeness(99, [20, 30], 10), 0);
});

test('score = .5 conditions + .3 safety + .2 data', () => {
  const { score, score_breakdown: b } = scoreExperiment(lunar, exp, 5, 10);
  assert.equal(b.safety, 0.333);
  assert.equal(b.data, 0.5);
  assert.ok(Math.abs(score - (0.5 * b.conditions + 0.3 * b.safety + 0.2 * b.data)) < 0.002);
});

test('priority peaks with no data, at the habitat, at p = 0.5', () => {
  const at = { o2_pct: 34, gravity_g: 0.166 };
  assert.equal(priority(at, lunar, 0, 0.5).priority, 1);
  assert.ok(priority(at, lunar, 3, 0.5).priority < 1);
  assert.equal(priority(at, lunar, 0, 1).priority, 0);
  assert.equal(grid().length, 27 * 4);
});
