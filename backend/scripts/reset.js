// Local only: drop everything, then migrate + seed.
import { execSync } from 'node:child_process';
import { pool } from '../src/db.js';

if (process.env.DATABASE_URL?.includes('rlwy.net') && !process.argv.includes('--force')) {
  console.error('DATABASE_URL points to Railway. Pass --force to reset it anyway.');
  process.exit(1);
}
await pool.query('DROP TABLE IF EXISTS test_points, material_moc, experiments, habitats, schema_migrations CASCADE');
await pool.end();
execSync('node scripts/migrate.js && node scripts/seed.js', { stdio: 'inherit' });
