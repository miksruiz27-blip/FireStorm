import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { classifyFlow, loadClassifiers } from '../src/classifiers.js';
import { parseCsv } from '../src/csv.js';
import { domainCheck, loadModel, predict } from '../src/model.js';

// The team's model.onnx (MLP 64×32) outputs, recorded with onnxruntime-node at import time.
const ONNX = [
  [{ o2_pct: 20.9, pressure_kpa: 101.3, flow_cm_s: 5 }, 0.9989],
  [{ o2_pct: 16, pressure_kpa: 100.5, flow_cm_s: 0.5 }, 0.0028],
  [{ o2_pct: 17.5, pressure_kpa: 101, flow_cm_s: 30 }, 0.0007],
];

test('Node p_burn = team model.onnx (±0.001)', async () => {
  await loadModel();
  const { p, model } = await predict(ONNX.map(([x]) => x));
  assert.equal(model, 'onnx');
  ONNX.forEach(([, want], i) => assert.ok(Math.abs(p[i] - want) <= 0.001, `example ${i + 1}: ${p[i]} vs ${want}`));
});

test('domain guard: ISS conditions in, partial gravity out', () => {
  assert.equal(domainCheck({ o2_pct: 20.9, pressure_kpa: 101.3, flow_cm_s: 5, gravity_g: 0 }).ok, true);
  const lunar = domainCheck({ o2_pct: 30, pressure_kpa: 70.3, flow_cm_s: 0, gravity_g: 0.165 });
  assert.equal(lunar.ok, false);
  assert.deepEqual(lunar.reasons, ['gravity 0.165 g (trained 0 g)']);
  assert.equal(domainCheck({ o2_pct: 60, pressure_kpa: 101.3, flow_cm_s: 0, gravity_g: 0 }).ok, false); // > 3σ O₂
});

test('PSI-166 flow classifier reproduces the team labels, ONNX and linear fallback', async () => {
  const rows = parseCsv(readFileSync(new URL('../../firestorm_modelos_y_csv_equipo/psi166_part01_dataset.csv', import.meta.url), 'utf8'))
    .map((r) => ({ ...Object.fromEntries(Object.entries(r).map(([k, v]) => [k, Number(v)])), want: r.modification_class }));
  const acc = ({ results }) => results.filter((r, i) => r.class === rows[i].want).length / rows.length;
  const fallback = await classifyFlow(rows); // before loading: linear fallback
  assert.equal(fallback.model, 'fallback');
  assert.ok(acc(fallback) >= 0.95, `fallback ${acc(fallback)}`);
  await loadClassifiers();
  const onnx = await classifyFlow(rows);
  assert.equal(onnx.model, 'onnx');
  assert.ok(acc(onnx) >= 0.99, `onnx ${acc(onnx)}`);
});
