import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { fit, flame, materialKey } from '../src/flame.js';
import { conditionsFrom } from '../src/genui/rules.js';

const data = (f) => JSON.parse(readFileSync(new URL(`../data/${f}`, import.meta.url), 'utf8'));
// Same input as scripts/fit_flame.js: verified test points only (F4 audit).
const P = fit(data('test_points.json').filter((t) => t.is_verified), data('material_moc.json'));
const at = (x) => flame({ material: 'pmma', pressure_kpa: 101.3, flow_cm_s: 0, ...x }, P);

test('fit: kP from MOC pressure pairs, classifies the sample', () => {
  assert.ok(P.k_p > 2 && P.k_p < 3.5, `k_p ${P.k_p}`);
  // Verified solid burns of MOC-known materials (137, μg + 1 g) against the 6 MOC rows: 0.77 after the F4 audit.
  assert.ok(P.metrics.accuracy >= 0.7, `accuracy ${P.metrics.accuracy}`);
  assert.ok(P.metrics.n >= 130, `n ${P.metrics.n}`);
  // equipo3: partial-g rows are fitted (labelled simulated), so the tested gravities include Moon and Mars.
  assert.deepEqual(P.fit_range.gravity_g, [0, 0.16, 0.38, 1]);
});

test('physics: U-shaped limit, lower pressure raises it, partial g is the most flammable', () => {
  const lim = (x) => at(x).loi_pct;
  assert.ok(lim({ gravity_g: 0, flow_cm_s: 0 }) > lim({ gravity_g: 0, flow_cm_s: 10 })); // starved without flow
  assert.ok(lim({ gravity_g: 0, flow_cm_s: 100 }) > lim({ gravity_g: 0, flow_cm_s: 10 })); // blow-off
  assert.ok(lim({ pressure_kpa: 50 }) > lim({ pressure_kpa: 101.3 }));
  assert.ok(lim({ gravity_g: 0.166 }) < lim({ gravity_g: 1 }));
  assert.ok(at({ o2_pct: 30, gravity_g: 1 }).spread_mm_s > at({ o2_pct: 21, gravity_g: 1 }).spread_mm_s);
  assert.deepEqual(at({ o2_pct: 30, gravity_g: 1 }).extrapolated, []);
  // equipo3 partial-g data (team dataset, simulated) covers Moon and Mars: no longer extrapolated.
  assert.deepEqual(at({ o2_pct: 34, gravity_g: 0.166 }).extrapolated, []);
  assert.deepEqual(at({ o2_pct: 30, gravity_g: 0.38 }).extrapolated, []);
});

test('materials: fuzzy names, what-if parsing', () => {
  assert.equal(materialKey('Silicone rubber', P), 'silicone');
  assert.equal(materialKey('paper', P), 'pmma');
  assert.equal(materialKey('SIBAL_Cotton_Fiberglass_75_25_Opposed', P), 'cotton-fiberglass fabric');
  assert.equal(materialKey('Nomex_fabric', P), 'aramid fabric');
  assert.equal(materialKey('PMMA_slab_1.2mm', P), 'pmma');
  const lunar = { o2_pct: 34, pressure_psia: 8.2, gravity_g: 0.166 };
  const c = conditionsFrom('What if we go to 34% O2 on Mars with fans off?', lunar);
  assert.deepEqual([c.o2_pct, c.gravity_g, c.flow_cm_s], [34, 0.38, 0]);
  assert.deepEqual(conditionsFrom('Is the lunar base risky?', lunar).changed, []);
});

test('POST /forecast: physics everywhere, data model only in its domain', async () => {
  const { default: request } = await import('supertest');
  const { app } = await import('../src/app.js');
  const { pool } = await import('../src/db.js');
  const lunar = (await request(app).post('/forecast').send({ o2_pct: 34, pressure_kpa: 56.5, flow_cm_s: 10, gravity_g: 0.166 }).expect(200)).body;
  assert.ok(lunar.p_burn > 0.5 && !lunar.extrapolated.length && lunar.data_model === null); // data model has no gravity input
  const iss = (await request(app).post('/forecast').send({ o2_pct: 21, pressure_kpa: 101.3, flow_cm_s: 5, gravity_g: 0 }).expect(200)).body;
  assert.ok(iss.data_model.p_burn > 0);
  await pool.end();
});
