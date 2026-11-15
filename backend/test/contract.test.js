// Contract tests against DATABASE_URL. If one fails, fix the backend, not the test.
import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import request from 'supertest';
import { z } from 'zod';
import { app } from '../src/app.js';
import { pool } from '../src/db.js';
import { copilot } from '../src/genui/copilot.js';
import { Experiment, GenUI, Habitat, TestPoint } from '../src/schemas.js';

after(() => pool.end());
const exact = (schema, body) => {
  const r = schema.safeParse(body);
  assert.ok(r.success, r.success ? '' : z.prettifyError(r.error));
};

test('GET /health', async () => {
  const r = await request(app).get('/health').expect(200);
  exact(
    z.object({ ok: z.literal(true), db: z.literal(true), model: z.boolean(), classifiers: z.object({ experiment: z.boolean(), flow: z.boolean() }).strict() }).strict(),
    r.body,
  );
});

test('GET /habitats', async () => {
  exact(z.array(Habitat.strict()).min(1), (await request(app).get('/habitats').expect(200)).body);
});

test('GET /experiments?habitat=lunar → scored, sorted desc', async () => {
  const { body } = await request(app).get('/experiments?habitat=lunar').expect(200);
  const Scored = Experiment.extend({
    score: z.number().min(0).max(1),
    score_breakdown: z.object({ conditions: z.number(), safety: z.number(), data: z.number() }).strict(),
  }).strict();
  exact(z.array(Scored).min(1), body);
  const scores = body.map((e) => e.score);
  assert.deepEqual(scores, [...scores].sort((a, b) => b - a));
});

test('GET /experiments/:id and 404 JSON', async () => {
  exact(Experiment.strict(), (await request(app).get('/experiments/bass-ii').expect(200)).body);
  assert.ok((await request(app).get('/experiments/nope').expect(404)).body.error);
});

test('GET /gapmap?habitat=lunar', async () => {
  exact(z.array(TestPoint.strict()).min(1), (await request(app).get('/gapmap?habitat=lunar').expect(200)).body);
  assert.ok((await request(app).get('/gapmap?habitat=mars').expect(400)).body.error);
});

test('GET /recommendations?habitat=lunar → top 5', async () => {
  const { body } = await request(app).get('/recommendations?habitat=lunar').expect(200);
  const Rec = z
    .object({
      cell: z.object({ o2_pct: z.number(), gravity_g: z.number() }).strict(),
      priority: z.number(),
      why: z.string().min(1),
      sources: z.array(z.string()),
    })
    .strict();
  exact(z.array(Rec).length(5), body);
});

test('GET /model', async () => {
  const { body } = await request(app).get('/model').expect(200);
  for (const k of ['features', 'mean', 'std', 'coef', 'intercept', 'positive_class', 'metrics']) assert.ok(k in body, k);
});

test('POST /predict validates physical ranges', async () => {
  const { body } = await request(app)
    .post('/predict')
    .send({ o2_pct: 34, pressure_kpa: 56.5, flow_cm_s: 0, gravity_g: 0.166 })
    .expect(200);
  exact(
    z.object({ p_burn: z.number().min(0).max(1), label: z.enum(['burn', 'extinct']), model: z.enum(['onnx', 'fallback']) }).strict(),
    body,
  );
  await request(app).post('/predict').send({ o2_pct: 130, pressure_kpa: 70, flow_cm_s: 0, gravity_g: 0 }).expect(400);
});

test('GET /catalog + POST /classify/*', async () => {
  const { loadClassifiers } = await import('../src/classifiers.js');
  await loadClassifiers();
  assert.equal((await request(app).get('/catalog').expect(200)).body.length, 81);
  const e = (await request(app).post('/classify/experiment').send({ text: 'water mist fire suppression' }).expect(200)).body;
  assert.equal(e.group, 'WaterMist_SCWM_Suppression');
  assert.ok(e.modifications.length);
  await request(app).post('/classify/experiment').send({ text: '' }).expect(400);
  const flow = { temperature_k: 955, diameter_mm: 6.5, max_velocity_m_s: 0.00024, max_shear_rate_s: 0.547, reynolds_number: 0.0098, mhd_max_force_n_m3: 10432 };
  const f = (await request(app).post('/classify/psi166').send(flow).expect(200)).body;
  assert.equal(f.class, 'Laminar_Subcritical_Diffusion_Safe');
  assert.ok(f.modification.length);
  await request(app).post('/classify/psi166').send({ ...flow, reynolds_number: -1 }).expect(400);
});

test('POST /copilot without LLM → template, valid GenUI, real citations', async () => {
  const r = await request(app)
    .post('/copilot')
    .send({ question: 'Which materials stay safe at 34% oxygen?', habitat: 'lunar' })
    .expect(200);
  exact(GenUI, r.body);
  assert.ok(r.body.citations.length >= 1);
  for (const c of r.body.citations) assert.ok(c.title && c.ref && /^https?:\/\//.test(c.url), JSON.stringify(c));
  if (!process.env.LLM_API_KEY && !process.env.OLLAMA_URL) assert.equal(r.headers['x-copilot-source'], 'template');
  await request(app).post('/copilot').send({ question: '', habitat: 'lunar' }).expect(400);
});

test('copilot: LLM down → template still valid', async () => {
  const { body, source } = await copilot({ question: 'How does oxygen affect flame spread?', habitat: 'lunar' }, { llm: async () => null });
  exact(GenUI, body);
  assert.equal(source, 'template');
  assert.match(body.answer, /^Con base en \d+ fuentes de NASA/);
});

test('copilot: an LLM citation outside the list is discarded', async () => {
  const fake = async () => ({ answer: 'Grounded answer.', cite: [99, 1], source: 'llm' });
  const { body, source } = await copilot({ question: 'What has been tested?', habitat: 'lunar' }, { llm: fake });
  exact(GenUI, body);
  assert.equal(source, 'llm');
  assert.deepEqual(body.citations.map((c) => c.n), [1]);
});

test('copilot: an LLM answer with no resolvable citation is rejected → template', async () => {
  const fake = async () => ({ answer: 'Ungrounded answer.', cite: [99], source: 'llm' });
  const { body, source } = await copilot({ question: 'What has been tested?', habitat: 'lunar' }, { llm: fake });
  exact(GenUI, body);
  assert.equal(source, 'template');
  assert.notEqual(body.answer, 'Ungrounded answer.');
});
