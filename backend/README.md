# FireStorm · API

Express + Postgres (Railway) + ONNX. Flutter app → this API → Postgres.

## Run locally

```bash
cp .env.example .env      # DATABASE_URL = Railway public proxy URL (or local Postgres)
npm install
npm run migrate && npm run seed
npm start                 # http://localhost:3000/health
npm test                  # unit + contract tests (needs DATABASE_URL)
```

`npm run db:reset` drops, migrates and seeds (refuses a Railway URL unless `--force`).

## Deploy (Railway)

The project `firestorm` has two services: `Postgres` and `api`.
- `railway.json` runs `npm run migrate` as the pre-deploy step, then starts the server and health-checks `/health`.
- `api` variables: `DATABASE_URL=${{Postgres.DATABASE_URL}}`, plus `LLM_PROVIDER` and `LLM_API_KEY` if you want LLM answers. Do not set `OLLAMA_URL` there.
- Deploy: `railway up --service api` from `backend/`.
- Seed: `npm run seed:remote` from your machine, which uses `DATABASE_PUBLIC_URL`.
- Snapshot: `BASE_URL=https://<domain> npm run snapshot` writes the offline fallback to `../assets/snapshot/`.

## Data

`data/<table>.json` or `.csv` for `habitats`, `experiments`, `test_points` and `material_moc`.
- CSV arrays are written as JSON (`[21,35]`) or as `a|b`.
- Every row is validated with zod. Invalid rows, and rows without a `source`, are listed and skipped.
- The seed upserts in one transaction, so it can be re-run safely. `--replace` empties experiments + test_points first.
- **Team drop**: `npm run import` reads `../firestorm_modelos_y_csv_equipo/` and writes `data/experiments.json` (58, one per test-id prefix or prefix group, e.g. LUNA/MARS partial-g series; names, findings and modifications from the catalog) and `data/test_points.json` (347, incl. 29 at 0.16 g and 19 at 0.38 g; spread rates for the solid PSI rows). It also copies the 3 ONNX models + `model.json` into `models/`. Then `npm run migrate && npm run seed -- --replace && npm run fit`, deploy, snapshot.
- Rows whose test-id prefix appears in `psi_repositories_simulated.csv` (PSI*, LUNA, MARS, SOFIE-*, …) carry "simulated values (team dataset)" in their source.
- `material_moc` and `habitats` are still the SAMPLE values from the mockups. The old sample experiments are in `data/sample_backup/`.

## Team classifiers (`src/classifiers.js`)

- `POST /classify/experiment {text}` → research group (12 classes), top 3, and that group's required modifications (`experiment_classifier.onnx`, string input).
- `POST /classify/psi166 {temperature_k, diameter_mm, max_velocity_m_s, max_shear_rate_s, reynolds_number, mhd_max_force_n_m3}` → flow class + required correction (`psi166_flow_classifier.onnx`, log10 of the last four). Falls back to the linear softmax in `model.json`.
- `GET /catalog` → the 70 catalog entries. The app shows all three on the Lab screen.
- Copilot: questions about modifications, redesign or lessons add a "Required modifications" card from the retrieved experiments.

## Scoring

`score = 0.5·conditions + 0.3·safety + 0.2·data`
- **conditions**: how close the habitat is to the experiment's test envelope. It averages three terms:
  - O₂: 1 inside the range, falling to 0 at 10 points outside;
  - pressure: same rule, falling to 0 at 50 kPa outside (habitat psia × 6.89476);
  - gravity: 1 − |Δg|, where `micro` counts as 0 g.
- **safety**: how many of the three domains (prevention, detection, suppression) the experiment covers, divided by 3.
- **data**: the experiment's test points divided by the maximum any experiment has.

`priority = gap × closeness × uncertainty`, computed over a grid of O₂ 15–40 % + 100 % × g ∈ {0, 0.165, 0.38, 1}.
- **gap** = 1 / (1 + tests within ±1 % O₂ at that g);
- **closeness** = e^−(|ΔO₂|/10 + |Δg|);
- **uncertainty** = 1 − |2p − 1|, where `p` is the model's p_burn at habitat pressure and flow 0.

## Flame model (the predictor)

`src/flame.js`: physics-informed forecast for solid fuels, any O₂ / pressure / gravity / flow / material. Parameters in `models/flame.json`, refit with `npm run fit -- --remote` after new data is seeded.
- `u_eff = √(flow² + (30·g^⅓)²)`: forced flow plus the buoyant flow the flame induces.
- `LOI = MOC + q·ln²(u_eff/u*) + kP·ln(101.3/P)`: U-shaped limit (oxygen-starved below u*, blow-off above); kP from MOC rows measured at two pressures.
- `p_burn = σ((O₂ − LOI)/s)`, `spread = c_material·(O₂ − LOI)·(u_eff/10)^b` (de Ris thin-fuel scaling).
- `extrapolated` lists every input outside the tested range; recommendations treat those cells as maximally uncertain.
- `GET /flame/model` returns the params (the app runs the same model offline, parity-tested). `POST /forecast` returns the full forecast plus `data_model` (the regression below, only inside its domain).
- The copilot forecasts at the habitat with 10 cm/s cabin ventilation, or at the question's what-if ("at 21% O2", "on Mars", "fans off", "8 psi", a material name).

## Data model (regression)

`src/model.js` loads `models/model.onnx` once. It reads the feature order and the `burn` column from `model.json`.
- Input `x`: float32 `[N, k]`. Output `probabilities`: `[N, 2]`.
- If the file is missing or fails, it uses the logistic regression in `model.json`: sigmoid(coef · (x − mean)/std + intercept).
- `/health.model` is true only when ONNX is loaded.

## Copilot (`POST /copilot {question, habitat}`)

Steps:
1. **Retrieve** experiments by full-text search on any question word. Fall back to the best-scoring experiments, and add the MOC sources. At most 8 numbered sources.
2. **Predict** p_burn at habitat O₂, pressure and gravity, with flow 0 (quiescent cabin air).
3. **Rules** in `src/genui/rules.js` build the widgets:
   - always a risk `answer_card`: ≥0.5 critical, ≥0.3 warning, otherwise info;
   - materials / safe / MOC → MOC `bar` chart plus a warning card listing materials whose MOC is below habitat O₂;
   - O₂ / flow / spread → `scatter` chart of spread rate (mm/s) against O₂;
   - experiments / evidence / tested, or no topic matched → `experiment_list` (max 5).
4. **LLM** returns only `{answer ≤60 words, cite:[n]}`. It tries the cloud provider first, then Ollama, 10 s each.
   - Citation numbers not in the list are dropped.
   - If the LLM fails, the answer comes from a template.
5. Citations are built from the DB list and the whole response is validated with zod.
   - The `X-Copilot-Source` header says `llm`, `ollama` or `template`.
