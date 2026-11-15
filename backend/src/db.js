import 'dotenv/config';
import pg from 'pg';

// --remote: scripts run from your machine against Railway's public proxy.
const url = process.argv.includes('--remote')
  ? process.env.DATABASE_PUBLIC_URL
  : process.env.DATABASE_URL;
const host = url ? new URL(url).hostname : 'localhost';
const internal = host.endsWith('.railway.internal') || host === 'localhost' || host === '127.0.0.1';

export const pool = new pg.Pool({
  connectionString: url,
  ssl: internal ? false : { rejectUnauthorized: false },
  connectionTimeoutMillis: 5000,
});
pool.on('error', (e) => console.error('pg pool:', e.message));

export const q = async (sql, params) => (await pool.query(sql, params)).rows;
