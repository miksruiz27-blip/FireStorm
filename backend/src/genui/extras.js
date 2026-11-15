// Extra GenUI widgets, built by rules from the physics model + real data (never by the LLM):
//  coverage    no PSI test near the asked condition → shown first, the answer is extrapolation
//  metrics     the forecast's key numbers as tiles
//  table       fire risk of every habitat at its own atmosphere
//  next_tests  the experiments that would close the gap (same priority as GET /recommendations)
//  follow_ups  questions the copilot can answer next (tapping one asks it)
import { flame } from '../flame.js';
import { PSI_TO_KPA, grid, pointsNear, priority, why } from '../scoring.js';
import { CABIN_FLOW, HABITAT_ES, REGIME_ES, say } from './rules.js';

const fmt = (v, d = 1) => +(+v).toFixed(d);

/** GET /recommendations: top 5 grid cells by gap × closeness × uncertainty, spread apart. */
export function recommend(h, points) {
  const ranked = grid().map((cell) => {
    const near = pointsNear(cell, points);
    const fc = flame({ ...cell, pressure_kpa: h.pressure_psia * PSI_TO_KPA, flow_cm_s: CABIN_FLOW });
    // Physics extrapolated past every test is unverified: maximal uncertainty, whatever p it computes.
    const p = fc.extrapolated.length ? 0.5 : fc.p_burn;
    const f = priority(cell, h, near.length, p);
    return { cell, priority: f.priority, why: why(cell, f, near.length, fc), sources: [...new Set(near.map((t) => t.source))], near: near.length, fc };
  });
  // Spread the picks: skip cells within ±2 % O₂ of a better one at the same gravity.
  const picks = [];
  for (const r of ranked.sort((a, b) => b.priority - a.priority)) {
    if (!picks.some((p) => p.cell.gravity_g === r.cell.gravity_g && Math.abs(p.cell.o2_pct - r.cell.o2_pct) <= 2)) picks.push(r);
    if (picks.length === 5) break;
  }
  return picks;
}

const topics = {
  habitats: /habitat|ambient|hábitat|compar|risky|riesg|atmospher|atmósfera|suit|traje|rover|\biss\b/i,
  next: /next|próxim|recommend|recomiend|recomend|gap|vac[ií]o|validat|valid|missing|falta|should we test|ensayar|untested|sin ensayar/i,
};

/** ctx: { question, habitat, cond, forecast (flame at cond), points (test_points), habitats, lang } */
export function extraWidgets({ question, habitat: h, cond: c, forecast: f, points, habitats, lang = 'en' }) {
  const t = say(lang);
  const regime = (r) => t(r, REGIME_ES[r] ?? r);
  const hName = (x) => t(x.name, HABITAT_ES[x.name] ?? x.name);
  const out = {};

  // coverage: test points within ±2 % O₂ at the same gravity.
  const near = points.filter((p) => Math.abs(p.o2_pct - c.o2_pct) <= 2 && Math.abs(p.gravity_g - c.gravity_g) < 0.05);
  if (!near.length) {
    const tested = [...new Set(points.map((p) => p.gravity_g))].sort((a, b) => a - b).join(', ');
    out.coverage = {
      type: 'coverage',
      text: t(
        `Outside data coverage: no PSI test within ±2 % of ${fmt(c.o2_pct)} % O₂ at ${c.gravity_g} g (tests exist at ${tested} g). ` +
          'The forecast below is physics extrapolation, not a measurement.',
        `Fuera de la cobertura de datos: ningún ensayo PSI a ±2 % de ${fmt(c.o2_pct)} % O₂ a ${c.gravity_g} g (hay ensayos a ${tested} g). ` +
          'El pronóstico de abajo es extrapolación física, no una medición.',
      ),
    };
  } else if (near.every((p) => /simulated/i.test(p.source ?? ''))) {
    // Covered, but only by the team's simulated partial-g campaign: say so, never call it measured.
    out.coverage = {
      type: 'coverage',
      text: t(
        `Covered only by ${near.length} simulated points from the team dataset at ${fmt(c.o2_pct)} % O₂ / ${c.gravity_g} g; ` +
          'no measured NASA test at this condition yet.',
        `Cubierto solo por ${near.length} puntos simulados del dataset del equipo a ${fmt(c.o2_pct)} % O₂ / ${c.gravity_g} g; ` +
          'aún no hay un ensayo NASA medido en esta condición.',
      ),
    };
  }

  const lvl = (p) => (p >= 0.5 ? 'critical' : p >= 0.3 ? 'warning' : 'info');
  out.metrics = {
    type: 'metrics',
    items: [
      { label: t('p(burn)', 'p(arder)'), value: `${Math.round(f.p_burn * 100)}`, unit: '%', level: lvl(f.p_burn) },
      { label: t('Flammability limit', 'Límite de inflamabilidad'), value: `${fmt(f.loi_pct)}`, unit: '% O₂' },
      { label: t('Margin', 'Margen'), value: `${f.margin_pct > 0 ? '+' : ''}${fmt(f.margin_pct)}`, unit: '% O₂', level: f.margin_pct > 0 ? 'critical' : 'info' },
      { label: t('Spread', 'Propagación'), value: `${fmt(f.spread_mm_s, 2)}`, unit: 'mm/s' },
      { label: t('Flow at flame', 'Flujo en la llama'), value: `${fmt(f.u_eff_cm_s)}`, unit: 'cm/s' },
    ],
  };

  if (topics.habitats.test(question) && habitats?.length) {
    const rows = habitats
      .map((x) => ({ x, fc: flame({ o2_pct: x.o2_pct, pressure_kpa: x.pressure_psia * PSI_TO_KPA, gravity_g: x.gravity_g, flow_cm_s: CABIN_FLOW, material: c.material }) }))
      .sort((a, b) => b.fc.margin_pct - a.fc.margin_pct);
    out.table = {
      type: 'table',
      title: t(`Fire risk by ambient · ${f.material}, ventilated`, `Riesgo de incendio por hábitat · ${f.material}, ventilado`),
      columns: [t('Ambient', 'Hábitat'), 'O₂ %', 'kPa', 'g', t('Limit %', 'Límite %'), t('p(burn)', 'p(arder)'), t('Regime', 'Régimen')],
      rows: rows.map(({ x, fc }) => [
        hName(x), `${fmt(x.o2_pct)}`, `${fmt(x.pressure_psia * PSI_TO_KPA)}`, `${x.gravity_g}`, `${fmt(fc.loi_pct)}`, fc.p_burn.toFixed(2), regime(fc.regime),
      ]),
      highlight: rows.findIndex(({ x }) => x.id === h.id),
    };
  }

  if (topics.next.test(question)) {
    out.next = {
      type: 'next_tests',
      items: recommend(h, points).slice(0, 3).map((r) => ({
        title: `${r.cell.o2_pct} % O₂ · ${r.cell.gravity_g} g`,
        priority: r.priority,
        body: t(
          `${r.near ? `${r.near} tests nearby` : 'No tests nearby'}; physics: ${r.fc.regime}, limit ${r.fc.loi_pct} %` +
            (r.fc.extrapolated.length ? '; extrapolated, a test here would confirm it.' : '.'),
          `${r.near ? `${r.near} ensayos cerca` : 'Sin ensayos cerca'}; física: ${regime(r.fc.regime)}, límite ${r.fc.loi_pct} %` +
            (r.fc.extrapolated.length ? '; extrapolado, un ensayo aquí lo confirmaría.' : '.'),
        ),
      })),
    };
  }

  // Follow-ups: the angles this question did not cover. Each phrasing triggers its rule widgets.
  const q = question.toLowerCase();
  const options = [
    [/material|segur|safe/, t('Which materials stay safe here?', '¿Qué materiales siguen siendo seguros aquí?')],
    [/fan|ventila|flow|flujo/, t('What if we turn the fans off?', '¿Qué pasa con la ventilación apagada?')],
    [/mars|marte|gravit|gravedad/, t('Does it change at Mars gravity?', '¿Cambia a gravedad de Marte?')],
    [topics.next, t('Which experiment is missing to validate this?', '¿Qué experimento falta para validar esto?')],
    [topics.habitats, t('Compare fire risk across ambients', 'Compara el riesgo de incendio entre hábitats')],
  ];
  out.followUps = { type: 'follow_ups', questions: options.filter(([re]) => !re.test(q)).slice(0, 3).map(([, s]) => s) };
  return out;
}

/** Final widget order: coverage, forecast card, metrics, rule widgets, table, next tests, follow-ups. */
export const compose = (widgets, x) =>
  [x.coverage, widgets[0], x.metrics, ...widgets.slice(1), x.table, x.next, x.followUps].filter(Boolean);
