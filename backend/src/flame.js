// Physics-informed flame model for solid fuels (opposed-flow flame spread).
// Parameters live in models/flame.json, fitted to test_points + material_moc by scripts/fit_flame.js.
//
//  u_buoy = U1g · g^(1/3)                 buoyant flow a flame induces (≈ 30 cm/s at 1 g)
//  u_eff  = √(u_forced² + u_buoy²)        what the flame actually "sees"
//  LOI    = MOC_min + q·ln²(u_eff/u*) + kP·ln(101.3/P)
//           U-shaped in flow: oxygen-starved (quench) below u*, blow-off above; MOC_min comes from
//           the material's 1 g MOC test. Lower pressure → higher limit.
//  p_burn = σ((O₂ − LOI)/s)
//  spread = c_material · (O₂ − LOI) · (u_eff/10)^b     de Ris thin-fuel scaling (∝ flame-temperature excess)
import { existsSync, readFileSync } from 'node:fs';

const P_REF = 101.3;
const file = new URL('../models/flame.json', import.meta.url);
export const params = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')) : null; // null until the first fit

const sigmoid = (z) => 1 / (1 + Math.exp(-z));
const r = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;

// Specimen names in the data → modelled material ("SIBAL_Cotton_Fiberglass_75_25_Opposed" → cotton-fiberglass fabric).
export const ALIASES = {
  pmma: 'pmma|acrylic|plexiglas',
  'cotton-fiberglass fabric': 'sibal|cotton.?fiberglass',
  'aramid fabric': 'nomex|aramid|kevlar',
  silicone: 'silicone',
};

/** Modelled material for a name: exact key, alias pattern, or a key the name starts with; null if none. */
export const matchMaterial = (name = '', P = params) => {
  const n = String(name).toLowerCase();
  const keys = Object.keys(P.materials);
  return (
    keys.find((k) => k === n) ??
    keys.find((k) => P.aliases?.[k] && new RegExp(P.aliases[k], 'i').test(n)) ??
    keys.find((k) => n.startsWith(k) || k.startsWith(n.split(' ')[0])) ??
    null
  );
};
/** Same, falling back to the default material. */
export const materialKey = (name = '', P = params) => matchMaterial(name, P) ?? P.default_material;

/** LOI (% O₂) for a material at effective flow u (cm/s) and pressure (kPa). */
export function loi(material, u, pressure_kpa, P = params) {
  const m = P.materials[material];
  const lnu = (x) => Math.log(Math.max(P.u_min, x) / P.u_star) ** 2;
  // moc_1g was measured in 1 g quiescent air, i.e. at u_eff = U1g.
  return m.moc_1g + P.q * (lnu(u) - lnu(P.u_buoy_1g)) + P.k_p * Math.log(P_REF / pressure_kpa);
}

export function flame({ o2_pct, pressure_kpa, gravity_g = 0, flow_cm_s = 0, material }, P = params) {
  const key = materialKey(material, P);
  const u_buoy = P.u_buoy_1g * Math.cbrt(Math.max(0, gravity_g));
  const u_eff = Math.max(P.u_min, Math.hypot(flow_cm_s ?? 0, u_buoy));
  const limit = loi(key, u_eff, pressure_kpa, P);
  const margin = o2_pct - limit;
  const p_burn = sigmoid(margin / P.s);
  const spread = margin > 0 ? P.materials[key].c * margin * (u_eff / 10) ** P.b : 0;
  const f = P.fit_range;
  const extrapolated = [
    (o2_pct < f.o2_pct[0] - 2 || o2_pct > f.o2_pct[1] + 2) && `O₂ ${o2_pct} % (tested ${f.o2_pct.join('–')})`,
    (pressure_kpa < f.pressure_kpa[0] - 5 || pressure_kpa > f.pressure_kpa[1] + 5) &&
      `pressure ${r(pressure_kpa, 1)} kPa (tested ${f.pressure_kpa.join('–')})`,
    !f.gravity_g.some((g) => Math.abs(g - gravity_g) < 0.05) && `gravity ${gravity_g} g (tested ${f.gravity_g.join(', ')} g)`,
  ].filter(Boolean);
  return {
    material: P.materials[key].name ?? key,
    p_burn: r(p_burn),
    regime: margin < -1 ? 'self-extinguishes' : margin < 1 ? 'marginal' : margin < 5 ? 'sustained' : 'vigorous',
    // Why it dies, when it does: too little flow brings too little oxygen; too much blows it off.
    limit_side: u_eff < P.u_star ? 'oxygen-starved' : 'blow-off',
    loi_pct: r(limit, 2),
    margin_pct: r(margin, 2),
    spread_mm_s: r(spread, 2),
    u_buoy_cm_s: r(u_buoy, 1),
    u_eff_cm_s: r(u_eff, 1),
    extrapolated,
  };
}

// ── fit ──
// Gas/liquid fuels and burner emulators of solids are not solid-fuel burns.
const SOLID = (t) => !/heptane|methane|ethylene|ethanol|methanol|propane|butane|pentane|hydrogen|decane|octane|emulat|droplet/i.test(t.material);
const range = (xs) => [Math.min(...xs), Math.max(...xs)];
const groupBy = (xs, key) => xs.reduce((g, x) => ((g[key(x)] ??= []).push(x), g), {});
const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

/** points: test_points rows; mocs: material_moc rows → params (+ metrics). Solid fuels only. */
export function fit(points, mocs, { u_buoy_1g = 30, u_min = 0.5, default_material = 'pmma' } = {}) {
  // kP from materials measured at two pressures; MOC normalised to 101.3 kPa.
  const byMat = groupBy(mocs, (m) => m.material.toLowerCase());
  const slopes = Object.values(byMat).flatMap((rows) =>
    rows.length < 2 ? [] : rows.slice(1).map((b) => (b.moc_pct - rows[0].moc_pct) / Math.log(rows[0].pressure_kpa / b.pressure_kpa)),
  ).filter(Number.isFinite);
  const k_p = slopes.length ? slopes.reduce((a, b) => a + b) / slopes.length : 2.5;
  const materials = Object.fromEntries(
    Object.entries(byMat).map(([k, rows]) => [
      k,
      { name: rows[0].material, moc_1g: r(rows.reduce((s, m) => s + m.moc_pct - k_p * Math.log(P_REF / m.pressure_kpa), 0) / rows.length, 2), c: 0 },
    ]),
  );
  const aliases = Object.fromEntries(Object.keys(materials).flatMap((k) => (ALIASES[k] ? [[k, ALIASES[k]]] : [])));
  // Only burns of a material we have a MOC for: anything else would be fitted against the wrong limit.
  const solid = points.filter((t) => SOLID(t) && matchMaterial(t.material, { materials, aliases }));
  const base = { u_buoy_1g, u_min, k_p: r(k_p), default_material, materials, aliases, b: 0.3, fit_range: {} };

  // q, u*: grid search on mean log-loss of burn/extinct + ridge on the curvature q.
  // ponytail: s fixed at ±1 % O₂ (MOC test repeatability) and ridge 0.02·q², because a small separable
  // sample alone would push the limit to a step function. Refit both once the real dataset is in.
  const s = 1;
  let best = null;
  for (let q = 0.25; q <= 3; q += 0.25)
    for (const u_star of [3, 5, 7, 10, 15, 20]) {
      const P = { ...base, q, u_star, s, fit_range: { o2_pct: [0, 100], pressure_kpa: [0, 999], gravity_g: [] } };
      const loss = solid.reduce((acc, t) => {
        const p = Math.min(1 - 1e-6, Math.max(1e-6, flame(t, P).p_burn));
        return acc - Math.log(t.outcome === 'burn' ? p : 1 - p);
      }, 0) / solid.length;
      const obj = loss + 0.02 * q * q;
      if (!best || obj < best.obj - 1e-9) best = { obj, loss, q, u_star };
    }
  Object.assign(base, { q: best.q, u_star: best.u_star, s });
  base.fit_range = { o2_pct: [0, 100], pressure_kpa: [0, 999], gravity_g: [] };

  // b + per-material c: least squares on measured spread rates.
  const spread = solid.filter((t) => t.spread_rate_mm_s != null);
  const zOf = (t, b) => {
    const f = flame(t, base);
    return Math.max(0, f.margin_pct) * (f.u_eff_cm_s / 10) ** b;
  };
  let bestB = null;
  for (let b = 0; b <= 1.0001; b += 0.05) {
    const c = {};
    for (const [k, rows] of Object.entries(groupBy(spread, (t) => materialKey(t.material, base)))) {
      const zz = rows.reduce((s, t) => s + zOf(t, b) ** 2, 0);
      c[k] = zz ? rows.reduce((s, t) => s + zOf(t, b) * t.spread_rate_mm_s, 0) / zz : 0;
    }
    const sse = spread.reduce((s, t) => s + (c[materialKey(t.material, base)] * zOf(t, b) - t.spread_rate_mm_s) ** 2, 0);
    if (!bestB || sse < bestB.sse) bestB = { b, c, sse };
  }
  base.b = r(bestB.b, 2);
  const fallbackC = median(Object.values(bestB.c).filter((c) => c > 0)) ?? 0.3;
  for (const [k, m] of Object.entries(materials)) m.c = r(bestB.c[k] || fallbackC);

  // Tested envelope: the burns plus the MOC tests (1 g, quiescent, at their pressures).
  base.fit_range = {
    o2_pct: range(solid.map((t) => t.o2_pct)),
    pressure_kpa: range([...solid.map((t) => t.pressure_kpa), ...mocs.map((m) => m.pressure_kpa)]),
    gravity_g: [...new Set([...solid.map((t) => t.gravity_g), ...(mocs.length ? [1] : [])])].sort((a, b) => a - b),
  };
  const correct = solid.filter((t) => (flame(t, base).p_burn >= 0.5) === (t.outcome === 'burn')).length;
  base.metrics = {
    n: solid.length,
    accuracy: r(correct / solid.length, 2),
    log_loss: r(best.loss),
    n_spread: spread.length,
    spread_rmse_mm_s: r(Math.sqrt(bestB.sse / Math.max(1, spread.length)), 2),
  };
  return base;
}
