// Widgets are built by rules from the flame model + real data. The LLM never builds widgets.
import { flame, params } from '../flame.js';
import { PSI_TO_KPA } from '../scoring.js';

export const level = (p) => (p == null ? 'warning' : p >= 0.5 ? 'critical' : p >= 0.3 ? 'warning' : 'info');

/** Cabin ventilation the habitat forecast assumes (ISS runs ~5–20 cm/s). */
export const CABIN_FLOW = 10;

const topics = {
  materials: /material|safe|segur|moc|flammab|inflamab/i,
  experiments: /experiment|evidence|evidencia|tested|probad|cover|study|estudi/i,
  spread: /\bo2\b|o₂|oxygen|ox[ií]geno|flow|flujo|spread|propagaci|fast|rápid/i,
  gravity: /gravit|gravedad|lunar|moon|luna|mars|marte|earth|tierra|micro|μg/i,
  modifications: /modif|redesign|rediseñ|change|cambi|mitigat|mitig|recommend|recomend|lesson|lecci|requir|requer|should we|debemos/i,
};
const GRAVITY_WORDS = [
  [/micro|μg|orbit|\biss\b/i, 0],
  [/lunar|moon|\bluna/i, 0.166],
  [/mars|marte/i, 0.38],
  [/earth|tierra/i, 1],
];
const fmt = (v) => +v.toFixed(1);

/** Habitat conditions, overridden by any what-if in the question ("at 34% O2", "0.38 g", "fans off", "8 psi"). */
export function conditionsFrom(question, h) {
  const c = {
    o2_pct: h.o2_pct,
    pressure_kpa: h.pressure_psia * PSI_TO_KPA,
    gravity_g: h.gravity_g,
    flow_cm_s: CABIN_FLOW,
    material: params.default_material,
  };
  const changed = [];
  const num = (re) => Number(question.match(re)?.[1]);
  const o2 = num(/(\d+(?:\.\d+)?)\s*%/);
  if (o2 >= 0 && o2 <= 100 && o2 !== c.o2_pct) (c.o2_pct = o2), changed.push(`${o2} % O₂`);
  const g = num(/(\d*\.?\d+)\s*g\b/i) ?? NaN;
  const gWord = GRAVITY_WORDS.find(([re]) => re.test(question))?.[1];
  const grav = g >= 0 && g <= 1 ? g : gWord;
  if (grav != null && Math.abs(grav - c.gravity_g) > 0.01) (c.gravity_g = grav), changed.push(`${grav} g`);
  const kpa = num(/(\d+(?:\.\d+)?)\s*kpa/i);
  const psi = num(/(\d+(?:\.\d+)?)\s*psi/i);
  const p = kpa > 0 ? kpa : psi > 0 ? psi * PSI_TO_KPA : null;
  if (p) (c.pressure_kpa = p), changed.push(`${fmt(p)} kPa`);
  const flow = num(/(\d+(?:\.\d+)?)\s*cm\s*\/\s*s/i);
  if (flow >= 0) (c.flow_cm_s = flow), changed.push(`${flow} cm/s flow`);
  else if (/fans? off|ventilation off|no (ventilation|flow)|quiescent|sin ventila|apagad/i.test(question))
    (c.flow_cm_s = 0), changed.push('ventilation off');
  const mat = Object.keys(params.materials).find((m) => question.toLowerCase().includes(m));
  if (mat) (c.material = mat), changed.push(mat);
  return { ...c, changed };
}

const forecastBody = (c, f, quiet) =>
  [
    `${f.regime[0].toUpperCase()}${f.regime.slice(1)} for ${f.material}-class solids: ` +
      `p(burn) ${f.p_burn.toFixed(2)}, spread ≈ ${f.spread_mm_s} mm/s.`,
    `Flammability limit ${f.loi_pct} % O₂ → margin ${f.margin_pct > 0 ? '+' : ''}${f.margin_pct}.`,
    c.gravity_g > 0.01
      ? `Buoyancy at ${c.gravity_g} g feeds the flame ≈ ${f.u_buoy_cm_s} cm/s, so ventilation off ` +
        `does not starve it (${quiet.regime}).`
      : `In microgravity only ventilation feeds it: fans off → limit ${quiet.loi_pct} % (${quiet.regime}).`,
    f.extrapolated.length ? `Physics extrapolation, untested: ${f.extrapolated.join('; ')}.` : '',
  ]
    .filter(Boolean)
    .join(' ');

/** Predicted spread (mm/s) vs O₂ at the given conditions: the curve the copilot charts. */
export const spreadCurve = (c, from = 10, to = 40) =>
  Array.from({ length: (to - from) / 2 + 1 }, (_, i) => {
    const o2 = from + 2 * i;
    return [o2, flame({ ...c, o2_pct: o2 }).spread_mm_s];
  });

/**
 * ctx: { question, habitat, cond (conditionsFrom), experiments, mocs, spreadPoints, sources }
 * sources: [{ n, key }] where key is 'exp:<id>' or 'moc:<source>'. Returns { widgets, cite, forecast }.
 */
export function buildWidgets({ question, habitat: h, cond, experiments, mocs, spreadPoints, sources }) {
  const c = cond ?? conditionsFrom(question, h);
  const f = flame(c);
  const quiet = flame({ ...c, flow_cm_s: 0 });
  const widgets = [];
  const cite = new Set();
  const n = (key) => sources.find((s) => s.key === key)?.n;

  widgets.push({
    type: 'answer_card',
    title: c.changed.length ? `What-if · ${c.changed.join(' · ')}` : `Flame forecast · ${h.name}`,
    body: forecastBody(c, f, quiet),
    // An untested condition the physics says burns is the worst case: no data to argue otherwise.
    level: f.extrapolated.length && f.p_burn >= 0.3 ? 'critical' : level(f.p_burn),
  });

  const hit = Object.fromEntries(Object.entries(topics).map(([k, re]) => [k, re.test(question)]));

  if (hit.materials) {
    // Rank: every modelled material at these conditions, most dangerous first.
    const ranked = Object.keys(params.materials)
      .map((m) => flame({ ...c, material: m }))
      .sort((a, b) => b.margin_pct - a.margin_pct);
    widgets.push({ type: 'chart', kind: 'bar', x: 'Material', y: 'Limit % O₂', points: ranked.map((r) => [r.material, r.loi_pct]) });
    const burn = ranked.filter((r) => r.margin_pct > 0);
    widgets.push({
      type: 'answer_card',
      title: `Materials that burn at ${fmt(c.o2_pct)} % O₂`,
      body: burn.length
        ? `Predicted to sustain flame (limit below ${fmt(c.o2_pct)} %): ` +
          burn.map((r) => `${r.material} (+${fmt(r.margin_pct)}, ${r.spread_mm_s} mm/s)`).join(', ') + '.'
        : `No modelled material sustains flame at ${fmt(c.o2_pct)} % O₂ here.`,
      level: burn.length ? 'warning' : 'info',
    });
    for (const m of mocs) cite.add(n(`moc:${m.source}`));
  }
  if (hit.spread) {
    widgets.push({
      type: 'chart',
      kind: 'line',
      x: 'O2 %',
      y: 'mm/s',
      points: spreadCurve(c),
      measured: spreadPoints.map((t) => [t.o2_pct, t.spread_rate_mm_s]),
    });
    for (const t of spreadPoints) cite.add(n(`exp:${t.experiment_id}`));
  }
  if (hit.gravity) {
    widgets.push({
      type: 'chart',
      kind: 'bar',
      x: 'Gravity',
      // Fans off: only buoyancy feeds the flame, so gravity alone sets the limit.
      y: 'Limit % O₂, fans off',
      points: GRAVITY_WORDS.map(([, g], i) => [['μg', 'Moon', 'Mars', 'Earth'][i], flame({ ...c, gravity_g: g, flow_cm_s: 0 }).loi_pct]),
    });
  }
  if (hit.modifications) {
    // The team's required design changes, from the retrieved experiments (DB), never generated.
    const withMods = experiments.filter((e) => e.modifications?.length).slice(0, 2);
    for (const e of withMods) {
      widgets.push({
        type: 'answer_card',
        title: `Required modifications · ${e.name}`,
        body: e.modifications.slice(0, 3).map((m, i) => `${i + 1}) ${m}`).join(' '),
        level: 'warning',
      });
      cite.add(n(`exp:${e.id}`));
    }
  }
  const noTopic = !Object.values(hit).some(Boolean);
  if ((hit.experiments || noTopic) && experiments.length) {
    const ids = experiments.slice(0, 5).map((e) => e.id);
    widgets.push({ type: 'experiment_list', ids });
    for (const id of ids) cite.add(n(`exp:${id}`));
  }
  // Forecast alone still cites the top retrieved source.
  if (!cite.size && sources.length) cite.add(sources[0].n);
  cite.delete(undefined);
  return { widgets, cite: [...cite].sort((a, b) => a - b), forecast: { ...f, conditions: c } };
}
