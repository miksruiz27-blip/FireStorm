import { q } from './db.js';

const EXP_COLS = `id, name, platform, fuel_type, domain, hardware, o2_range, pressure_kpa_range, gravity,
  flow_cm_s_range, materials, key_findings, sources, modifications, research_group`;
const TP_COLS = `experiment_id, material, o2_pct, pressure_kpa, gravity_g, flow_cm_s, outcome, spread_rate_mm_s, source`;

export const habitats = () => q('SELECT id, name, o2_pct, pressure_psia, gravity_g, source FROM habitats ORDER BY id');
export const habitat = async (id) =>
  (await q('SELECT id, name, o2_pct, pressure_psia, gravity_g, source FROM habitats WHERE id = $1', [id]))[0];
// Everything the app shows or fits on is verified (F4 source audit); unverified rows stay in the DB.
export const experiments = () => q(`SELECT ${EXP_COLS} FROM experiments WHERE is_verified ORDER BY id`);
export const experiment = async (id) =>
  (await q(`SELECT ${EXP_COLS} FROM experiments WHERE id = $1 AND is_verified`, [id]))[0];
export const testPoints = () =>
  q(`SELECT ${TP_COLS} FROM test_points WHERE is_verified ORDER BY experiment_id, o2_pct, id`);
export const mocs = () => q('SELECT material, moc_pct, pressure_kpa, source FROM material_moc ORDER BY moc_pct');
export const pointCounts = async () =>
  Object.fromEntries(
    (await q('SELECT experiment_id, count(*)::int n FROM test_points WHERE is_verified GROUP BY 1')).map((r) => [r.experiment_id, r.n]),
  );

/** Full-text search: any word of the question (OR), ranked. */
export function searchExperiments(question, limit = 5) {
  const words = [...new Set(question.toLowerCase().match(/[a-z0-9]{3,}/g) ?? [])];
  if (!words.length) return [];
  return q(
    `SELECT ${EXP_COLS} FROM experiments, to_tsquery('english', $1) query
     WHERE search @@ query AND is_verified ORDER BY ts_rank(search, query) DESC, id LIMIT $2`,
    [words.join(' | '), limit],
  );
}
