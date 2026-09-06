# PROGRESS (living checklist — agents tick items; orchestrator resumes from here)

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked (say why in Notes)

## Resume instructions (for a fresh orchestrator session)
1. Read `CLAUDE.md`, this file, `docs/07_PHASES.md`.
2. `git status` / `git log --oneline` to see the last checkpoint.
3. Spawn the next phase whose box is not `[x]`, following the order in 07. A1 ∥ B0 may run in parallel; so may A2 ∥ B1 and A3 ∥ B2.
4. Implementation agents run on the Opus model. The orchestrator only plans, reviews reports, and commits.

## Phase status
- [ ] A1 backend data layer
- [ ] A2 engine + home + auth + events + i18n
- [ ] A3 live alerts + admin + deploy + CI
- [ ] B0 flutter toolchain + scaffold
- [ ] B1 app foundation + onboarding + home skeleton
- [ ] B2 full card system + map + places + WS + events
- [ ] B3 integration + APK + CI
- [ ] C1 e2e QA
- [ ] C2 docs + pitch
- [ ] S* stretch

## A1 checklist
- [ ] skeleton + venv + deps + .env.example + Dockerfile
- [ ] config/core (cache, timeutil, geo, i18n loader)
- [ ] providers: open_meteo forecast/air/marine/geocode · bigdatacloud · rainviewer · imd · scenarios
- [ ] data files: cities.json ≥150 · coastal_points.json ≥80 · planting_calendar.json · imd_ids.json · scenarios (10)
- [ ] services: snapshot + aqi_cpcb + comfort/heat/dew + workout + school_commute + commute/traffic + frost + packing + planting + tides + pollen + marine + visibility + flight_risk + nowcast + warnings
- [ ] routers: health, locations, weather/snapshot, weather/radar
- [ ] recorded fixtures + offline tests green

## A2 checklist
- [ ] DB models + sqlite init · JWT guest/OTP · /me, /me/card-prefs, /me/places
- [ ] engine: catalog (02 matrix) · context · scoring · explain · learning
- [ ] 33 builders · /home (all params) · /events
- [ ] i18n en + hi complete
- [ ] docs/fixtures/home_<persona>.json ×8 + home_severe.json + home_coastal.json
- [ ] tests: 03 §tests ×9 + API flows

## A3 checklist
- [ ] admin routes + console · WS manager + /ws/alerts · global scenario/now-override
- [ ] infra/docker-compose.yml · infra/render.yaml · .github/workflows/backend.yml
- [ ] backend README section (run, env, IMD whitelisting, deploy)
- [ ] tests: admin→home pinned · ws warning_issued · expiry · lite

## B0 checklist
- [ ] scripts/setup_flutter_windows.ps1 + flutter_env.ps1/.sh
- [ ] Flutter + JDK + Android SDK installed under D:\sdk; `flutter doctor` OK
- [ ] `flutter create` scaffold with Android config · .gitignore · docs/SETUP_WINDOWS.md
- [ ] `flutter build web` and `flutter build apk --debug` succeed

## B1 checklist
- [ ] packages · theme · router · riverpod · models · api client · cache · repos (+fixture fallback)
- [ ] onboarding (language, personas, location) · settings (backend URL, language)
- [ ] home: shell, chips, banner, freshness, offline banner, hero/warnings/hourly/daily/metric/generic renderers, why sheet UI
- [ ] l10n en/hi scaffolding · analyze/test/build web · screenshot docs/screenshots/b1_home.png

## B2 checklist
- [ ] all renderers + detail pages · animations · events pipeline · why-sheet actions
- [ ] places page · map page (radar + warnings) · settings complete · demo sheet · WS client · low-bandwidth · a11y
- [ ] l10n en/hi complete · icon/splash · screenshots per persona

## B3 checklist
- [ ] live backend integration, contract mismatches fixed · WS reorder verified in web build
- [ ] release APK built · .github/workflows/flutter.yml · README app section

## C1 / C2
- [ ] QA_REPORT.md with every demo step verified
- [ ] README final · 08_PITCH.md · pptx

## Deviations from spec (record here)
(none yet)

## Notes for next phase
(none yet)
