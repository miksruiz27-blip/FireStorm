// p_burn from models/model.onnx (onnxruntime-node); falls back to the logistic regression in model.json.
import { existsSync, readFileSync } from 'node:fs';

const file = (f) => new URL(`../models/${f}`, import.meta.url);
export const meta = JSON.parse(readFileSync(file('model.json'), 'utf8'));
let session = null;

/** Feature order + burn column come from model.json, never hardcoded. */
const burnIndex = Math.max(0, (meta.classes ?? ['extinct', 'burn']).indexOf(meta.positive_class ?? 'burn'));

export async function loadModel() {
  if (!existsSync(file('model.onnx'))) return console.warn('model.onnx missing → regression fallback');
  try {
    const ort = await import('onnxruntime-node');
    session = await ort.InferenceSession.create(file('model.onnx').pathname.replace(/^\/(\w:)/, '$1'));
    session.ort = ort;
  } catch (e) {
    console.warn('model.onnx failed to load → fallback:', e.message);
    session = null;
  }
}
export const modelReady = () => session !== null;

const sigmoid = (z) => 1 / (1 + Math.exp(-z));
export const fallbackP = (x) =>
  sigmoid(x.reduce((s, v, j) => s + meta.coef[j] * ((v - meta.mean[j]) / meta.std[j]), meta.intercept));

/** rows: [{o2_pct, pressure_kpa, flow_cm_s, gravity_g}] → { p: number[], model } */
export async function predict(rows) {
  const x = rows.map((r) => meta.features.map((f) => Number(r[f] ?? 0)));
  if (session) {
    try {
      const k = meta.features.length;
      const input = new session.ort.Tensor('float32', Float32Array.from(x.flat()), [x.length, k]);
      const out = await session.run({ [session.inputNames[0]]: input });
      const probs = (out.probabilities ?? out[session.outputNames.at(-1)]).data;
      return { p: x.map((_, i) => Number(probs[i * 2 + burnIndex])), model: 'onnx' };
    } catch (e) {
      console.warn('onnx run failed → fallback:', e.message);
    }
  }
  return { p: x.map(fallbackP), model: 'fallback' };
}

/** Training data: ISS only (g = 0, per the model team) and each feature within ±3σ of its mean.
 * Outside it the regression extrapolates (e.g. 70 kPa → p ≈ 0), so callers must not trust p. */
export function domainCheck(row) {
  const reasons = meta.features.flatMap((f, j) => {
    const v = Number(row[f] ?? 0);
    return Math.abs((v - meta.mean[j]) / meta.std[j]) > 3
      ? [`${f} ${+v.toFixed(1)} (trained ${+meta.mean[j].toFixed(1)} ± ${+meta.std[j].toFixed(1)})`]
      : [];
  });
  const g = Number(row.gravity_g ?? 0);
  if (g > (meta.train_gravity_g ?? 0) + 0.01) reasons.push(`gravity ${g} g (trained ${meta.train_gravity_g ?? 0} g)`);
  return { ok: reasons.length === 0, reasons };
}
