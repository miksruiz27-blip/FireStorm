// Offline fallback for the app: BASE_URL → ../assets/snapshot/*.json
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import 'dotenv/config';

const base = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const out = new URL('../../assets/snapshot/', import.meta.url);
const get = async (path, init) => {
  const r = await fetch(base + path, init);
  if (!r.ok) throw new Error(`${path} → ${r.status} ${await r.text()}`);
  return r.json();
};
const save = (name, data) => writeFile(new URL(name, out), `${JSON.stringify(data, null, 1)}\n`);

await mkdir(out, { recursive: true });
const habitats = await get('/habitats');
const per = async (path) =>
  Object.fromEntries(await Promise.all(habitats.map(async (h) => [h.id, await get(`${path}?habitat=${h.id}`)])));
const questions = JSON.parse(await readFile(new URL('../data/guion_preguntas.json', import.meta.url), 'utf8'));

await save('habitats.json', habitats);
await save('experiments.json', await per('/experiments'));
await save('recommendations.json', await per('/recommendations'));
await save('test_points.json', await get(`/gapmap?habitat=${habitats[0].id}`));
await save('model.json', await get('/model'));
await save('flame.json', await get('/flame/model'));
await save('catalog.json', await get('/catalog'));
const cache = [];
for (const q of questions) {
  const response = await get('/copilot', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ question: q, habitat: 'lunar' }),
  });
  cache.push({ q, response });
}
await save('copilot_cache.json', cache);
console.log(`snapshot from ${base} → assets/snapshot/ (${habitats.length} habitats, ${cache.length} copilot answers)`);
