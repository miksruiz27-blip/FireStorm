// Widgets are built by rules from the flame model + real data. The LLM never builds widgets.
import { readFileSync } from 'node:fs';
import { flame, params } from '../flame.js';
import { PSI_TO_KPA } from '../scoring.js';

/** (en, es) → the string for `lang`. */
export const say = (lang) => (en, es) => (lang === 'es' ? es : en);

// English → Spanish for catalog text (inverse of translations_en.json, the Spanish originals).
const ES = Object.fromEntries(
  Object.entries(JSON.parse(readFileSync(new URL('../../data/translations_en.json', import.meta.url), 'utf8'))).map(([es, en]) => [en, es]),
);
export const toLang = (lang, s) => (lang === 'es' ? ES[s] ?? s : s);
export const REGIME_ES = { 'self-extinguishes': 'se autoextingue', marginal: 'marginal', sustained: 'sostenida', vigorous: 'vigorosa' };

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
export const HABITAT_ES = { 'Lunar Base': 'Base Lunar', 'Pressurized Rover': 'Rover Presurizado', Spacesuit: 'Traje espacial' };

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

const forecastBody = (c, f, quiet, lang = 'en') => {
  const t = say(lang);
  const regime = (r) => t(r, REGIME_ES[r] ?? r);
  const r = regime(f.regime);
  return [
    t(
      `${r[0].toUpperCase()}${r.slice(1)} for ${f.material}-class solids: `,
      `${r[0].toUpperCase()}${r.slice(1)} para sólidos tipo ${toLang(lang, f.material)}: `,
    ) + t(`p(burn) ${f.p_burn.toFixed(2)}, spread ≈ ${f.spread_mm_s} mm/s.`, `p(arder) ${f.p_burn.toFixed(2)}, propagación ≈ ${f.spread_mm_s} mm/s.`),
    t(
      `Flammability limit ${f.loi_pct} % O₂ → margin ${f.margin_pct > 0 ? '+' : ''}${f.margin_pct}.`,
      `Límite de inflamabilidad ${f.loi_pct} % O₂ → margen ${f.margin_pct > 0 ? '+' : ''}${f.margin_pct}.`,
    ),
    c.gravity_g > 0.01
      ? t(
          `Buoyancy at ${c.gravity_g} g feeds the flame ≈ ${f.u_buoy_cm_s} cm/s, so ventilation off ` +
            `does not starve it (${quiet.regime}).`,
          `La flotabilidad a ${c.gravity_g} g alimenta la llama con ≈ ${f.u_buoy_cm_s} cm/s, así que apagar la ` +
            `ventilación no la asfixia (${regime(quiet.regime)}).`,
        )
      : t(
          `In microgravity only ventilation feeds it: fans off → limit ${quiet.loi_pct} % (${quiet.regime}).`,
          `En microgravedad solo la alimenta la ventilación: ventiladores apagados → límite ${quiet.loi_pct} % (${regime(quiet.regime)}).`,
        ),
    f.extrapolated.length
      ? t(`Physics extrapolation, untested: ${f.extrapolated.join('; ')}.`, `Extrapolación física, sin ensayar: ${f.extrapolated.join('; ')}.`)
      : '',
  ]
    .filter(Boolean)
    .join(' ');
};

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
export function buildWidgets({ question, habitat: h, cond, experiments, mocs, spreadPoints, sources, lang = 'en' }) {
  const t = say(lang);
  const c = cond ?? conditionsFrom(question, h);
  const f = flame(c);
  const quiet = flame({ ...c, flow_cm_s: 0 });
  const widgets = [];
  const cite = new Set();
  const n = (key) => sources.find((s) => s.key === key)?.n;

  widgets.push({
    type: 'answer_card',
    title: c.changed.length
      ? `${t('What-if', 'Escenario')} · ${c.changed.join(' · ')}`
      : `${t('Flame forecast', 'Pronóstico de llama')} · ${t(h.name, HABITAT_ES[h.name] ?? h.name)}`,
    body: forecastBody(c, f, quiet, lang),
    // An untested condition the physics says burns is the worst case: no data to argue otherwise.
    level: f.extrapolated.length && f.p_burn >= 0.3 ? 'critical' : level(f.p_burn),
  });

  const hit = Object.fromEntries(Object.entries(topics).map(([k, re]) => [k, re.test(question)]));

  if (hit.materials && mocs.length) {
    // SAFE / BURNS from the MOC table (material_moc), at the active O₂ (habitat or the question's what-if).
    // Per material, the MOC row measured at the pressure closest to the condition.
    const rows = Object.values(
      mocs.reduce((best, m) => {
        const k = m.material.toLowerCase();
        const d = (r) => Math.abs(r.pressure_kpa - c.pressure_kpa);
        if (!best[k] || d(m) < d(best[k])) best[k] = m;
        return best;
      }, {}),
    ).sort((a, b) => a.moc_pct - b.moc_pct);
    const o2 = c.o2_pct;
    const safe = rows.filter((m) => m.moc_pct > o2);
    const burns = rows.filter((m) => m.moc_pct <= o2);
    const spread = (m) => flame({ ...c, material: m.material }).spread_mm_s;
    const at = (m) => `MOC ${fmt(m.moc_pct)} % ${t('at', 'a')} ${fmt(m.pressure_kpa)} kPa`;
    const name = (m) => toLang(lang, m.material);
    widgets.push({ type: 'chart', kind: 'bar', x: 'Material', y: 'MOC % O₂', points: rows.map((m) => [name(m), m.moc_pct]), threshold: o2 });
    widgets.push({
      type: 'answer_card',
      title: t(`SAFE at ${fmt(o2)} % O₂ · MOC above ${fmt(o2)} %`, `SEGUROS a ${fmt(o2)} % O₂ · MOC por encima de ${fmt(o2)} %`),
      body: safe.length
        ? safe.map((m) => `${name(m)} (${at(m)}, ${t('margin', 'margen')} +${fmt(m.moc_pct - o2)})`).join('; ') + '.'
        : t(
            `None of the ${rows.length} materials in the MOC table stays below its limit at ${fmt(o2)} % O₂.`,
            `Ninguno de los ${rows.length} materiales de la tabla MOC queda por debajo de su límite a ${fmt(o2)} % O₂.`,
          ),
      level: 'info',
    });
    widgets.push({
      type: 'answer_card',
      title: t(`BURNS at ${fmt(o2)} % O₂ · MOC at or below ${fmt(o2)} %`, `ARDEN a ${fmt(o2)} % O₂ · MOC igual o inferior a ${fmt(o2)} %`),
      body: burns.length
        ? burns
            .map((m) =>
              t(
                `${name(m)} (${at(m)}, ${fmt(o2 - m.moc_pct)} points over; predicted spread ≈ ${spread(m)} mm/s)`,
                `${name(m)} (${at(m)}, ${fmt(o2 - m.moc_pct)} puntos por encima; propagación predicha ≈ ${spread(m)} mm/s)`,
              ),
            )
            .join('; ') + '.'
        : t(`No material in the MOC table burns at ${fmt(o2)} % O₂.`, `Ningún material de la tabla MOC arde a ${fmt(o2)} % O₂.`),
      level: burns.length ? 'critical' : 'info',
    });
    for (const m of rows) cite.add(n(`moc:${m.source}`));
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
      x: t('Gravity', 'Gravedad'),
      // Fans off: only buoyancy feeds the flame, so gravity alone sets the limit.
      y: t('Limit % O₂, fans off', 'Límite % O₂, ventiladores apagados'),
      points: GRAVITY_WORDS.map(([, g], i) => [
        t(['μg', 'Moon', 'Mars', 'Earth'][i], ['μg', 'Luna', 'Marte', 'Tierra'][i]),
        flame({ ...c, gravity_g: g, flow_cm_s: 0 }).loi_pct,
      ]),
    });
  }
  if (hit.modifications) {
    // The team's required design changes, from the retrieved experiments (DB), never generated.
    const withMods = experiments.filter((e) => e.modifications?.length).slice(0, 2);
    for (const e of withMods) {
      widgets.push({
        type: 'answer_card',
        title: `${t('Required modifications', 'Modificaciones requeridas')} · ${toLang(lang, e.name)}`,
        body: e.modifications.slice(0, 3).map((m, i) => `${i + 1}) ${toLang(lang, m)}`).join(' '),
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
  // Unnumbered (uncitable) keys add undefined: drop them first, then make sure the answer cites
  // at least the top retrieved source.
  cite.delete(undefined);
  if (!cite.size && sources.length) cite.add(sources[0].n);
  return { widgets, cite: [...cite].sort((a, b) => a - b), forecast: { ...f, conditions: c } };
}
