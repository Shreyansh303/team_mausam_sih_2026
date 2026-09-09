import '../core/formatters.dart';
import 'gen/app_localizations.dart';

/// Enum-ish values that arrive inside `Card.data` (docs/02 §Per-card specification) are
/// **not** localized by the backend — only titles, subtitles, insights and reasons are
/// (docs/04 §preamble `lang`). This file is where those band names become UI text.
///
/// Every lookup falls back to `Fmt.humanize`, so a value a later backend adds shows up as
/// readable English rather than a blank chip.
String aqiBandLabel(L l, String? key) => switch (key) {
      'good' => l.aqiGood,
      'satisfactory' => l.aqiSatisfactory,
      'moderate' => l.aqiModerate,
      'poor' => l.aqiPoor,
      'very_poor' || 'very poor' => l.aqiVeryPoor,
      'severe' => l.aqiSevere,
      _ => Fmt.humanize(key),
    };

String comfortBandLabel(L l, String? key) => switch (key) {
      'uncomfortable' => l.comfortUncomfortable,
      'fair' => l.comfortFair,
      'comfortable' => l.comfortComfortable,
      'ideal' => l.comfortIdeal,
      _ => Fmt.humanize(key),
    };

String soilBandLabel(L l, String? key) => switch (key) {
      'very_dry' => l.soilVeryDry,
      'dry' => l.soilDry,
      'adequate' => l.soilAdequate,
      'wet' => l.soilWet,
      'saturated' => l.soilSaturated,
      _ => Fmt.humanize(key),
    };

/// docs/02 card 16 `sea_state` — the Douglas scale names.
String seaStateLabel(L l, String? key) => switch (key) {
      'calm' => l.seaCalm,
      'smooth' => l.seaSmooth,
      'slight' => l.seaSlight,
      'moderate' => l.seaModerate,
      'rough' => l.seaRough,
      'very_rough' || 'very rough' => l.seaVeryRough,
      'high' => l.seaHigh,
      _ => Fmt.humanize(key),
    };

/// docs/02 card 12 `best_workout_window.windows[].label` — a quality, not a window name.
String qualityLabel(L l, String? key) => switch (key?.toLowerCase()) {
      'great' => l.qualityGreat,
      'good' => l.qualityGood,
      'fair' => l.qualityFair,
      'poor' => l.qualityPoor,
      // docs/02 cards 22/28 speak `good|caution|poor|avoid` and `low|moderate|high|severe`
      // through the same field, so both ladders resolve here.
      'caution' => l.verdictCaution,
      'avoid' => l.verdictAvoid,
      'low' || 'medium' || 'moderate' || 'high' || 'severe' || 'none' => levelLabel(l, key),
      _ => Fmt.humanize(key),
    };

/// low | medium | high — used by travel risk, commute impact and frost risk.
///
/// Two more ladders arrive through the same field and are resolved here rather than in a
/// second helper, because `AlertSpec.of` reads every alert card's band with this one call:
/// docs/02 card 15 `heat_alert.level` is the NWS heat-index ladder
/// (`caution|extreme_caution|danger|extreme_danger`) and docs/02 card 25
/// `storm_fog_alert.level` is `watch|warning`. Neither had an arm, so both fell through to
/// `Fmt.humanize` and drew English inside an otherwise-Hindi card.
String levelLabel(L l, String? key) => switch (key?.toLowerCase()) {
      'low' => l.levelLow,
      'medium' => l.levelMedium,
      'moderate' => l.levelModerate,
      'high' => l.levelHigh,
      'severe' => l.levelSevere,
      'none' => l.levelNone,
      'caution' => l.heatLevelCaution,
      'extreme_caution' => l.heatLevelExtremeCaution,
      'danger' => l.heatLevelDanger,
      'extreme_danger' => l.heatLevelExtremeDanger,
      'watch' => l.stormLevelWatch,
      'warning' => l.stormLevelWarning,
      _ => Fmt.humanize(key),
    };

/// docs/02 card 21 `rain_alert.intensity`.
String intensityLabel(L l, String? key) => switch (key?.toLowerCase()) {
      'light' => l.intensityLight,
      'moderate' => l.intensityModerate,
      'heavy' => l.intensityHeavy,
      'very_heavy' => l.intensityVeryHeavy,
      _ => Fmt.humanize(key),
    };

/// docs/04 §Objects `Warning.hazard`.
String hazardLabel(L l, String? key) => switch (key) {
      'heavy_rain' => l.hazardHeavyRain,
      'very_heavy_rain' => l.hazardVeryHeavyRain,
      'thunderstorm' => l.hazardThunderstorm,
      'lightning' => l.hazardLightning,
      'heatwave' => l.hazardHeatwave,
      'cold_wave' => l.hazardColdWave,
      'fog' => l.hazardFog,
      'dust_storm' => l.hazardDustStorm,
      'cyclone' => l.hazardCyclone,
      'strong_wind' => l.hazardStrongWind,
      'snow' => l.hazardSnow,
      'flood' => l.hazardFlood,
      _ => Fmt.humanize(key),
    };

/// `winter | pre_monsoon | monsoon | post_monsoon` (docs/03 §Context).
String seasonLabel(L l, String? key) => switch (key) {
      'winter' => l.seasonWinter,
      'pre_monsoon' => l.seasonPreMonsoon,
      'monsoon' => l.seasonMonsoon,
      'post_monsoon' => l.seasonPostMonsoon,
      _ => Fmt.humanize(key),
    };

/// docs/04 §Objects `User.school_windows[].label` / `commute_windows[].label`, and the same
/// names inside cards 22 and 28.
String windowLabel(L l, String? key) => switch (key) {
      'morning_drop' => l.windowMorningDrop,
      'afternoon_pickup' => l.windowAfternoonPickup,
      'morning' => l.windowMorning,
      'evening' => l.windowEvening,
      'early_morning' => l.windowEarlyMorning,
      'late_morning' => l.windowLateMorning,
      'afternoon' => l.windowAfternoon,
      'night' => l.windowNight,
      _ => Fmt.humanize(key),
    };

/// docs/04 §Objects `Card.severity` (info|advisory|watch|warning|severe) and
/// `Warning.severity` (yellow|orange|red).
String severityLabel(L l, String? key) => switch (key) {
      'info' => l.severityInfo,
      'advisory' => l.severityAdvisory,
      'watch' => l.severityWatch,
      'warning' => l.severityWarning,
      'severe' => l.severitySevere,
      'yellow' => l.severityYellow,
      'orange' => l.severityOrange,
      'red' => l.severityRed,
      _ => Fmt.humanize(key),
    };
