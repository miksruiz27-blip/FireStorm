// Fit the flame model to the DB (test_points + material_moc) → models/flame.json. `--remote` for Railway.
import { writeFileSync } from 'node:fs';
import 'dotenv/config';
import { pool } from '../src/db.js';
import { fit } from '../src/flame.js';
import * as repo from '../src/repo.js';

const [points, mocs] = await Promise.all([repo.testPoints(), repo.mocs()]);
const params = fit(points, mocs);
params.source = `fitted on ${params.metrics.n} solid-fuel test points + ${mocs.length} MOC rows (${new Date().toISOString().slice(0, 10)})`;
writeFileSync(new URL('../models/flame.json', import.meta.url), `${JSON.stringify(params, null, 1)}\n`);
console.log(params.metrics, { q: params.q, u_star: params.u_star, s: params.s, b: params.b, k_p: params.k_p });
await pool.end();
