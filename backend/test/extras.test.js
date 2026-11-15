import assert from 'node:assert/strict';
import { test } from 'node:test';
import { flame } from '../src/flame.js';
import { compose, extraWidgets, recommend } from '../src/genui/extras.js';
import { conditionsFrom } from '../src/genui/rules.js';
import { GenUI } from '../src/schemas.js';

const lunar = { id: 'lunar', name: 'Lunar Base', o2_pct: 34, pressure_psia: 8.2, gravity_g: 0.166 };
const iss = { id: 'iss', name: 'ISS', o2_pct: 21, pressure_psia: 14.7, gravity_g: 0 };
const points = [{ o2_pct: 21, gravity_g: 0, source: 'PSI-25' }, { o2_pct: 30, gravity_g: 0, source: 'PSI-25' }];
const run = (question, h = lunar) => {
  const cond = conditionsFrom(question, h);
  return extraWidgets({ question, habitat: h, cond, forecast: flame(cond), points, habitats: [lunar, iss], lang: 'es' });
};

test('lunar: no partial-g tests → coverage first; metrics always; follow-ups skip what was asked', () => {
  const x = run('¿Qué materiales siguen siendo seguros?');
  assert.match(x.coverage.text, /Fuera de la cobertura/);
  assert.equal(x.metrics.items.length, 5);
  assert.ok(!x.followUps.questions.some((q) => /materiales/.test(q)));
  assert.equal(x.followUps.questions.length, 3);
  assert.equal(run('hola', iss).coverage, undefined); // ISS 21 % at 0 g is tested
});

test('compare → habitat table (current highlighted); validate → next tests from recommend()', () => {
  const t = run('Compara el riesgo entre hábitats').table;
  assert.equal(t.rows.length, 2);
  assert.equal(t.rows[t.highlight][0], 'Base Lunar');
  const n = run('¿Qué experimento falta para validar esto?').next;
  assert.equal(n.items.length, 3);
  assert.equal(n.items[0].priority, recommend(lunar, points)[0].priority);
});

test('composed widgets are valid GenUI in the documented order', () => {
  const x = run('Compara el riesgo entre hábitats y qué falta validar');
  const w = compose([{ type: 'answer_card', title: 'f', body: 'b', level: 'critical' }], x);
  assert.deepEqual(w.map((v) => v.type), ['coverage', 'answer_card', 'metrics', 'table', 'next_tests', 'follow_ups']);
  GenUI.parse({ answer: 'x', widgets: w, citations: [] });
});
