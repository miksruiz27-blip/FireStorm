// Team drop (../firestorm_modelos_y_csv_equipo) → data/experiments.json + data/test_points.json, and the
// ONNX models + model.json → models/. Re-run whenever the team ships a new drop, then `npm run seed -- --replace`.
//  bass_experiments.csv                     every test point (347 in the 2026-11-14 drop), id prefix = experiment
//  psi_repositories_simulated.csv           spread rates for the PSI rows (solid fuels only)
//  unified_experiments_and_modifications.csv  names, hardware, findings, required modifications
import { copyFileSync, readFileSync, writeFileSync } from 'node:fs';
import { parseCsv } from '../src/csv.js';

const team = new URL('../../firestorm_modelos_y_csv_equipo/', import.meta.url);
const csv = (f) => parseCsv(readFileSync(new URL(f, team), 'utf8'));
const tests = csv('bass_experiments.csv');
const psi = Object.fromEntries(csv('psi_repositories_simulated.csv').map((r) => [r.test_id, r]));
const catalog = Object.fromEntries(csv('unified_experiments_and_modifications.csv').map((r) => [r.id, r]));

// test_id prefix → [experiment id, catalog id, overrides]
const EXPERIMENTS = {
  BASS: ['bass', 'EXP-13', { domain: ['prevention', 'suppression'] }],
  BASS2: ['bass-ii', 'PSI-REPO-25', { name: 'BASS-II - Burning and Suppression of Solids II', domain: ['prevention', 'suppression'] }],
  PSI: ['bass-psi-archive', 'EXP-13', { name: 'BASS / BASS-II PSI archive (PMMA cast sheet)' }],
  'INC-AP1': ['apollo-1', 'INC-02', {}],
  'INC-AP13': ['apollo-13', 'INC-01', {}],
  FLEX: ['flex', 'EXP-01', { domain: ['prevention', 'suppression'] }],
  FLEX2: ['flex-2', 'EXP-02', { domain: ['prevention', 'suppression'] }],
  COOL: ['cool-flames', 'EXP-26', {}],
  SOFIE: ['sofie', 'EXP-14', {}],
  'ACME-BRE': ['acme-bre', 'EXP-08', { fuel_type: 'gas' }], // gas burner that emulates solids
  'ACME-CLD': ['acme-cld', 'EXP-09', {}],
  'ACME-EF': ['acme-e-field', 'EXP-10', {}],
  'ACME-FD': ['acme-flame-design', 'EXP-11', {}],
  'ACME-SF': ['acme-s-flame', 'EXP-12', {}],
  SPICE: ['spice', 'EXP-03', {}],
  SLICE: ['slice', 'EXP-04', {}],
  SOFBALL: ['sofball', 'EXP-23', {}],
  CANDLE: ['candle-flames', 'EXP-24', { fuel_type: 'solid' }], // paraffin wax
  MIST: ['mist', 'EXP-22', {}],
  'HAL-HVAC': ['hvac-ventilation', 'HAL-04', { domain: ['prevention', 'suppression'] }],
  'HAL-N2JET': ['n2-jet-suppression', 'HAL-05', { domain: ['prevention', 'suppression'] }],
  PSI25: ['psi-25', 'PSI-REPO-25', { domain: ['prevention', 'suppression'] }],
  PSI26: ['psi-26', 'PSI-REPO-26', { domain: ['prevention', 'suppression'] }],
  PSI68: ['psi-68', 'PSI-REPO-68', { domain: ['prevention', 'suppression'] }],
  PSI69: ['psi-69', 'PSI-REPO-69', { domain: ['prevention', 'suppression'] }],
  PSI20: ['psi-20', 'PSI-REPO-20', { fuel_type: 'gas' }], // ACME BRE emulator
  PSI159: ['psi-159', 'PSI-REPO-159', { fuel_type: 'gas' }], // CFI-G gaseous cool flames
  // Partial gravity (Moon 0.16 g / Mars 0.38 g) + exploration atmospheres (8.2 psia / 34 % O₂).
  // Several prefixes may share one experiment id: their rows are merged.
  LUNA: ['luci-lunar', 'LUNA-MARS-01', { domain: ['prevention'] }],
  MARS: ['mars-partial-g', 'LUNA-MARS-03', { domain: ['prevention'] }],
  'SAFFIRE-LM': ['saffire-iv-vi', 'LUNA-MARS-02', { domain: ['prevention', 'detection'] }],
  'SAFFIRE-FFD': ['saffire-iv-vi', 'LUNA-MARS-02', {}],
  'FLEX-LUNA': ['flex-partial-g', 'LUNA-MARS-05', {}],
  'FLEX-MARS': ['flex-partial-g', 'LUNA-MARS-05', {}],
  'ACME-LUNA': ['acme-e-field-partial-g', 'LUNA-MARS-06', { fuel_type: 'gas' }],
  'ACME-MARS': ['acme-e-field-partial-g', 'LUNA-MARS-06', {}],
  'SAME-LUNA': ['same-daft-dust', 'LUNA-MARS-04', {}],
  'SAME-MARS': ['same-daft-dust', 'LUNA-MARS-04', {}],
  'MIST-LUNA': ['scwm-partial-g', 'LUNA-MARS-07', { domain: ['suppression'] }],
  'MIST-MARS': ['scwm-partial-g', 'LUNA-MARS-07', {}],
  'ISSI-LUNA': ['issi-partial-g', 'LUNA-MARS-08', {}],
  'ISSI-MARS': ['issi-partial-g', 'LUNA-MARS-08', {}],
  'SOFIE-GEL': ['sofie-iss-cir', 'SOFIE-CIR-5MOD', {}],
  'SOFIE-MIST': ['sofie-iss-cir', 'SOFIE-CIR-5MOD', {}],
  'SOFIE-SMURF': ['sofie-iss-cir', 'SOFIE-CIR-5MOD', {}],
  'SOFIE-RTDFS': ['sofie-iss-cir', 'SOFIE-CIR-5MOD', {}],
  'SOFIE-NCA': ['sofie-iss-cir', 'SOFIE-CIR-5MOD', {}],
  STD6001: ['nasa-std-6001b', 'STD-6001B-SMAC', { domain: ['prevention', 'detection'] }],
  SMAC: ['nasa-std-6001b', 'STD-6001B-SMAC', {}],
  LIION: ['li-ion-runaway', 'NESC-LIION-TR', {}],
  ...Object.fromEntries(
    [10, 21, 22, 23, 39, 47, 60, 62, 98, 99, 100, 101, 102, 106, 107, 108, 115, 117, 142, 181].map((n) => [
      `PSI${n}`,
      [`psi-${n}`, `PSI-REPO-${n}`, {}],
    ]),
  ),
};

// Experiments renamed by the F4 audit: the label the UI showed before → it now shows the id below.
const RENAMED = { 'saffire-iv-vi': 'SAFFIRE-EXPLORATION', 'sofie-iss-cir': 'SOFIE-CIR', 'nasa-std-6001b': 'STD-6001B-SMAC' };

// Reference documents (standards), not investigations: citable, never ranked (F5).
const REFERENCES = { 'nasa-std-6001b': { platform: 'NASA Technical Standard' } };

// Catalog group → defaults (fuel, safety domain).
const GROUP = {
  BASS_Solid_Flammability: ['solid', ['prevention']],
  SoFIE_Exploration_Flammability: ['solid', ['prevention']],
  Apollo_Incidents_Redesign: ['solid', ['prevention']],
  Smoke_Dust_Detection_SAME_DAFT: ['solid', ['detection']],
  Droplet_CoolFlames_FLEX: ['liquid', ['prevention']],
  ACME_Gas_Diffusion_Flames: ['gas', ['prevention']],
  Premixed_Stability_SOFBALL_Candle: ['gas', ['prevention']],
  WaterMist_SCWM_Suppression: ['gas', ['suppression']],
};

const prefix = (id) => id.replace(/-\d+[a-z]?$/i, '');
const uniq = (xs) => [...new Set(xs)];
const range = (xs) => [Math.min(...xs), Math.max(...xs)];
// Prefixes with rows in psi_repositories_simulated.csv (PSI*, and the partial-g LUNA/MARS/… series).
const SIMULATED = new Set(Object.keys(psi).map(prefix));
const simulated = (p) => SIMULATED.has(p);
const G_BANDS = { micro: 0, lunar: 0.166, mars: 0.38, earth: 1 };
/** Gravity band most rows were run at. */
const gravityBand = (gs) => {
  const band = (g) => Object.entries(G_BANDS).reduce((a, b) => (Math.abs(b[1] - g) < Math.abs(a[1] - g) ? b : a))[0];
  const n = Object.groupBy(gs, band);
  return Object.keys(n).sort((a, b) => n[b].length - n[a].length)[0];
};
/** "1) a; 2) b." → ['a', 'b'] */
const items = (s = '') =>
  s.split(/\s*(?:^|[;.]?\s)\d+\)\s*/).map((x) => x.trim().replace(/[;.]$/, '')).filter(Boolean);
const sourceTitle = (p, s) => (simulated(p) ? `${s} — simulated values (team dataset)` : s);
const ntrs = (s) => s.match(/NTRS:?\s*(\d{8,})/)?.[1] ?? '';
const url = (s, fallback) => s.match(/https?:\/\/[^\s)]+/)?.[0] ?? (ntrs(s) ? `https://ntrs.nasa.gov/citations/${ntrs(s)}` : fallback);
const platform = (hw) =>
  /cygnus/i.test(hw) ? 'Cygnus' : /sts|shuttle|spacelab/i.test(hw) ? 'Space Shuttle' : /\bmir\b/i.test(hw) ? 'Mir'
    : /apollo|launch complex/i.test(hw) ? 'Apollo' : 'ISS';

// F4 source audit. A partial-gravity row (0 < g < 1) is verified only if its source in the repo is a
// measured record; every such row in this drop comes from psi_repositories_simulated.csv, whose repo_url
// points at a microgravity PSI investigation, so it has no traceable partial-g source.
const partialG = (t) => Number(t.gravity_g) > 0 && Number(t.gravity_g) < 1;
const verifiedPoint = (t) => !(partialG(t) && simulated(prefix(t.test_id)));

const byPrefix = Object.groupBy(tests, (t) => prefix(t.test_id));
const unknown = Object.keys(byPrefix).filter((p) => !EXPERIMENTS[p]);
if (unknown.length) throw new Error(`unmapped test_id prefixes: ${unknown.join(', ')} — add them to EXPERIMENTS`);

// Experiment id → its prefixes (first prefix's catalog id + overrides win).
const ids = Object.groupBy(Object.keys(EXPERIMENTS), (p) => EXPERIMENTS[p][0]);
const experiments = Object.entries(ids).map(([id, prefixes]) => {
  const [, catId, o] = EXPERIMENTS[prefixes[0]];
  const p = prefixes[0];
  const all = prefixes.flatMap((x) => byPrefix[x] ?? []);
  const c = catalog[catId];
  if (!all.length || !c) throw new Error(`${p}: ${all.length ? `catalog ${catId} missing` : 'no test rows'}`);
  // Envelope, materials and sources from the verified rows only (all rows if none is verified).
  const verified = all.filter(verifiedPoint);
  const rows = verified.length ? verified : all;
  const [fuel, domain] = GROUP[c.grupo_investigacion] ?? ['solid', ['prevention']];
  const g = rows.map((t) => Number(t.gravity_g));
  const catRef = `${c.fuente}${c.referencia ? ` · ${c.referencia}` : ''}`;
  return {
    id,
    name: o.name ?? c.experimento_investigacion,
    platform: platform(c.instalacion_hardware),
    fuel_type: o.fuel_type ?? fuel,
    domain: o.domain ?? domain,
    hardware: c.instalacion_hardware,
    o2_range: range(rows.map((t) => Number(t.o2_pct))),
    pressure_kpa_range: range(rows.map((t) => Number(t.pressure_kpa))),
    gravity: gravityBand(g),
    flow_cm_s_range: range(rows.map((t) => Number(t.flow_cm_s))),
    materials: uniq(rows.map((t) => t.material)),
    key_findings: uniq([c.consecuencia_hallazgo, c.descripcion_objetivo].filter(Boolean)),
    modifications: items(c.modificaciones_necesarias),
    research_group: c.grupo_investigacion,
    // A reference is cited by its own document only (its test rows are SIN FUENTE).
    sources: [
      ...(id in REFERENCES ? [] : uniq(rows.map((t) => sourceTitle(prefix(t.test_id), t.source)))
        .map((s) => ({ title: s, ntrs_id: ntrs(s), url: url(s, 'https://psi.nasa.gov') }))),
      { title: catRef, ntrs_id: '', url: url(c.referencia, '') },
    ],
    catalog_id: catId,
    // A standard is verified by its own document (title + standard ID + URL), not by test rows.
    is_verified: verified.length > 0 || id in REFERENCES,
    type: id in REFERENCES ? 'reference' : 'investigation',
    ...(REFERENCES[id] ?? {}),
  };
});

const fuelOf = Object.fromEntries(experiments.map((e) => [e.id, e.fuel_type]));
const test_points = tests.map((t) => {
  const experiment_id = EXPERIMENTS[prefix(t.test_id)][0];
  const s = psi[t.test_id];
  // Flame spread only for solids that burned; liquid/gas "rates" are burning rates, not spread.
  const spread = s && fuelOf[experiment_id] === 'solid' && t.outcome === 'burn' ? Number(s.burning_or_spread_rate) : null;
  return {
    experiment_id,
    material: t.material,
    o2_pct: Number(t.o2_pct),
    pressure_kpa: Number(t.pressure_kpa),
    gravity_g: Number(t.gravity_g),
    flow_cm_s: Number(t.flow_cm_s),
    outcome: t.outcome,
    spread_rate_mm_s: spread,
    source: sourceTitle(prefix(t.test_id), t.source),
    is_verified: verifiedPoint(t),
  };
});

const out = (f, data) => writeFileSync(new URL(`../data/${f}`, import.meta.url), `${JSON.stringify(data, null, 1)}\n`);
out('experiments.json', experiments.map(({ catalog_id, ...e }) => e));
out('test_points.json', test_points);

// Models: ONNX as shipped; model.json gets the class order model.js needs (ONNX label 1 = burn).
for (const f of ['model.onnx', 'experiment_classifier.onnx', 'psi166_flow_classifier.onnx'])
  copyFileSync(new URL(f, team), new URL(`../models/${f}`, import.meta.url));
const meta = JSON.parse(readFileSync(new URL('model.json', team), 'utf8'));
// PSI-166 flow classes → the action the team wrote most often for that class.
const flow = meta.extended_capabilities.psi166_mhd_classifier;
const actions = Object.groupBy(csv('psi166_part01_dataset.csv'), (r) => r.modification_class);
flow.class_modifications = Object.fromEntries(
  flow.classes.map((k) => {
    const n = Object.groupBy(actions[k] ?? [], (r) => r.modificaciones_necesarias);
    return [k, Object.entries(n).sort((a, b) => b[1].length - a[1].length)[0]?.[0] ?? ''];
  }),
);
// Catalog entries whose only experiments are unverified are hidden from /catalog (kept in the file).
const catalogVerified = {};
for (const e of experiments) catalogVerified[e.catalog_id] ||= e.is_verified;
for (const entry of meta.extended_capabilities.catalog_summary.entries)
  if (catalogVerified[entry.id] === false) entry.is_verified = false;
writeAudit();
writeFileSync(
  new URL('../models/model.json', import.meta.url),
  `${JSON.stringify({ ...meta, classes: ['extinct', 'burn'] }, null, 1)}\n`,
);
console.log(
  `${experiments.length} experiments, ${test_points.length} test points ` +
    `(${test_points.filter((t) => t.spread_rate_mm_s != null).length} with spread), 3 ONNX models → data/, models/`,
);

/** AUDIT_SOURCES.md at the repo root: every experiment with partial-g rows and every partial-g test point. */
function writeAudit() {
  const simRow = Object.fromEntries(csv('psi_repositories_simulated.csv').map((r, i) => [r.test_id, { ...r, line: i + 2 }]));
  const esc = (s = '') => String(s).replace(/\|/g, '\\|').replace(/\s+/g, ' ').trim();
  const pg = tests.map((t, i) => ({ t, line: i + 2 })).filter(({ t }) => partialG(t));
  const pgExp = [...new Set(pg.map(({ t }) => EXPERIMENTS[prefix(t.test_id)][0]))];
  const expRows = experiments.filter((e) => pgExp.includes(e.id)).map((e) => {
    const c = catalog[e.catalog_id];
    const status = !e.is_verified
      ? 'SIN FUENTE'
      : e.type === 'reference'
        ? 'OK · reference (standard, not ranked; its partial-g rows SIN FUENTE)'
        : RENAMED[e.id] ? 'RENOMBRAR' : 'OK';
    return `| ${e.id} | ${RENAMED[e.id] ?? e.id.toUpperCase()} | ${esc(c.codigo_corto)} — ${esc(c.experimento_investigacion)} | ` +
      `${esc(c.fuente)} · ${esc(c.referencia)} (catalog ${e.catalog_id}) | ${status} |`;
  });
  const tpRows = pg.map(({ t, line }) => {
    const s = simRow[t.test_id];
    const where = `bass_experiments.csv:${line}` + (s ? ` · psi_repositories_simulated.csv:${s.line}` : '');
    return `| ${t.test_id} | ${EXPERIMENTS[prefix(t.test_id)][0]} | ${t.gravity_g} | ${esc(t.material)} | ${where} | ` +
      `${esc(t.source)}${s ? ` · repo_url ${s.repo_url}` : ''} | ${verifiedPoint(t) ? 'OK' : 'SIN FUENTE'} |`;
  });
  const md = `# AUDIT_SOURCES — partial-gravity data (F4)

Generated by \`backend/scripts/import_team.js\` from the team drop in \`firestorm_modelos_y_csv_equipo/\`. Re-run \`npm run import\` to refresh.

**Rule.** A row with 0 < g < 1 is OK only if its source in the repo is a measured record at that gravity
(NTRS or PSI identifier). Every partial-g row in this drop is in \`psi_repositories_simulated.csv\` (team-simulated
values), and its \`repo_url\` points at a microgravity PSI investigation, not a partial-g measurement → **SIN FUENTE**.
SIN FUENTE rows are kept in the DB with \`is_verified = false\`, hidden from the UI and excluded from the model fit.
An experiment with no verified row is SIN FUENTE; one that stays visible under an invented label is RENOMBRAR.

## Experiments with partial-g rows

| id | shown as | real name (catalog) | source (title · reference) | status |
|---|---|---|---|---|
${expRows.join('\n')}

## Partial-g test points (${pg.length})

| test_id | experiment | g | material | file:row | source | status |
|---|---|---|---|---|---|---|
${tpRows.join('\n')}
`;
  writeFileSync(new URL('../../AUDIT_SOURCES.md', import.meta.url), md);
}
