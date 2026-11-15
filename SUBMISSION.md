# Space Apps 2026 submission — copy/paste fields

**Project name:** Habitat Fire Atlas
**Challenge:** Flame in Freefall: AI-Powered Fire Safety Insights from Microgravity Combustion Data
**Team:** Dartline Tech Racing · Saltillo

## High-level summary (≤ 150 words)

Fire behaves differently without gravity, and what was learned on the ISS does not transfer as-is to the Moon or
Mars. Habitat Fire Atlas turns decades of NASA microgravity combustion experiments into habitat-specific
fire-safety decisions. Pick a habitat (ISS, lunar base, rover, spacesuit) and the app ranks the 58 most relevant
investigations, forecasts whether each material burns at that oxygen, pressure, gravity and airflow with a
physics-informed model, maps where NASA has data and where it has none, and recommends the next experiment to run.
Because the raw PSI archive exceeds 1 TB, we built a predictive model on 347 curated test points that flags every
input outside its tested range. It runs on web and Android, offline, with NASA sources cited on every answer.

## Links

- Demo: https://web-production-29998460.up.railway.app
- Android APK: https://web-production-29998460.up.railway.app/download/habitat-fire-atlas.apk
- Repository: <GitHub URL>
- Video / slides: <link>

## Project details

**What it does / how it works.** Express + PostgreSQL API on Railway; Flutter app (one codebase, web + Android).
Five views: Habitat, Forecast, Ranking, Gap map, Copilot (+ Report and Lab). The flame model combines a U-shaped
oxygen limit versus airflow, buoyant flow proportional to g^⅓, a pressure term and de Ris spread scaling; it is
fitted to 156 solid-fuel burns (accuracy 0.78) and runs on-device. The recommender scores every O₂ × gravity cell
as data gap × closeness to the habitat × model uncertainty.

**Benefits.** Mission planners see, for their exact atmosphere (for example 8.2 psia / 34 % O₂ at 0.16 g), which
materials sustain a flame, how fast it spreads, which experiments back that claim, and which experiment is missing.

**Innovation.** GenUI answers built from a closed widget catalog; on-device inference (3–22 min Earth–Mars signal
delay); a gap map that turns model uncertainty into the next experiment to fly.

**Limitations (stated openly).** 193 of the 347 points are simulated values reconstructed by the team from cited
PSI/NTRS investigations, including all partial-gravity series; they are labelled in the app. The ONNX data model is
not cross-validated and has no gravity input, so the app only uses it inside the ISS envelope.

## Use of Artificial Intelligence

Product: scikit-learn models exported to ONNX; optional LLM phrasing grounded on retrieved NASA records with
citations (rule-based answers without a key). Development: Claude Code (Anthropic) used as a coding assistant;
data decisions and final review by the team.

## NASA data

NASA PSI repository (psi.nasa.gov); NTRS (ntrs.nasa.gov), e.g. NASA/TM-2015-218735 (BASS); NASA Researcher's
Guide: Combustion Science (2015). Investigations: BASS / BASS-II, SoFIE, SAFFIRE, FLEX / FLEX-2, ACME, SAME / DAFT,
LUCI, NASA-STD-6001B.

## Space agency partner data

<fill in if used>
