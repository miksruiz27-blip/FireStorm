// The LLM only writes `answer` (≤60 words) and picks source numbers. Cloud first, then Ollama. 10 s each.
import { LlmOut } from '../schemas.js';

const SYSTEM =
  'You are the Habitat Fire Atlas copilot. Answer in at most 60 words, grounded only in the numbered NASA sources. ' +
  'Reply with JSON only: {"answer": "...", "cite": [numbers]}. Cite only numbers from the list.';

const prompt = ({ question, habitat, widgets, sources }) =>
  [
    `Question: ${question}`,
    `Habitat: ${habitat.name} · ${habitat.o2_pct} % O2 · ${habitat.pressure_psia} psia · ${habitat.gravity_g} g`,
    `Physics flame forecast (state it; say "untested" if extrapolated): ${widgets[0].body}`,
    `Widgets shown: ${widgets.map((w) => w.title ?? `${w.type}${w.kind ? ` ${w.kind}` : ''}`).join('; ')}`,
    'Sources:',
    ...sources.map((s) => `[${s.n}] ${s.title}${s.text ? ` — ${s.text}` : ''}`),
  ].join('\n');

const post = async (url, headers, body, ms) => {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(ms),
  });
  if (!r.ok) throw new Error(`${url} → ${r.status}`);
  return r.json();
};

const providers = {
  anthropic: async (user, ms) => {
    const j = await post(
      'https://api.anthropic.com/v1/messages',
      { 'x-api-key': process.env.LLM_API_KEY, 'anthropic-version': '2023-06-01' },
      { model: process.env.LLM_MODEL || 'claude-opus-5-5', max_tokens: 400, system: SYSTEM, messages: [{ role: 'user', content: user }] },
      ms,
    );
    return j.content?.find((c) => c.type === 'text')?.text;
  },
  // Any OpenAI-compatible API (OpenAI, Groq, …): set LLM_BASE_URL + LLM_MODEL.
  openai: async (user, ms) => {
    const j = await post(
      `${process.env.LLM_BASE_URL || 'https://api.openai.com/v1'}/chat/completions`,
      { authorization: `Bearer ${process.env.LLM_API_KEY}` },
      { model: process.env.LLM_MODEL, messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: user }] },
      ms,
    );
    return j.choices?.[0]?.message?.content;
  },
  ollama: async (user, ms) => {
    const j = await post(
      `${process.env.OLLAMA_URL}/api/chat`,
      {},
      { model: process.env.OLLAMA_MODEL || 'llama3.1', stream: false, format: 'json',
        messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: user }] },
      ms,
    );
    return j.message?.content;
  },
};

const parse = (text) => {
  const r = LlmOut.safeParse(JSON.parse(text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1)));
  if (!r.success) throw new Error('invalid LLM JSON');
  const words = r.data.answer.trim().split(/\s+/);
  return { answer: words.length > 60 ? `${words.slice(0, 60).join(' ')}…` : words.join(' '), cite: r.data.cite };
};

/** → { answer, cite, source: 'llm'|'ollama' } or null. Never throws. */
export async function askLLM(ctx, budgetMs = 12000) {
  const deadline = Date.now() + budgetMs;
  const attempts = [];
  const cloud = providers[process.env.LLM_PROVIDER];
  if (cloud && process.env.LLM_API_KEY) attempts.push(['llm', cloud]);
  if (process.env.OLLAMA_URL) attempts.push(['ollama', providers.ollama]);
  const user = prompt(ctx);
  for (const [source, call] of attempts) {
    const ms = Math.min(10000, deadline - Date.now());
    if (ms < 500) break;
    try {
      return { ...parse(await call(user, ms)), source };
    } catch (e) {
      console.warn(`copilot ${source} failed:`, e.message);
    }
  }
  return null;
}
