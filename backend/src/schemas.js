import { z } from 'zod';

// CSV cells arrive as strings: '' → null, numbers coerced.
const num = z.coerce.number().finite();
const optNum = z.preprocess((v) => (v === '' || v === undefined ? null : v), num.nullable());
// CSV arrays: JSON ("[1,2]") or "a|b".
const arr = (item) =>
  z.preprocess(
    (v) => (typeof v !== 'string' ? v : v.trim().startsWith('[') ? JSON.parse(v) : v.split('|').filter(Boolean)),
    z.array(item),
  );
const range = arr(num).pipe(z.array(z.number()).length(2));
const source = z.string().trim().min(1, 'missing source');

export const Habitat = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  o2_pct: num,
  pressure_psia: num,
  gravity_g: num,
  source,
});

export const SourceRef = z.object({
  title: z.string().min(1),
  ntrs_id: z.coerce.string(),
  url: z.string(),
});

export const Experiment = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  platform: z.string(),
  fuel_type: z.enum(['solid', 'liquid', 'gas']),
  domain: arr(z.enum(['prevention', 'detection', 'suppression'])).pipe(z.array(z.string()).min(1)),
  hardware: z.string(),
  o2_range: range,
  pressure_kpa_range: range,
  gravity: z.string().default('micro'),
  flow_cm_s_range: range,
  materials: arr(z.string()).default([]),
  key_findings: arr(z.string()).default([]),
  modifications: arr(z.string()).default([]),
  research_group: z.string().default(''),
  is_verified: z.boolean().default(true),
  type: z.enum(['investigation', 'reference']).default('investigation'),
  sources: arr(SourceRef).pipe(z.array(SourceRef).min(1, 'missing source')),
});

export const TestPoint = z.object({
  experiment_id: z.string().min(1),
  material: z.string().min(1),
  o2_pct: num,
  pressure_kpa: num,
  gravity_g: num,
  flow_cm_s: optNum,
  outcome: z.enum(['burn', 'extinct']),
  spread_rate_mm_s: optNum,
  source,
  is_verified: z.boolean().default(true),
});

export const MaterialMoc = z.object({
  material: z.string().min(1),
  moc_pct: num,
  pressure_kpa: num,
  source,
});

export const PredictIn = z.object({
  o2_pct: z.number().min(0).max(100),
  pressure_kpa: z.number().positive(),
  flow_cm_s: z.number().min(0),
  gravity_g: z.number().min(0).max(1),
  material: z.string().optional(),
});

export const ClassifyIn = z.object({ text: z.string().trim().min(3).max(2000) });

/** PSI-166 EML melt telemetry, physical units (the classifier takes log10 of the last four). */
export const FlowIn = z.object({
  temperature_k: z.number().positive(),
  diameter_mm: z.number().positive(),
  max_velocity_m_s: z.number().positive(),
  max_shear_rate_s: z.number().positive(),
  reynolds_number: z.number().positive(),
  mhd_max_force_n_m3: z.number().positive(),
});

export const CopilotIn = z.object({
  question: z.string().trim().min(1).max(500),
  habitat: z.string().min(1),
  lang: z.enum(['en', 'es']).default('en'), // answer language (the app's EN/ES switch)
});

// ── GenUI ──
const Level = z.enum(['info', 'warning', 'critical']);
export const Widget = z.discriminatedUnion('type', [
  z.object({ type: z.literal('answer_card'), title: z.string(), body: z.string(), level: Level }),
  z.object({
    type: z.literal('chart'),
    kind: z.enum(['scatter', 'bar', 'line']),
    x: z.string(),
    y: z.string(),
    points: z.array(z.tuple([z.union([z.number(), z.string()]), z.number()])),
    measured: z.array(z.tuple([z.number(), z.number()])).optional(), // line: test points over the predicted curve
    threshold: z.number().optional(), // bar: habitat O₂ line; above = safe, at/below = burns
  }),
  z.object({ type: z.literal('experiment_list'), ids: z.array(z.string()) }),
  z.object({ type: z.literal('coverage'), text: z.string() }),
  z.object({
    type: z.literal('metrics'),
    items: z.array(z.object({ label: z.string(), value: z.string(), unit: z.string(), level: Level.optional() })).min(1),
  }),
  z.object({
    type: z.literal('table'),
    title: z.string(),
    columns: z.array(z.string()).min(1),
    rows: z.array(z.array(z.string())),
    highlight: z.number().int().optional(),
  }),
  z.object({
    type: z.literal('next_tests'),
    items: z.array(z.object({ title: z.string(), priority: z.number(), body: z.string() })),
  }),
  z.object({ type: z.literal('follow_ups'), questions: z.array(z.string()) }),
]);

export const GenUI = z.object({
  answer: z.string().min(1),
  widgets: z.array(Widget).min(1),
  // Only resolvable sources: a real title, a PSI/NTRS ref and an http(s) link.
  citations: z.array(
    z.object({ n: z.number().int().positive(), title: z.string().min(1), ref: z.string().min(1), url: z.url() }),
  ),
});

export const LlmOut = z.object({
  answer: z.string().min(1),
  cite: z.array(z.number().int()),
});
