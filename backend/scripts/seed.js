// Seed: data/<table>.json or .csv → validate with zod → upsert, all in one transaction.
// Invalid rows are reported, never inserted. `--replace` first empties experiments + test_points
// (the dataset is swapped as a whole; habitats and material_moc are upserted).
import { existsSync, readFileSync } from 'node:fs';
import { pool } from '../src/db.js';
import { parseCsv } from '../src/csv.js';
import { Experiment, Habitat, MaterialMoc, TestPoint } from '../src/schemas.js';

const data = (f) => new URL(`../data/${f}`, import.meta.url);

function load(name) {
  if (existsSync(data(`${name}.json`))) return JSON.parse(readFileSync(data(`${name}.json`), 'utf8'));
  if (existsSync(data(`${name}.csv`))) return parseCsv(readFileSync(data(`${name}.csv`), 'utf8'));
  console.warn(`⚠ data/${name}.json|csv not found, skipping`);
  return [];
}

const rejected = [];
function valid(name, schema, rows) {
  return rows.flatMap((row, i) => {
    const r = schema.safeParse(row);
    if (r.success) return [r.data];
    rejected.push(`${name}[${i}]: ${r.error.issues.map((e) => `${e.path.join('.')} ${e.message}`).join('; ')}`);
    return [];
  });
}

const upserts = {
  habitats: [
    Habitat,
    `INSERT INTO habitats (id, name, o2_pct, pressure_psia, gravity_g, source) VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (id) DO UPDATE SET name=$2, o2_pct=$3, pressure_psia=$4, gravity_g=$5, source=$6`,
    (h) => [h.id, h.name, h.o2_pct, h.pressure_psia, h.gravity_g, h.source],
  ],
  experiments: [
    Experiment,
    `INSERT INTO experiments (id, name, platform, fuel_type, domain, hardware, o2_range, pressure_kpa_range, gravity,
       flow_cm_s_range, materials, key_findings, sources, modifications, research_group, search)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$15,$16,
       to_tsvector('english', $2 || ' ' || $14 || ' ' || array_to_string($11::text[], ' ') || ' ' ||
         array_to_string($12::text[], ' ') || ' ' || array_to_string($15::text[], ' ')))
     ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, platform=EXCLUDED.platform, fuel_type=EXCLUDED.fuel_type,
       domain=EXCLUDED.domain, hardware=EXCLUDED.hardware, o2_range=EXCLUDED.o2_range,
       pressure_kpa_range=EXCLUDED.pressure_kpa_range, gravity=EXCLUDED.gravity, flow_cm_s_range=EXCLUDED.flow_cm_s_range,
       materials=EXCLUDED.materials, key_findings=EXCLUDED.key_findings, sources=EXCLUDED.sources,
       modifications=EXCLUDED.modifications, research_group=EXCLUDED.research_group, search=EXCLUDED.search`,
    (e) => [e.id, e.name, e.platform, e.fuel_type, e.domain, e.hardware, e.o2_range, e.pressure_kpa_range, e.gravity,
      e.flow_cm_s_range, e.materials, e.key_findings, JSON.stringify(e.sources), e.hardware, e.modifications, e.research_group],
  ],
  test_points: [
    TestPoint,
    `INSERT INTO test_points (experiment_id, material, o2_pct, pressure_kpa, gravity_g, flow_cm_s, outcome, spread_rate_mm_s, source)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
     ON CONFLICT (experiment_id, material, o2_pct, pressure_kpa, gravity_g, flow_cm_s)
     DO UPDATE SET outcome=$7, spread_rate_mm_s=$8, source=$9`,
    (t) => [t.experiment_id, t.material, t.o2_pct, t.pressure_kpa, t.gravity_g, t.flow_cm_s, t.outcome, t.spread_rate_mm_s, t.source],
  ],
  material_moc: [
    MaterialMoc,
    `INSERT INTO material_moc (material, pressure_kpa, moc_pct, source) VALUES ($1,$2,$3,$4)
     ON CONFLICT (material, pressure_kpa) DO UPDATE SET moc_pct=$3, source=$4`,
    (m) => [m.material, m.pressure_kpa, m.moc_pct, m.source],
  ],
};

const db = await pool.connect();
try {
  await db.query('BEGIN');
  if (process.argv.includes('--replace')) await db.query('TRUNCATE test_points, experiments');
  for (const [table, [schema, sql, params]] of Object.entries(upserts)) {
    for (const row of valid(table, schema, load(table))) {
      await db.query('SAVEPOINT row');
      try {
        await db.query(sql, params(row));
        await db.query('RELEASE SAVEPOINT row');
      } catch (e) {
        await db.query('ROLLBACK TO SAVEPOINT row');
        rejected.push(`${table} ${JSON.stringify(row).slice(0, 80)}…: ${e.message}`); // e.g. unknown experiment_id
      }
    }
  }
  await db.query('COMMIT');
} catch (e) {
  await db.query('ROLLBACK');
  throw e;
} finally {
  db.release();
}

if (rejected.length) console.log(`\n✗ ${rejected.length} rows rejected:\n  ${rejected.join('\n  ')}`);
const counts = await pool.query(
  `SELECT 'habitats' t, count(*)::int n FROM habitats UNION ALL SELECT 'experiments', count(*) FROM experiments
   UNION ALL SELECT 'test_points', count(*) FROM test_points UNION ALL SELECT 'material_moc', count(*) FROM material_moc`,
);
console.table(counts.rows);
await pool.end();
