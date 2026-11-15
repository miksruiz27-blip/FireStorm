import * as repo from '../repo.js';
import { GenUI } from '../schemas.js';
import { scoreExperiment } from '../scoring.js';
import { askLLM } from './llm.js';
import { buildWidgets, conditionsFrom, level } from './rules.js';

const MAX_SOURCES = 8;

/** Citable id for a source: NTRS id, else the PSI investigation in its URL, else the URL's host. */
export const refOf = ({ ntrs_id, url }) =>
  ntrs_id ? `NTRS ${ntrs_id}` : url.match(/investigations\/(PSI-\d+)/)?.[1] ?? new URL(url).host.replace(/^www\./, '');
const citable = (s) => s?.title && /^https?:\/\/\S+$/.test(s.url ?? '');

/** → { body: GenUI, source: 'llm'|'ollama'|'template' }. `llm` injectable for tests. */
export async function copilot({ question, habitat: habitatId }, { llm = askLLM } = {}) {
  const h = await repo.habitat(habitatId);
  if (!h) throw Object.assign(new Error(`unknown habitat ${habitatId}`), { status: 400 });

  // a) retrieve: FTS hits, else the best-scoring experiments for this habitat.
  let experiments = await repo.searchExperiments(question);
  if (!experiments.length) {
    const [all, counts] = await Promise.all([repo.experiments(), repo.pointCounts()]);
    const max = Math.max(1, ...Object.values(counts));
    experiments = all
      .map((e) => ({ e, s: scoreExperiment(h, e, counts[e.id] ?? 0, max).score }))
      .sort((a, b) => b.s - a.s)
      .slice(0, 5)
      .map((x) => x.e);
  }
  const [mocs, points, all] = await Promise.all([repo.mocs(), repo.testPoints(), repo.experiments()]);
  const byId = Object.fromEntries(all.map((e) => [e.id, e]));
  const spreadPoints = points.filter((t) => t.spread_rate_mm_s != null);

  // Numbered sources (max 8): retrieved experiments' first resolvable source, then MOC sources that have a link.
  // A source without a title and an http(s) URL is never numbered, so it can never be cited.
  const sources = [];
  const addSource = (key, src, text) =>
    sources.length < MAX_SOURCES && citable(src) && !sources.some((s) => s.key === key) &&
    sources.push({ n: sources.length + 1, key, title: src.title, url: src.url, ref: refOf(src), text });
  for (const e of [...experiments, ...spreadPoints.map((t) => byId[t.experiment_id])]) {
    if (e) addSource(`exp:${e.id}`, e.sources.find(citable), e.key_findings[0]);
  }
  for (const m of mocs) addSource(`moc:${m.source}`, { title: m.source, url: m.url ?? '', ntrs_id: m.ntrs_id ?? '' }, null);

  // b+c) physics forecast at the habitat (or the question's what-if) → widgets.
  const cond = conditionsFrom(question, h);
  const { widgets, cite: ruleCite, forecast: f } = buildWidgets({
    question, habitat: h, cond, experiments,
    mocs,
    spreadPoints: spreadPoints.filter((t) => sources.some((s) => s.key === `exp:${t.experiment_id}`)),
    sources,
  });

  // d/e) LLM writes the answer. It is rejected unless it cites at least one numbered (resolvable)
  // source; then the rule answer + rule citations stand in.
  const llmOut = await llm({ question, habitat: h, widgets, sources });
  const valid = new Set(sources.map((s) => s.n));
  const llmCite = llmOut ? [...new Set(llmOut.cite)].filter((n) => valid.has(n)) : [];
  const out = llmCite.length ? llmOut : null;
  const cite = out ? llmCite : ruleCite;
  const answer = out?.answer ??
    `Con base en ${cite.length} fuentes de NASA y el modelo físico: riesgo ` +
      `${{ critical: 'crítico', warning: 'alto', info: 'bajo' }[level(f.p_burn)]} en ${h.name} ` +
      `a ${+f.conditions.o2_pct.toFixed(1)} % O₂ — límite ${f.loi_pct} %, propagación ≈ ${f.spread_mm_s} mm/s` +
      (f.extrapolated.length ? '; extrapolado, sin ensayos en esta condición.' : '.');

  // f) citations come from the DB-backed list only.
  const body = GenUI.parse({
    answer,
    widgets,
    citations: cite.map((n) => sources.find((s) => s.n === n)).filter(Boolean).map(({ n, title, ref, url }) => ({ n, title, ref, url })),
  });
  return { body, source: out ? out.source : 'template' };
}
