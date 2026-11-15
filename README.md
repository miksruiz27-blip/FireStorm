# FireStorm

**NASA Space Apps Challenge 2026 · Flame in Freefall** — team Dartline Tech Racing (Saltillo).

Decades of microgravity combustion results, turned into fire-safety decisions for lunar and Martian habitats:
**rank** the experiments that matter for a habitat's atmosphere, **forecast** whether a material burns there,
**map** where NASA has data and where it has none, and **recommend** the next experiment to run.

- **Live demo (web):** https://web-production-29998460.up.railway.app
- **Android APK (works offline):** https://web-production-29998460.up.railway.app/download/firestorm.apk
- **API:** https://api-production-34edefa4.up.railway.app/health

## Why a predictive model

The PSI repository experiments add up to more than 1 TB of raw data, impossible to ingest in a 36-hour
hackathon. Instead of processing everything, we built a model that generalises from **347 curated test
points** (NASA PSI / NTRS records) and **says where it does not know**: every forecast lists the inputs that fall
outside the tested range, and the gap map turns those blind spots into experiment recommendations.

## What it does

| Screen | What you get |
|---|---|
| Habitat | Pick ISS, Lunar Base, Pressurized Rover or Spacesuit; everything recalibrates to its O₂ / pressure / gravity |
| Forecast | Physics-informed flame model: p(burn), spread rate, flammability limit vs flow, per material; flags extrapolation |
| Ranking | 58 investigations ranked by condition overlap (50 %), safety domains (30 %), data density (20 %) |
| Gap map | Every test condition by O₂ × gravity (μg, Moon, Mars, Earth); hatched zones have no data; top-3 suggested experiments |
| Copilot | Ask in natural language; answer is built as UI widgets (GenUI) from a closed catalog, with NASA citations |
| Report / Lab | Per-investigation report with required design modifications; team classifiers (ONNX) |

## Models

| Model | Data | Metric | Notes |
|---|---|---|---|
| Physics flame model (`backend/src/flame.js`, ported to Dart) | 156 solid-fuel burns + 6 MOC tests | accuracy 0.78, spread RMSE 0.92 mm/s | LOI U-curve vs flow, buoyancy ∝ g^⅓, pressure term, de Ris spread scaling. Tested at 0, 0.16, 0.38, 1 g |
| Data model (`models/model.onnx`, team) | 347 points, features O₂ / pressure / flow | in-sample fit ≈ 1.0, **not cross-validated** | No gravity input: used only inside the ISS μg envelope |
| Experiment classifier (`experiment_classifier.onnx`, team) | 81-entry catalog | — | Text → research group + required modifications |
| PSI-166 flow classifier (`psi166_flow_classifier.onnx`, team) | 638 EML records | — | Flow regime + required correction |

**Data honesty.** 193 of the 347 test points (including every lunar and Martian series) come from the team's
`psi_repositories_simulated.csv`: values reconstructed from the cited PSI/NTRS investigations, not raw
measurements. The app labels each of them "simulated values (team dataset)" in its citations.

## Architecture

```
NASA PSI + NTRS → team CSVs + ONNX (firestorm_modelos_y_csv_equipo/)
  → backend/scripts/import_team.js → PostgreSQL (Railway)
  → Express API (Railway): ranking, gap map, forecast, copilot, classifiers
  → Flutter app (web + Android). Offline: bundled snapshot + the physics model running on-device.
```

## Run locally

```bash
# API (needs Postgres in backend/.env, see backend/.env.example)
cd backend && npm install && npm run migrate && npm run seed && npm start
# App
flutter pub get && flutter run -d chrome        # or an Android device
```

Tests: `cd backend && npm test` (27) · `flutter test` (15). Backend details: [backend/README.md](backend/README.md).

## Use of AI

- **In the product:** scikit-learn models exported to ONNX (team); a physics model fitted by grid search; the
  Copilot can phrase answers with an LLM (Claude or an OpenAI-compatible API, optional) but only from retrieved NASA
  records with numbered citations. Without an API key it answers from rules (the app labels it "Rule-based").
- **In development:** the team used Claude Code (Anthropic) as a coding assistant for the backend, the Flutter
  app, the data import and tests. All data choices and the final review are the team's.

## NASA data and references

- NASA Physical Science Informatics (PSI) repository — https://psi.nasa.gov
- NASA Technical Reports Server (NTRS) — https://ntrs.nasa.gov (e.g. BASS: NASA/TM-2015-218735, NTRS 20150016543)
- NASA Researcher's Guide: Combustion Science (2015)
- Investigations: BASS / BASS-II, SoFIE, SAFFIRE, FLEX / FLEX-2, ACME, SAME / DAFT, LUCI, NASA-STD-6001B
