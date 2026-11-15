// Pure scoring functions. See README for the one-line rationale of each term.
export const PSI_TO_KPA = 6.89476;
export const GRAVITY_GRID = [0, 0.165, 0.38, 1];
const EXPERIMENT_G = { micro: 0, lunar: 0.165, mars: 0.38, earth: 1 };
const round = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;

/** 1 inside [lo,hi], linear decay to 0 at `span` outside. */
export const closeness = (v, [lo, hi], span) =>
  v >= lo && v <= hi ? 1 : Math.max(0, 1 - Math.min(Math.abs(v - lo), Math.abs(v - hi)) / span);

export function scoreExperiment(h, e, points, maxPoints) {
  const g = EXPERIMENT_G[e.gravity] ?? 0;
  const conditions =
    (closeness(h.o2_pct, e.o2_range, 10) +
      closeness(h.pressure_psia * PSI_TO_KPA, e.pressure_kpa_range, 50) +
      Math.max(0, 1 - Math.abs(h.gravity_g - g))) / 3;
  const safety = new Set(e.domain).size / 3;
  const data = maxPoints ? points / maxPoints : 0;
  return {
    score: round(0.5 * conditions + 0.3 * safety + 0.2 * data),
    score_breakdown: { conditions: round(conditions), safety: round(safety), data: round(data) },
  };
}

/** Tests within ±1 % O₂ at the same gravity. */
export const pointsNear = (cell, points) =>
  points.filter((t) => Math.abs(t.o2_pct - cell.o2_pct) <= 1 && Math.abs(t.gravity_g - cell.gravity_g) < 0.05);

/** priority = data gap × closeness to habitat × model uncertainty (1 − |2p − 1|). */
export function priority(cell, h, nearCount, p) {
  const gap = 1 / (1 + nearCount);
  const near = Math.exp(-(Math.abs(cell.o2_pct - h.o2_pct) / 10 + Math.abs(cell.gravity_g - h.gravity_g)));
  const uncertainty = 1 - Math.abs(2 * p - 1);
  return { priority: round(gap * near * uncertainty), gap: round(gap), near: round(near), uncertainty: round(uncertainty) };
}

export function grid() {
  return GRAVITY_GRID.flatMap((gravity_g) =>
    // O₂ 15–40 % plus the pure-oxygen column (suits, pre-breathe).
    [...Array.from({ length: 26 }, (_, i) => 15 + i), 100].map((o2_pct) => ({ o2_pct, gravity_g })),
  );
}

/** fc: flame forecast at the cell (habitat pressure, cabin flow). */
export const why = (c, f, n, fc) =>
  `${n ? `${n} test${n > 1 ? 's' : ''} nearby` : 'No tests'} at ${c.o2_pct} % O₂ / ${c.gravity_g} g (gap ${f.gap}); ` +
  `closeness to habitat ${f.near}; physics: ${fc.regime} (limit ${fc.loi_pct} %, p ${fc.p_burn})` +
  (fc.extrapolated.length ? ', extrapolated — a test here would confirm it.' : `, uncertainty ${f.uncertainty}.`);
