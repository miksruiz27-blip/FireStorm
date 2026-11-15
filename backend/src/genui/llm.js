// The LLM only writes `answer` (≤60 words) and picks source numbers. Cloud first, then Ollama. 10 s each.
import { LlmOut } from '../schemas.js';

const LANGUAGE = { en: 'English', es: 'Spanish' };
const system = (lang = 'en') =>
  `You are the FireStorm copilot. Respond in ${LANGUAGE[lang] ?? 'English'}, whatever the language of the question. ` +
  'Answer in at most 60 words, grounded only in the numbered NASA sources and the widgets. ' +
  'Answer exactly what was asked, using the widget made for it: the ambient table for comparisons, ' +
  'the suggested next tests for what to test, the SAFE/BURNS cards for materials, the forecast for what-ifs. ' +
  'Give the verdict first, then at most 2-3 numbers from the widgets with symbols (%, mm/s, g). ' +
  'If coverage says there is no test data, say once that it is physics extrapolation, untested. ' +
  'Plain prose: no brackets, no markdown, no lists, no source numbers in the text. ' +
  'Call the pressurized environment an "ambient" (e.g. "this ambient", "across ambients"); never say "habitat". ' +
  'Reply with JSON only: {"answer": "...", "cite": [numbers]}. Cite only numbers from the list.';

const describe = (w) =>
  w.type === 'answer_card' ? `${w.title}: ${w.body}`
  : w.type === 'metrics' ? `Key numbers: ${w.items.map((i) => `${i.label} ${i.value} ${i.unit}`).join(', ')}`
  : w.type === 'table' ? `${w.title}: ${w.rows.map((r) => r.join(' / ')).join('; ')}`
  : w.type === 'next_tests' ? `Suggested next tests: ${w.items.map((i) => `${i.title} (priority ${i.priority})`).join('; ')}`
  : w.type === 'chart' ? `Chart (${w.kind}): ${w.y} by ${w.x}`
  : null;

const prompt = ({ question, habitat, widgets, sources, coverage, retry }) =>
  [
    `Question: ${question}`,
    `Ambient: ${habitat.name} · ${habitat.o2_pct} % O2 · ${habitat.pressure_psia} psia · ${habitat.gravity_g} g`,
    ...(coverage ? [`Coverage: ${coverage}`] : []),
    // Materials question: both lists, always, even if one is empty.
    ...(widgets.some((w) => /^(SAFE|SEGUROS) /.test(w.title ?? ''))
      ? ['Give both lists from the SAFE and BURNS cards (MOC above vs at/below the ambient O2), even if one is empty.']
      : []),
    'Widgets shown (rule-built from the physics model and NASA data; the first card is the physics forecast):',
    ...widgets.map(describe).filter(Boolean).map((d) => `- ${d}`),
    'Sources:',
    ...sources.map((s) => `[${s.n}] ${s.title}${s.text ? ` — ${s.text}` : ''}`),
    ...(retry ? ['Your previous reply cited no valid source. "cite" MUST contain at least one number from the Sources list.'] : []),
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
  anthropic: async (user, ms, SYSTEM) => {
    const j = await post(
      'https://api.anthropic.com/v1/messages',
      { 'x-api-key': process.env.LLM_API_KEY, 'anthropic-version': '2023-06-01' },
      { model: process.env.LLM_MODEL || 'claude-opus-5-5', max_tokens: 400, system: SYSTEM, messages: [{ role: 'user', content: user }] },
      ms,
    );
    return j.content?.find((c) => c.type === 'text')?.text;
  },
  // Any OpenAI-compatible API (OpenAI, Groq, …): set LLM_BASE_URL + LLM_MODEL.
  openai: async (user, ms, SYSTEM) => {
    const j = await post(
      `${process.env.LLM_BASE_URL || 'https://api.openai.com/v1'}/chat/completions`,
      { authorization: `Bearer ${process.env.LLM_API_KEY}` },
      { model: process.env.LLM_MODEL, messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: user }] },
      ms,
    );
    return j.choices?.[0]?.message?.content;
  },
  ollama: async (user, ms, SYSTEM) => {
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
  // Models sometimes emit a stray "\u" (not followed by 4 hex digits): escape it instead of losing the answer.
  const json = text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1).replace(/\\u(?![0-9a-fA-F]{4})/g, '\\\\u');
  const r = LlmOut.safeParse(JSON.parse(json));
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
  const SYSTEM = system(ctx.lang);
  for (const [source, call] of attempts) {
    const ms = Math.min(10000, deadline - Date.now());
    if (ms < 500) break;
    try {
      return { ...parse(await call(user, ms, SYSTEM)), source };
    } catch (e) {
      console.warn(`copilot ${source} failed:`, e.message);
    }
  }
  return null;
}
