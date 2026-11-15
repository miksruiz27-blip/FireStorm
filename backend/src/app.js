import cors from 'cors';
import express from 'express';
import { z } from 'zod';
import { pool } from './db.js';
import * as repo from './repo.js';
import { domainCheck, meta, modelReady, predict } from './model.js';
import { ClassifyIn, CopilotIn, FlowIn, PredictIn } from './schemas.js';
import { classifiersReady, classifyFlow, classifyText } from './classifiers.js';
import { PSI_TO_KPA, grid, pointsNear, priority, scoreExperiment, why } from './scoring.js';
import { copilot } from './genui/copilot.js';
import { CABIN_FLOW } from './genui/rules.js';
import { flame, params as flameParams } from './flame.js';

export const app = express();
app.use(cors());
app.use(express.json({ limit: '32kb' }));

const fail = (status, error) => Object.assign(new Error(error), { status });
const habitatFrom = async (req) => {
  const h = await repo.habitat(String(req.query.habitat ?? ''));
  if (!h) throw fail(400, `unknown habitat "${req.query.habitat ?? ''}"`);
  return h;
};

app.get('/health', async (_req, res) => {
  const db = await pool.query('SELECT 1').then(() => true, () => false);
  res.json({ ok: true, db, model: modelReady(), classifiers: classifiersReady() });
});

/** The team's catalog: experiments, PSI repositories, findings, incidents, PSI-166 investigations. */
app.get('/catalog', (_req, res) =>
  res.json((meta.extended_capabilities?.catalog_summary?.entries ?? []).filter((e) => e.is_verified !== false)),
);

/** Free text → research group + that group's required modifications (experiment_classifier.onnx). */
app.post('/classify/experiment', async (req, res) => {
  const { text } = ClassifyIn.parse(req.body);
  const out = await classifyText([text]);
  if (!out) throw fail(503, 'experiment classifier not loaded');
  res.json(out[0]);
});

/** PSI-166 EML melt telemetry → flow regime class + required modification (psi166_flow_classifier.onnx). */
app.post('/classify/psi166', async (req, res) => {
  const x = FlowIn.parse(req.body);
  const { results, model } = await classifyFlow([x]);
  res.json({ ...results[0], model });
});

app.get('/habitats', async (_req, res) => res.json(await repo.habitats()));

app.get('/experiments', async (req, res) => {
  const [all, counts] = await Promise.all([repo.experiments(), repo.pointCounts()]);
  if (!req.query.habitat) return res.json(all);
  const h = await habitatFrom(req);
  const max = Math.max(1, ...Object.values(counts));
  // The ranking holds investigations only; reference documents (standards) stay citable by the copilot.
  res.json(
    all
      .filter((e) => e.type !== 'reference')
      .map((e) => ({ ...e, ...scoreExperiment(h, e, counts[e.id] ?? 0, max) }))
      .sort((a, b) => b.score - a.score),
  );
});

app.get('/experiments/:id', async (req, res) => {
  const e = await repo.experiment(req.params.id);
  if (!e) throw fail(404, 'experiment not found');
  res.json(e);
});

app.get('/gapmap', async (req, res) => {
  await habitatFrom(req);
  res.json(await repo.testPoints());
});

app.get('/recommendations', async (req, res) => {
  const h = await habitatFrom(req);
  const points = await repo.testPoints();
  const cells = grid();
  const ranked = cells.map((cell) => {
    const near = pointsNear(cell, points);
    const fc = flame({ ...cell, pressure_kpa: h.pressure_psia * PSI_TO_KPA, flow_cm_s: CABIN_FLOW });
    // Physics extrapolated past every test is unverified: maximal uncertainty, whatever p it computes.
    const p = fc.extrapolated.length ? 0.5 : fc.p_burn;
    const f = priority(cell, h, near.length, p);
    return { cell, priority: f.priority, why: why(cell, f, near.length, fc), sources: [...new Set(near.map((t) => t.source))] };
  });
  // Spread the picks: skip cells within ±2 % O₂ of a better one at the same gravity.
  const picks = [];
  for (const r of ranked.sort((a, b) => b.priority - a.priority)) {
    const close = picks.some(
      (p) => p.cell.gravity_g === r.cell.gravity_g && Math.abs(p.cell.o2_pct - r.cell.o2_pct) <= 2,
    );
    if (!close) picks.push(r);
    if (picks.length === 5) break;
  }
  res.json(picks);
});

app.get('/model', (_req, res) => res.json(meta));

app.get('/flame/model', (_req, res) => res.json(flameParams));

app.post('/predict', async (req, res) => {
  const x = PredictIn.parse(req.body);
  const { p, model } = await predict([x]);
  res.set('X-Model-Domain', domainCheck(x).ok ? 'in' : 'out'); // contract body unchanged
  res.json({ p_burn: p[0], label: p[0] >= 0.5 ? 'burn' : 'extinct', model });
});

/** Physics flame forecast; `data_model` = the ISS-trained regression, only inside its training domain. */
app.post('/forecast', async (req, res) => {
  const x = PredictIn.parse(req.body);
  const data = domainCheck(x).ok ? await predict([x]) : null;
  res.json({ ...flame(x), data_model: data && { p_burn: data.p[0], model: data.model } });
});

app.post('/copilot', async (req, res) => {
  const { body, source } = await copilot(CopilotIn.parse(req.body));
  res.set('X-Copilot-Source', source).json(body);
});

app.use((_req, _res, next) => next(fail(404, 'not found')));
// Errors are always JSON; the process never dies on a request.
app.use((err, _req, res, _next) => {
  const status = err instanceof z.ZodError ? 400 : err.status ?? (err.type === 'entity.parse.failed' ? 400 : 500);
  if (status === 500) console.error(err);
  res.status(status).json({ error: err instanceof z.ZodError ? z.prettifyError(err) : err.message });
});
