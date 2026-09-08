// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class LBn extends L {
  LBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'মৌসম পার্সোনালাইজ়ড';

  @override
  String get onboardingLanguageTitle => 'আপনার ভাষা বেছে নিন';

  @override
  String get onboardingLanguageSubtitle =>
      'আপনি পরে সেটিংসে এটি বদলাতে পারবেন।';

  @override
  String get onboardingPersonaTitle => 'আমরা আপনার জন্য কী দেখব?';

  @override
  String get onboardingPersonaSubtitle => '১ থেকে ৩টি বাছুন। প্রথমটিই প্রধান।';

  @override
  String get onboardingLocationTitle => 'আপনি কোথায় আছেন?';

  @override
  String get onboardingLocationSubtitle =>
      'এর সাহায্যে আমরা আপনার এলাকার আবহাওয়া আনি।';

  @override
  String get continueLabel => 'এগিয়ে যান';

  @override
  String get back => 'পিছনে';

  @override
  String get finish => 'শেষ করুন';

  @override
  String get skip => 'এড়িয়ে যান';

  @override
  String get personaLimitReached => 'You can pick up to 3.';

  @override
  String get personaPrimary => 'Primary';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get useMyLocation => 'আমার অবস্থান ব্যবহার করুন';

  @override
  String get searchCity => 'শহর খুঁজুন';

  @override
  String get popularCities => 'জনপ্রিয় শহর';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Search for your city instead.';

  @override
  String get locationServicesOff =>
      'Location services are off. Turn them on or search for your city.';

  @override
  String get locatingYou => 'Finding you…';

  @override
  String get homeTitle => 'হোম';

  @override
  String get moreForYou => 'আপনার জন্য আরও';

  @override
  String get showMore => 'আরও দেখান';

  @override
  String get showLess => 'কম দেখান';

  @override
  String get details => 'বিস্তারিত';

  @override
  String get share => 'শেয়ার করুন';

  @override
  String get pinToTop => 'উপরে পিন করুন';

  @override
  String get unpin => 'পিন সরান';

  @override
  String get hideCard => 'এই কার্ড লুকান';

  @override
  String get restoreHidden => 'লুকানো কার্ড ফেরান';

  @override
  String get whyThisCard => 'এটি আমি কেন দেখছি?';

  @override
  String get drivenBy => 'যার কারণে';

  @override
  String get estimated => 'আনুমানিক';

  @override
  String get pinned => 'পিন করা';

  @override
  String get allClear => 'সব ঠিক আছে';

  @override
  String get offlineBanner => 'আপনি অফলাইনে — সংরক্ষিত তথ্য দেখানো হচ্ছে।';

  @override
  String get staleBanner => 'রিফ্রেশ করা যায়নি। সংরক্ষিত তথ্য দেখানো হচ্ছে।';

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get updatedJustNow => 'এইমাত্র হালনাগাদ';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Updated $hours h ago';
  }

  @override
  String get sampleDataBadge => 'নমুনা তথ্য';

  @override
  String viewingAs(String persona) {
    return 'Viewing as $persona';
  }

  @override
  String get saveRole => 'Save';

  @override
  String get clearRoleView => 'Clear';

  @override
  String get settingsTitle => 'সেটিংস';

  @override
  String get settingsLanguage => 'ভাষা';

  @override
  String get settingsBackendUrl => 'Backend URL';

  @override
  String get settingsBackendUrlHint => 'http://localhost:8000';

  @override
  String get settingsBackendUrlHelp =>
      'Point this at the machine running the FastAPI backend. On a phone use the PC\'s LAN IP.';

  @override
  String get settingsPersonas => 'আপনার আগ্রহ';

  @override
  String get settingsAbout => 'সম্পর্কে';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get saved => 'সংরক্ষিত';

  @override
  String get invalidUrl => 'Enter a valid http(s) URL.';

  @override
  String get errorGeneric => 'কিছু একটা ভুল হয়েছে।';

  @override
  String get errorNoData => 'No weather data available right now.';

  @override
  String get loading => 'লোড হচ্ছে…';

  @override
  String get personaHealth => 'স্বাস্থ্য';

  @override
  String get personaHealthTag => 'Air quality, pollen and health advice';

  @override
  String get personaFitness => 'ফিটনেস';

  @override
  String get personaFitnessTag => 'Best windows to run, ride or train';

  @override
  String get personaBeach => 'সমুদ্রতট';

  @override
  String get personaBeachTag => 'Waves, tides and sea temperature';

  @override
  String get personaTraveler => 'ভ্রমণকারী';

  @override
  String get personaTravelerTag => 'Saved places, packing and travel risk';

  @override
  String get personaParent => 'অভিভাবক';

  @override
  String get personaParentTag => 'School run, rain alerts and warnings';

  @override
  String get personaAgriculture => 'কৃষি';

  @override
  String get personaAgricultureTag => 'Soil, rainfall outlook and frost';

  @override
  String get personaCommuter => 'যাতায়াত';

  @override
  String get personaCommuterTag => 'Traffic, visibility and storms';

  @override
  String get personaEventPlanner => 'অনুষ্ঠান পরিকল্পক';

  @override
  String get personaEventPlannerTag => 'Long-range outlook and rain chance';

  @override
  String get severityInfo => 'Info';

  @override
  String get severityAdvisory => 'Advisory';

  @override
  String get severityWatch => 'Watch';

  @override
  String get severityWarning => 'Warning';

  @override
  String get severitySevere => 'Severe';

  @override
  String get feelsLike => 'অনুভূত';

  @override
  String get humidity => 'আর্দ্রতা';

  @override
  String get wind => 'বাতাস';

  @override
  String get uv => 'UV';

  @override
  String get aqi => 'AQI';

  @override
  String get sunrise => 'সূর্যোদয়';

  @override
  String get sunset => 'সূর্যাস্ত';

  @override
  String get high => 'সর্বোচ্চ';

  @override
  String get low => 'সর্বনিম্ন';

  @override
  String get rainChance => 'বৃষ্টি';

  @override
  String get next24Hours => 'পরের ২৪ ঘণ্টা';

  @override
  String get sevenDays => '৭ দিন';

  @override
  String validUntil(String time) {
    return 'Until $time';
  }

  @override
  String get pinnedToTop => 'Pinned to the top';

  @override
  String get unpinned => 'Unpinned';

  @override
  String get cardMenu => 'Card options';

  @override
  String learnedFromYou(int taps, int dismisses) {
    return 'You opened this $taps times and pushed it down $dismisses times.';
  }

  @override
  String rankScore(String score, String urgency) {
    return 'Rank score $score · urgency $urgency';
  }

  @override
  String get placesTitle => 'সংরক্ষিত স্থান';

  @override
  String placesSubtitle(int max) {
    return 'Weather for up to $max places you care about — they also power the traveller cards.';
  }

  @override
  String get placesEmpty => 'No saved places yet. Search below to add one.';

  @override
  String get placesAdd => 'Add a place';

  @override
  String placesFull(int max) {
    return 'You have reached the limit of $max saved places.';
  }

  @override
  String get placesAddFailed =>
      'Could not save that place. Check the backend connection.';

  @override
  String get placesRemoveFailed => 'Could not remove that place.';

  @override
  String get placeKindHome => 'Home';

  @override
  String get placeKindWork => 'Work';

  @override
  String get placeKindSchool => 'School';

  @override
  String get placeKindTravel => 'Travel';

  @override
  String get placeKindOther => 'Other';

  @override
  String get coastal => 'Coastal';

  @override
  String get remove => 'Remove';

  @override
  String get mapTitle => 'রাডার ও সতর্কতা';

  @override
  String get mapToggleRadar => 'Toggle the radar layer';

  @override
  String get mapAttribution =>
      'Base map © OpenStreetMap contributors · radar frames from RainViewer.';

  @override
  String get radarNoFrames => 'No radar frames available right now.';

  @override
  String get radarPastFrame => 'observed';

  @override
  String get radarForecastFrame => 'forecast';

  @override
  String get lowBandwidthRadarOff => 'Low-bandwidth mode: radar tiles are off.';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get openMap => 'Open map';

  @override
  String get settingsUnits => 'একক';

  @override
  String get unitsMetric => 'Metric (°C, km/h)';

  @override
  String get unitsImperial => 'Imperial (°F, mph)';

  @override
  String get settingsHomeLocation => 'Home location';

  @override
  String get settingsNoLocation => 'No location set';

  @override
  String get settingsPlacesSubtitle => 'Places you follow beyond home';

  @override
  String get settingsSchoolWindows => 'School run windows';

  @override
  String get settingsCommuteWindows => 'Commute windows';

  @override
  String get settingsAccessibility => 'Data & accessibility';

  @override
  String get settingsLowBandwidth => 'Low-bandwidth mode';

  @override
  String get settingsLowBandwidthHelp =>
      'Sends lite=1: trimmed hourly arrays, no radar tiles.';

  @override
  String get settingsLargeText => 'Larger text';

  @override
  String get settingsLargeTextHelp =>
      'Raises the minimum text size across the app.';

  @override
  String get settingsResetLearning => 'Reset what the app learned';

  @override
  String get settingsResetLearningHelp =>
      'Clears taps, dismissals, pins and hidden cards.';

  @override
  String get settingsResetLearningConfirm =>
      'This clears every card preference and the ranking history on the server. Continue?';

  @override
  String get settingsResetLearningDone =>
      'Learning reset. The feed is back to its defaults.';

  @override
  String get settingsReset => 'Reset';

  @override
  String get aboutDisclaimer =>
      'SIH 2026 · PS 26076 · a Team Mausam prototype. Not affiliated with, and not endorsed by, the India Meteorological Department.';

  @override
  String get change => 'Change';

  @override
  String get cancel => 'বাতিল';

  @override
  String get demoTitle => 'ডেমো নিয়ন্ত্রণ';

  @override
  String get demoSubtitle =>
      'Scenario, clock and persona overrides for this device only.';

  @override
  String get demoScenario => 'Scenario';

  @override
  String get demoClock => 'Demo clock (IST)';

  @override
  String get demoClockNow => 'Live';

  @override
  String get demoClockPick => 'Pick a time';

  @override
  String get demoPersona => 'View as persona';

  @override
  String get demoPersonaMine => 'My personas';

  @override
  String get demoSimulateOffline => 'Simulate offline';

  @override
  String get demoSimulateOfflineHelp =>
      'Shows the offline behaviour without touching the radio.';

  @override
  String get demoOpenConsole => 'Open admin console';

  @override
  String get demoReset => 'Reset demo';

  @override
  String get demoActiveHint =>
      'Demo overrides are active — the feed is not showing live data.';

  @override
  String get demoConsoleUnavailable =>
      'Could not open the console. Try this URL:';

  @override
  String demoLiveStatus(String status) {
    return 'Live alerts: $status';
  }

  @override
  String get wsConnected => 'connected';

  @override
  String get wsConnecting => 'connecting…';

  @override
  String get wsReconnecting => 'reconnecting…';

  @override
  String get wsUnauthorized => 'needs a new token';

  @override
  String get wsOffline => 'not connected';

  @override
  String get warningMovedToTop => 'একটি সতর্কতা আপনার ফিডের উপরে এসেছে।';

  @override
  String get view => 'দেখুন';

  @override
  String sampleDataBanner(String url) {
    return 'Sample data — the backend at $url is not reachable.';
  }

  @override
  String get liteBadge => 'Lite';

  @override
  String get liveUpdates => 'Live updates connected';

  @override
  String get engineFooterSemantics => 'Ranking details';

  @override
  String get aqiGood => 'Good';

  @override
  String get aqiSatisfactory => 'Satisfactory';

  @override
  String get aqiModerate => 'Moderate';

  @override
  String get aqiPoor => 'Poor';

  @override
  String get aqiVeryPoor => 'Very poor';

  @override
  String get aqiSevere => 'Severe';

  @override
  String get comfortUncomfortable => 'Uncomfortable';

  @override
  String get comfortFair => 'Fair';

  @override
  String get comfortComfortable => 'Comfortable';

  @override
  String get comfortIdeal => 'Ideal';

  @override
  String get soilVeryDry => 'Very dry';

  @override
  String get soilDry => 'Dry';

  @override
  String get soilAdequate => 'Adequate';

  @override
  String get soilWet => 'Wet';

  @override
  String get soilSaturated => 'Saturated';

  @override
  String get seaCalm => 'Calm';

  @override
  String get seaSmooth => 'Smooth';

  @override
  String get seaSlight => 'Slight';

  @override
  String get seaModerate => 'Moderate';

  @override
  String get seaRough => 'Rough';

  @override
  String get seaVeryRough => 'Very rough';

  @override
  String get seaHigh => 'High';

  @override
  String get qualityGreat => 'Great';

  @override
  String get qualityGood => 'Good';

  @override
  String get qualityFair => 'Fair';

  @override
  String get qualityPoor => 'Poor';

  @override
  String get levelLow => 'Low';

  @override
  String get levelMedium => 'Medium';

  @override
  String get levelHigh => 'High';

  @override
  String get levelSevere => 'Severe';

  @override
  String get levelNone => 'None';

  @override
  String get intensityLight => 'Light';

  @override
  String get intensityModerate => 'Moderate';

  @override
  String get intensityHeavy => 'Heavy';

  @override
  String get intensityVeryHeavy => 'Very heavy';

  @override
  String get hazardHeavyRain => 'Heavy rain';

  @override
  String get hazardVeryHeavyRain => 'Very heavy rain';

  @override
  String get hazardThunderstorm => 'Thunderstorm';

  @override
  String get hazardLightning => 'Lightning';

  @override
  String get hazardHeatwave => 'Heatwave';

  @override
  String get hazardColdWave => 'Cold wave';

  @override
  String get hazardFog => 'Fog';

  @override
  String get hazardDustStorm => 'Dust storm';

  @override
  String get hazardCyclone => 'Cyclone';

  @override
  String get hazardStrongWind => 'Strong wind';

  @override
  String get hazardSnow => 'Snow';

  @override
  String get hazardFlood => 'Flood';

  @override
  String get seasonWinter => 'Winter';

  @override
  String get seasonPreMonsoon => 'Pre-monsoon';

  @override
  String get seasonMonsoon => 'Monsoon';

  @override
  String get seasonPostMonsoon => 'Post-monsoon';

  @override
  String get windowMorningDrop => 'Morning drop';

  @override
  String get windowAfternoonPickup => 'Afternoon pickup';

  @override
  String get windowMorning => 'Morning';

  @override
  String get windowEvening => 'Evening';

  @override
  String get windowEarlyMorning => 'Early morning';

  @override
  String get windowLateMorning => 'Late morning';

  @override
  String get windowAfternoon => 'Afternoon';

  @override
  String get windowNight => 'Night';

  @override
  String get nothingToFlag => 'Nothing to flag right now.';

  @override
  String get nothingToAdd => 'Nothing to add.';

  @override
  String moreItems(int count) {
    return '+$count more';
  }

  @override
  String get placeFallback => 'Place';

  @override
  String nextDays(int days) {
    return 'next $days days';
  }

  @override
  String get nothingToPack => 'Nothing special to pack.';

  @override
  String get itemFallback => 'Item';

  @override
  String get savedPlaceFallback => 'Saved place';

  @override
  String riskWithLevel(String level) {
    return '$level risk';
  }

  @override
  String seasonWithName(String season) {
    return '$season season';
  }

  @override
  String zoneWithName(String zone) {
    return '$zone zone';
  }

  @override
  String get cropFallback => 'Crop';

  @override
  String get warningInForce => 'Warning in force';

  @override
  String peaksAround(String time) {
    return 'Peaks around $time';
  }

  @override
  String get airTemp => 'Air temp';

  @override
  String get heatIndex => 'Heat index';

  @override
  String frostRiskWithLevel(String level) {
    return '$level frost risk';
  }

  @override
  String expectedNight(String day) {
    return 'Expected on $day night';
  }

  @override
  String get minTemp => 'Min temp';

  @override
  String get cloud => 'Cloud';

  @override
  String fromTime(String time) {
    return 'From $time';
  }

  @override
  String untilTime(String time) {
    return 'until $time';
  }

  @override
  String peakAtTime(String time) {
    return '· peak $time';
  }

  @override
  String rainWithIntensity(String intensity) {
    return '$intensity rain';
  }

  @override
  String get peakChance => 'Peak chance';

  @override
  String get expected => 'Expected';

  @override
  String get alertFallback => 'Alert';

  @override
  String get noDailyRainfall => 'No daily rainfall data.';

  @override
  String get axisRainChance => 'Chance of rain, % per day';

  @override
  String focusDayWithLabel(String label) {
    return 'Focus day · $label';
  }

  @override
  String get onTheDay => 'On the day';

  @override
  String get axisRainfallMm => 'Rainfall, mm per day';

  @override
  String wettestDayWithDate(String day) {
    return 'Wettest day · $day';
  }

  @override
  String get next24h => 'Next 24 h';

  @override
  String get next72h => 'Next 72 h';

  @override
  String get next7d => 'Next 7 d';

  @override
  String get rainDays => 'Rain days';

  @override
  String countOfTotal(int count, int total) {
    return '$count of $total';
  }

  @override
  String get noDailyData => 'No daily data.';

  @override
  String get noHourlyData => 'No hourly data.';

  @override
  String get now => 'এখন';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String fieldsCount(int count) {
    return '$count fields';
  }

  @override
  String get noFurtherDetail => 'No further detail available.';

  @override
  String get noReading => 'No reading available.';

  @override
  String aqiScaleNote(String scale) {
    return '$scale AQI · 0–500';
  }

  @override
  String get comfortScaleNote => 'Comfort index · 0–100';

  @override
  String get soilScaleNote => 'Volumetric water content, surface 0–1 cm';

  @override
  String get dominant => 'Dominant';

  @override
  String get rootZone => 'Root zone';

  @override
  String get soilTemp => 'Soil temp';

  @override
  String get sinceRain => 'Since rain';

  @override
  String daysShort(int count) {
    return '$count d';
  }

  @override
  String get noNowcast => 'No nowcast issued for this location.';

  @override
  String validTill(String time) {
    return 'Valid till $time';
  }

  @override
  String issuedAt(String time) {
    return 'Issued $time';
  }

  @override
  String get noSavedPlaces => 'No saved places yet.';

  @override
  String localTimeAt(String time) {
    return 'local time $time';
  }

  @override
  String get highLow => 'High / low';

  @override
  String get activeWarning => 'Active warning';

  @override
  String get rainWithin2h => 'Rain within 2 h';

  @override
  String rainWithin2hValue(String pct) {
    return 'Rain within 2 h · $pct';
  }

  @override
  String radarFrameAt(String time) {
    return 'RainViewer · frame $time';
  }

  @override
  String frameOf(int index, int total) {
    return 'Frame $index of $total';
  }

  @override
  String get frames => 'Frames';

  @override
  String get noMarineData => 'No marine data for this location.';

  @override
  String get period => 'Period';

  @override
  String get seaTemp => 'Sea temp';

  @override
  String get swell => 'Swell';

  @override
  String get current => 'Current';

  @override
  String get fromDirection => 'From';

  @override
  String get safeSwim => 'Safe for swimming';

  @override
  String get notSafeSwim => 'Not safe for swimming';

  @override
  String waveHeightNextHours(int hours) {
    return 'Wave height, next $hours h';
  }

  @override
  String get surf => 'Surf';

  @override
  String get highestWaves => 'Highest waves';

  @override
  String get around => 'Around';

  @override
  String get douglasScale => 'Douglas sea scale';

  @override
  String get noTideTable => 'No tide table for this location.';

  @override
  String metresNow(String value) {
    return '$value m now';
  }

  @override
  String get tideHigh => 'High';

  @override
  String get tideLow => 'Low';

  @override
  String nextTide(String type, String time, String height) {
    return 'Next: $type tide at $time ($height m)';
  }

  @override
  String get turningPoints => 'Turning points';

  @override
  String get noWindow => 'No window in the forecast period.';

  @override
  String overallWithVerdict(String verdict) {
    return 'Overall: $verdict';
  }

  @override
  String get temp => 'Temp';

  @override
  String get delay => 'Delay';

  @override
  String minutesShort(int count) {
    return '+$count min';
  }

  @override
  String get visibility => 'Visibility';

  @override
  String impactWithLevel(String level) {
    return '$level impact';
  }

  @override
  String get hourlyScore => 'Hourly score';

  @override
  String get hourlyScoreHelp =>
      '100 = perfect conditions; the window bands above are the best runs of hours.';

  @override
  String get traffic => 'Traffic';

  @override
  String get congestion => 'Congestion';

  @override
  String get schoolDay => 'School day';

  @override
  String get notSchoolDay => 'Not a school day';

  @override
  String get rainPerHourMm => 'Rain per hour (mm)';

  @override
  String get rainChancePct => 'Chance of rain (%)';

  @override
  String get expectedRainfallMm => 'Expected rainfall (mm)';

  @override
  String get hourByHourFocus => 'Hour by hour on the focus day';

  @override
  String get nextHours => 'Next hours';

  @override
  String get next7Days => 'Next 7 days';

  @override
  String get scale => 'Scale';

  @override
  String get bestHoursToday => 'Best hours today';

  @override
  String get cachedSuffix => 'cached';

  @override
  String severityWarningWord(String severity, String title) {
    return '$severity warning. $title';
  }

  @override
  String get moreLanguagesNote =>
      'অনুবাদ সম্পূর্ণ হলে আরও ভাষা যুক্ত হবে; অনূদিত না হলে ইংরেজিতে দেখাবে।';

  @override
  String get yes => 'yes';

  @override
  String get no => 'no';

  @override
  String get verdictCaution => 'Caution';

  @override
  String get verdictAvoid => 'Avoid';

  @override
  String get severityYellow => 'Yellow';

  @override
  String get severityOrange => 'Orange';

  @override
  String get severityRed => 'Red';

  @override
  String get levelModerate => 'Moderate';

  @override
  String get quickRadar => 'Radar';

  @override
  String get quickPlaces => 'Places';

  @override
  String get quickDemo => 'Demo';
}
