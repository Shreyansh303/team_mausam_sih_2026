# 11 · Impact numbers — sourced external statistics for Slide 5

Supplies the ⚠️ external statistics that [`10_SIH_DECK_CONTENT.md`](10_SIH_DECK_CONTENT.md) §Slide 5
leaves as placeholders. Everything here was **looked up and cited**, not recalled.

Two conventions carried over from the rest of this repo:

- ✅ = **measured in this repository**, traceable to [`QA_REPORT.md`](QA_REPORT.md) or a command you
  can re-run.
- 🔎 = **external statistic with a citation below.** Use the citation on the slide or in the
  appendix. Do not put an unsourced number in front of a judge.

Collected **2026-09-10**. Figures with a year in them (app rating, internet users) drift — re-check
the two items under [Verify before printing](#verify-before-printing) close to the presentation.

---

## Block A · The problem is a *delivery* problem — and the evidence is IMD's own store page

The strongest opening available, because it is not opinion: it is the incumbent's own review page.

| Metric | Value |
|---|---|
| Mausam app rating | **3.13 / 5** from **4.4k ratings** 🔎 |
| Downloads since launch (27 Jul 2020) | **~990,000** 🔎 |
| India active internet users | **958 million**, ~8% YoY growth 🔎 |
| Mausam's penetration of that base | **≈ 0.1%** (derived from the two rows above) |

### Recurring complaints in those reviews → the feature that answers each

Every complaint below is a **ranking or comprehension** problem, which is precisely the problem
statement.

| Complaint about Mausam today 🔎 | What this prototype ships |
|---|---|
| *"No way to mark a location as favourite"* — the Favourites screen exists but nothing can be added to it | `saved_places` card + Places page, up to 8 locations, live local time per place ✅ |
| *"UI needs improvement… information only up to district level"* | 33 ranked cards at coordinate level, 212-city offline gazetteer ✅ |
| *"Graphs and charts need to be more understandable"* | 15 renderer kinds — gauges, timelines, tide curves — each with a one-line insight **and an action** ✅ |
| *"Options don't work properly and take too long to load"* | Warm `/home` **2 ms** server-side · **34.5 KB** payload · **13.5 KB** under `?lite=1` ✅ |
| *"Confusion during login — expected OTP on mobile, it went to email"* | Guest-first onboarding: no login required to reach your home screen ✅ |

> **Line to say out loud:** "IMD's data is world-class. Its app scores 3.1 out of 5. The gap is not
> meteorology — it is that the screen does not answer anyone's actual question. Every complaint on
> that store page is a ranking or comprehension problem."

---

## Block B · The harm that first-screen warnings address

| Hazard | Annual toll in India | Cards that catch it |
|---|---|---|
| **Lightning** | **2,558 deaths (2023)** — 39.7% of all **6,444** "forces of nature" deaths. Worst states: MP 397 · Bihar 345 · Odisha 294 · UP 287 · Jharkhand 194 🔎 | `warnings` + `nowcast`, pinned for **every** persona at orange+ ✅ |
| **Fog / low visibility road accidents** | **~15,115 deaths (2024)** per MoRTH — ⚠️ **verify the exact table**, see below 🔎 | `visibility` · `storm_fog_alert` · `commute_conditions` ✅ |
| **Heatwave** | **459** official deaths (2024); independent count **733 deaths + 40,000+ heatstroke cases** across 17 states; 2025: **455**. Official range 500–1,500/yr and **widely accepted as grossly undercounted** 🔎 | `heat_alert` (NWS heat index, 4 levels) · `best_workout_window` ✅ |
| **Monsoon-dependent agriculture** | **~46%** of the workforce · **51%** of net sown area is rainfed · **~45%** has no assured irrigation · rainfed land produces **~40%** of food 🔎 | `soil_moisture` · `rainfall_outlook` · `frost_alert` · `planting_guidance` (7 agro-zones × 12 months) ✅ |

> **The undercounting point argues for the product.** If heat deaths are undercounted partly because
> nobody is watching the right number at the right time, then a card reading *"Heat level: Danger —
> drink water every 30 minutes"* at 13:00 is an intervention, not a readout.

---

## Block C · The multiplier — what a better last mile is worth

From the Global Commission on Adaptation, WMO and the UN. These turn a prototype into a
national-scale argument.

| Finding 🔎 | Figure |
|---|---|
| **24 hours' notice of a storm or heatwave cuts the resulting damage by** | **30%** |
| Benefit–cost ratio of multi-hazard early warning systems | **1 : 9** — every $1 returns ~$9 net |
| $800M spent on early warning in developing countries averts | **$3–16 billion / year** in losses |
| Globally, better forecasts + warnings + climate information could save | **23,000 lives/year** and **$162 billion/year** |
| Advance warnings could prevent | **$13B** asset losses/yr + wellbeing gains worth **$22B** of income |
| People still uncovered by early warning | **1 in 3** globally |
| UN "Early Warnings for All" deadline | **end of 2027** |

> **The bridge sentence — the single most important line on the slide:**
>
> *"India already has the warning. IMD issues it. The UN's own number for closing the last mile is
> **30% less damage** and a **9:1 return**. Our contribution is measured: from the moment a warning
> is issued it is pinned above every user's own preferences and served in **17.7 ms** — to a farmer,
> a beachgoer and a parent alike."*

The second half of that sentence is measured in this repo ✅, which is why it lands.

---

## Block D · "OUR PROMISE" — impact model with the arithmetic visible

Selected finale decks earn this slide with visible arithmetic. Do the same, and **put the
assumptions on the slide** so the claim survives Q&A.

```
ADDRESSABLE BASE
  India active internet users                            958,000,000   🔎 IAMAI/TRAI 2025
  Agriculture workforce share                                    46%   🔎 PLFS
  Net sown area that is rainfed                                  51%   🔎 MoA&FW
  Mausam downloads today                                    ~990,000   🔎 AppBrain
  → Current reach of India's official weather app:            ~0.10%

WARNING-ADDRESSABLE ANNUAL TOLL  (the three hazards our cards pin)
  Lightning deaths (2023)                                       2,558   🔎 NCRB
  Fog / low-visibility road deaths (2024)                     ~15,115   🔎 MoRTH  ⚠️ verify
  Heat deaths (2024, independent count)                           733   🔎 DTE
  ──────────────────────────────────────────────────────────────────────
  Total                                                       ~18,406

APPLY THE UN / GCA MULTIPLIER  (24 h notice → 30% less damage)
  Upper bound, if every affected person received and acted on
  a first-screen warning:                       0.30 × 18,406 ≈ 5,500 lives / year

THE HONEST DISCOUNT — PUT THIS ON THE SLIDE TOO
  We do not claim 5,500. We deliver warnings, we do not generate them, and
  reach is a function of adoption. What we claim is the mechanism:
    • the warning is FIRST, not findable     urgency ≥ 0.8 pins for all 8 personas   ✅
    • it arrives 17.7 ms after being issued  measured, QA step 5e                    ✅
    • it survives a bad network              offline cache + 13.5 KB lite mode       ✅
    • it is understood                       insight + action, Hindi 91/96 strings   ✅
  Every 1% of that 5,500 which personalization actually converts is 55 lives a year.
```

> **Why the "every 1% is 55 lives" construction is the right move:** it gives a judge a number to
> hold, while the slide itself states the discount. A precise fake number gets destroyed in Q&A; an
> honest bound with visible arithmetic does not.

---

## Block E · Growth and adoption

| Metric | Figure | Why it earns slide space |
|---|---|---|
| India active internet users | **958M**, ~8% YoY 🔎 | The base is not the constraint |
| Rural internet users | **~548M**, growing **~4× faster than urban** 🔎 | Exactly the cohort the low-bandwidth + offline + Hindi work targets |
| Smartphone owners | **1.14B**, projected **1.5B by 2026** 🔎 | Device access is not the constraint |
| Village 3G/4G coverage | **~95%** (≈80% 5G) 🔎 | Connectivity is not the constraint |
| Mausam's share of that base | **~0.1%** | **Product experience is the constraint — and that is this PS** |
| Devices this build supports | **Android 7.0+ (minSdk 24)**, 3 ABIs ✅ | Does not exclude the cohort that needs it most |
| Languages | **5 offered, 2 complete** (606 backend + 353 app strings each) ✅ | Remaining scheduled languages are translation work, not engineering |

> **Framing line:** "958 million people online. 1.14 billion smartphones. 95% of villages with 4G.
> And India's official weather app has reached 0.1% of them, at 3.1 stars. Nothing about that is a
> distribution problem."

---

## Verify before printing

Two items carry the most weight and are the most likely to be challenged.

1. **The fog fatality figure.** "15,115 deaths in foggy conditions (2024)" comes from press coverage
   of MoRTH's annual report, and press summaries routinely conflate **accidents** with
   **fatalities**. Open [Road Accidents in India 2024](https://morth.gov.in/backend/documents/uploaded/1781177676_V1gUW8tJWT.pdf),
   find the weather-condition table, and screenshot it into the appendix. It is the largest number in
   Block D, so it is the one a judge will test. For cross-reference, the
   [data.gov.in series](https://www.data.gov.in/resource/year-wise-total-number-road-accidents-due-foggy-and-misty-weather-condition-country-2019)
   gives accidents by year 2019–2022, and one state-level report (Assam) gives 2,476 fog fatalities
   over 2020–2024 — useful for a sanity check on national scale.

2. **The Mausam store rating.** **3.13 / 5 from 4.4k ratings** is the best single asset on the slide
   and it moves over time. Take a **dated screenshot** of
   [the Play Store page](https://play.google.com/store/apps/details?id=com.imd.masuam) and put it in
   the appendix; a live rating that has shifted by presentation day is an avoidable own goal.

---

## Sources

**Hazard tolls**
- NCRB 2023, lightning and forces of nature — [Down To Earth summary](https://www.downtoearth.org.in/natural-disasters/lightning-strikes-took-over-2500-lives-in-2023-ncrb-data) · [ADSI 2023 full report (PDF)](https://www.ncrb.gov.in/uploads/files/1ADSIPublication-2023.pdf)
- MoRTH — [Road Accidents in India 2024 (PDF)](https://morth.gov.in/backend/documents/uploaded/1781177676_V1gUW8tJWT.pdf) · [fog/mist accident dataset, data.gov.in](https://www.data.gov.in/resource/year-wise-total-number-road-accidents-due-foggy-and-misty-weather-condition-country-2019)
- Heat — [733 deaths and 40,000+ heatstroke cases, 2024](https://www.downtoearth.org.in/climate-change/seeing-red-india-had-over-700-heat-deaths-in-2024-much-higher-than-official-toll-claim-scientists) · [official undercounting](https://www.pbs.org/newshour/world/india-likely-undercounts-heat-related-deaths-tempering-its-response-officials-say)

**Early-warning value**
- [UN Secretary-General — 24 h notice cuts damage 30%](https://press.un.org/en/2022/sgsm21574.doc.htm)
- [WMO — Early Warnings for All](https://wmo.int/all-activities/build-resilience/early-warnings-all)
- [WMO — hydromet investments save lives and make economic sense (1:9)](https://wmo.int/news/media-centre/hydromet-investments-save-lives-and-make-economic-sense)

**The incumbent app**
- [Mausam — downloads and 3.13★ rating](https://www.appbrain.com/app/mausam/com.imd.masuam)
- [Mausam on Google Play](https://play.google.com/store/apps/details?id=com.imd.masuam)

**Agriculture**
- [Rainfed Farming Division, MoA&FW](https://agriwelfare.gov.in/en/RainfedDiv)
- [Agriculture workforce share and monsoon dependence](https://www.businesstoday.in/india/story/inside-indias-agricultural-matrix-how-the-monsoon-shapes-farming-cycle-crop-yields-528584-2026-05-02)

**Reach**
- [India internet users 958M, rural growth (IAMAI)](https://bestmediainfo.com/insights/indias-internet-users-near-one-billion-in-2025-rural-india-leads-growth-iamai-11056899)
- [TRAI urban/rural internet penetration](https://www.adgully.com/post/1049/urban-internet-penetration-exceeds-111-rural-lagging-at-4499-trai-report)
