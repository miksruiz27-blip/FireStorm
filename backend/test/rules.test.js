import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildWidgets, level } from '../src/genui/rules.js';
import { GenUI } from '../src/schemas.js';

const ctx = (question, habitat = { name: 'Lunar Base', o2_pct: 34, pressure_psia: 8.2, gravity_g: 0.166 }) => ({
  question,
  habitat,
  experiments: [{ id: 'saffire' }, { id: 'bass-ii' }],
  mocs: [
    { material: 'PMMA', moc_pct: 15.5, pressure_kpa: 101.3, source: 'm' },
    { material: 'PMMA', moc_pct: 16.5, pressure_kpa: 70.3, source: 'm' },
    { material: 'test-safe', moc_pct: 40, pressure_kpa: 101.3, source: 'm' },
  ],
  spreadPoints: [{ experiment_id: 'bass-ii', o2_pct: 21, spread_rate_mm_s: 4.1 }],
  sources: [
    { n: 1, key: 'exp:saffire' },
    { n: 2, key: 'exp:bass-ii' },
    { n: 3, key: 'moc:m' },
  ],
});
const types = (w) => w.map((x) => x.kind ?? x.type);

test('risk level thresholds', () => {
  assert.deepEqual([level(0.5), level(0.3), level(0.29), level(null)], ['critical', 'warning', 'info', 'warning']);
});

test('lunar forecast: burns (tested at 0.16 g) → critical; buoyancy noted; 0.6 g untested', () => {
  const { widgets, forecast } = buildWidgets(ctx('hello'));
  assert.equal(widgets[0].level, 'critical');
  assert.doesNotMatch(widgets[0].body, /untested/);
  const between = buildWidgets(ctx('hello', { name: 'X', o2_pct: 30, pressure_psia: 10.2, gravity_g: 0.6 }));
  assert.match(between.widgets[0].body, /untested/);
  assert.match(widgets[0].body, /Buoyancy/);
  assert.ok(forecast.p_burn > 0.5);
});

test('safe question → MOC bar with habitat O₂ line + SAFE and BURNS lists; spread → predicted line', () => {
  const m = buildWidgets(ctx('Which materials stay safe at 34% oxygen?'));
  assert.deepEqual(types(m.widgets), ['answer_card', 'bar', 'answer_card', 'answer_card', 'line']); // 'oxygen' also asks for spread
  assert.equal(m.widgets[1].threshold, 34);
  assert.deepEqual(m.widgets[1].points, [['PMMA', 16.5], ['test-safe', 40]]); // PMMA: row closest to 56.5 kPa
  assert.match(m.widgets[2].title, /^SAFE at 34 % O₂/);
  assert.match(m.widgets[2].body, /test-safe \(MOC 40 % at 101.3 kPa, margin \+6\)/);
  assert.match(m.widgets[3].title, /^BURNS at 34 % O₂/);
  assert.match(m.widgets[3].body, /PMMA \(MOC 16.5 % at 70.3 kPa, 17.5 points over; predicted spread/);
  assert.equal(buildWidgets(ctx('Which materials are safe?', { name: 'ISS', o2_pct: 21, pressure_psia: 14.7, gravity_g: 0 })).widgets[1].threshold, 21);
  assert.deepEqual(m.cite, [2, 3]); // MOC source + the measured spread point's experiment
  const s = buildWidgets(ctx('How does oxygen affect spread?')).widgets[1];
  assert.equal(s.kind, 'line');
  assert.equal(s.measured.length, 1);
});

test('what-if title; gravity question → limit by gravity; no topic → experiment list, valid GenUI', () => {
  assert.match(buildWidgets(ctx('What about 21% O2?')).widgets[0].title, /What-if · 21 % O₂/);
  assert.deepEqual(types(buildWidgets(ctx('What has been tested at lunar gravity?')).widgets), ['answer_card', 'bar', 'experiment_list']);
  const { widgets, cite } = buildWidgets(ctx('hello'));
  assert.deepEqual(types(widgets), ['answer_card', 'experiment_list']);
  GenUI.parse({ answer: 'x', widgets, citations: cite.map((n) => ({ n, title: 't', ref: 'PSI-25', url: 'https://psi.nasa.gov' })) });
});

test('modifications question → the retrieved experiments’ required modifications, cited', () => {
  const c = ctx('What modifications are required?');
  c.experiments = [{ id: 'bass-ii', name: 'BASS-II', modifications: ['Cortar HVAC', 'Bajar MOC'] }, { id: 'saffire' }];
  const { widgets, cite } = buildWidgets(c);
  const card = widgets.find((w) => w.title?.startsWith('Required modifications'));
  assert.equal(card.body, '1) Cortar HVAC 2) Bajar MOC');
  assert.ok(cite.includes(2));
});
