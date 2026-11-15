// The team's two extra ONNX models (see model.json → extended_capabilities):
//  experiment_classifier.onnx    free text → research group (12) + that group's required modifications
//  psi166_flow_classifier.onnx   PSI-166 EML melt telemetry → flow regime / modification class (3)
import { existsSync } from 'node:fs';
import { meta } from './model.js';

const ext = meta.extended_capabilities ?? {};
const file = (f) => new URL(`../models/${f}`, import.meta.url);
const path = (f) => file(f).pathname.replace(/^\/(\w:)/, '$1');
const sessions = {};

export async function loadClassifiers() {
  const ort = await import('onnxruntime-node').catch(() => null);
  for (const [k, f] of [['experiment', 'experiment_classifier.onnx'], ['flow', 'psi166_flow_classifier.onnx']]) {
    if (!ort || !existsSync(file(f))) continue;
    try {
      sessions[k] = Object.assign(await ort.InferenceSession.create(path(f)), { ort });
    } catch (e) {
      console.warn(`${f} failed to load:`, e.message);
    }
  }
}
export const classifiersReady = () => ({ experiment: !!sessions.experiment, flow: !!sessions.flow });

const top = (probs, i, classes) => {
  const p = Array.from(probs.slice(i * classes.length, (i + 1) * classes.length), Number);
  const ranked = classes.map((c, j) => ({ class: c, p: +p[j].toFixed(4) })).sort((a, b) => b.p - a.p);
  return { class: ranked[0].class, p: ranked[0].p, ranked };
};

/** texts → [{ group, p, ranked, modifications, experiments }]; null if the model is not loaded. */
export async function classifyText(texts) {
  const s = sessions.experiment;
  const c = ext.experiment_classifier;
  if (!s || !c) return null;
  const out = await s.run({ [s.inputNames[0]]: new s.ort.Tensor('string', texts, [texts.length, 1]) });
  return texts.map((_, i) => {
    const t = top(out.probabilities.data, i, c.classes);
    const g = c.modifications_by_group?.[t.class] ?? {};
    return {
      group: t.class,
      p: t.p,
      ranked: t.ranked.slice(0, 3),
      category: g.categoria_principal ?? '',
      experiments: g.experimentos_incluidos ?? [],
      modifications: g.modificaciones_necesarias ?? [],
    };
  });
}

const FLOW_FEATURES = (r) => [
  r.temperature_k,
  r.diameter_mm,
  Math.log10(r.max_velocity_m_s),
  Math.log10(r.max_shear_rate_s),
  Math.log10(r.reynolds_number),
  Math.log10(r.mhd_max_force_n_m3),
];

/** Multinomial logistic regression from model.json (linear CV accuracy 0.98): used when the ONNX is missing. */
function flowFallback(x, m) {
  return x.map((row) => {
    const z = m.coef.map((w, k) => w.reduce((s, wj, j) => s + wj * ((row[j] - m.mean[j]) / m.std[j]), m.intercept[k]));
    const e = z.map((v) => Math.exp(v - Math.max(...z)));
    return e.map((v) => v / e.reduce((a, b) => a + b));
  });
}

/** rows: FlowIn[] → { results: [{ class, p, ranked, modification }], model } */
export async function classifyFlow(rows) {
  const m = ext.psi166_mhd_classifier;
  const x = rows.map(FLOW_FEATURES);
  const s = sessions.flow;
  let probs, model;
  if (s) {
    const out = await s.run({ [s.inputNames[0]]: new s.ort.Tensor('float32', Float32Array.from(x.flat()), [x.length, 6]) });
    probs = out.probabilities.data;
    model = 'onnx';
  } else {
    probs = flowFallback(x, m).flat();
    model = 'fallback';
  }
  return {
    model,
    results: rows.map((_, i) => {
      const t = top(probs, i, m.classes);
      return { ...t, modification: m.class_modifications?.[t.class] ?? '' };
    }),
  };
}
