import { readdir, readFile } from 'node:fs/promises';
import { pool } from '../src/db.js';

const dir = new URL('../db/migrations/', import.meta.url);
await pool.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz DEFAULT now())');
const done = new Set((await pool.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name));
for (const name of (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort()) {
  if (done.has(name)) continue;
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    await c.query(await readFile(new URL(name, dir), 'utf8'));
    await c.query('INSERT INTO schema_migrations (name) VALUES ($1)', [name]);
    await c.query('COMMIT');
    console.log('applied', name);
  } catch (e) {
    await c.query('ROLLBACK');
    throw e;
  } finally {
    c.release();
  }
}
console.log('migrations up to date');
await pool.end();
