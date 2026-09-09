// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class LHi extends L {
  LHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'मौसम पर्सनलाइज़्ड';

  @override
  String get onboardingLanguageTitle => 'अपनी भाषा चुनें';

  @override
  String get onboardingLanguageSubtitle =>
      'आप इसे बाद में सेटिंग्स में बदल सकते हैं।';

  @override
  String get onboardingPersonaTitle => 'हम आपके लिए क्या देखें?';

  @override
  String get onboardingPersonaSubtitle =>
      '1 से 3 चुनें। पहला चुना गया विकल्प प्राथमिक होगा।';

  @override
  String get onboardingLocationTitle => 'आप कहाँ हैं?';

  @override
  String get onboardingLocationSubtitle =>
      'हम इससे आपके क्षेत्र का मौसम लाते हैं।';

  @override
  String get continueLabel => 'आगे बढ़ें';

  @override
  String get back => 'पीछे';

  @override
  String get finish => 'पूरा करें';

  @override
  String get skip => 'छोड़ें';

  @override
  String get personaLimitReached => 'आप अधिकतम 3 चुन सकते हैं।';

  @override
  String get personaPrimary => 'प्राथमिक';

  @override
  String selectedCount(int count) {
    return '$count चुने गए';
  }

  @override
  String get useMyLocation => 'मेरा स्थान इस्तेमाल करें';

  @override
  String get searchCity => 'शहर खोजें';

  @override
  String get popularCities => 'प्रमुख शहर';

  @override
  String get locationPermissionDenied =>
      'स्थान की अनुमति नहीं मिली। कृपया अपना शहर खोजें।';

  @override
  String get locationServicesOff =>
      'स्थान सेवाएँ बंद हैं। उन्हें चालू करें या शहर खोजें।';

  @override
  String get locatingYou => 'आपको ढूँढ़ रहे हैं…';

  @override
  String get homeTitle => 'होम';

  @override
  String get moreForYou => 'आपके लिए और';

  @override
  String get showMore => 'और दिखाएँ';

  @override
  String get showLess => 'कम दिखाएँ';

  @override
  String get details => 'विवरण';

  @override
  String get share => 'साझा करें';

  @override
  String get pinToTop => 'ऊपर पिन करें';

  @override
  String get unpin => 'पिन हटाएँ';

  @override
  String get hideCard => 'यह कार्ड छिपाएँ';

  @override
  String get restoreHidden => 'छिपाए गए कार्ड वापस लाएँ';

  @override
  String get whyThisCard => 'यह कार्ड क्यों दिख रहा है?';

  @override
  String get drivenBy => 'किसके कारण';

  @override
  String get estimated => 'अनुमानित';

  @override
  String get pinned => 'पिन किया गया';

  @override
  String get allClear => 'सब ठीक है';

  @override
  String get offlineBanner => 'आप ऑफ़लाइन हैं — सहेजा गया डेटा दिखा रहे हैं।';

  @override
  String get staleBanner => 'ताज़ा नहीं कर सके। सहेजा गया डेटा दिखा रहे हैं।';

  @override
  String get retry => 'फिर कोशिश करें';

  @override
  String get updatedJustNow => 'अभी अपडेट हुआ';

  @override
  String updatedMinutesAgo(int minutes) {
    return '$minutes मिनट पहले अपडेट हुआ';
  }

  @override
  String updatedHoursAgo(int hours) {
    return '$hours घंटे पहले अपडेट हुआ';
  }

  @override
  String get sampleDataBadge => 'नमूना डेटा';

  @override
  String viewingAs(String persona) {
    return '$persona के रूप में देख रहे हैं';
  }

  @override
  String get saveRole => 'सहेजें';

  @override
  String get clearRoleView => 'हटाएँ';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsBackendUrl => 'बैकएंड URL';

  @override
  String get settingsBackendUrlHint => 'http://localhost:8000';

  @override
  String get settingsBackendUrlHelp =>
      'उस मशीन का पता दें जिस पर FastAPI बैकएंड चल रहा है। फ़ोन पर PC का LAN IP डालें।';

  @override
  String get settingsPersonas => 'आपकी रुचियाँ';

  @override
  String get settingsAbout => 'ऐप के बारे में';

  @override
  String get save => 'सहेजें';

  @override
  String get saved => 'सहेजा गया';

  @override
  String get invalidUrl => 'मान्य http(s) URL डालें।';

  @override
  String get errorGeneric => 'कुछ गड़बड़ हो गई।';

  @override
  String get errorNoData => 'अभी मौसम डेटा उपलब्ध नहीं है।';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get personaHealth => 'स्वास्थ्य';

  @override
  String get personaHealthTag => 'वायु गुणवत्ता, पराग और स्वास्थ्य सलाह';

  @override
  String get personaFitness => 'फ़िटनेस';

  @override
  String get personaFitnessTag => 'दौड़ने और व्यायाम के सबसे अच्छे समय';

  @override
  String get personaBeach => 'समुद्र तट';

  @override
  String get personaBeachTag => 'लहरें, ज्वार-भाटा और समुद्र का तापमान';

  @override
  String get personaTraveler => 'यात्री';

  @override
  String get personaTravelerTag => 'सहेजे गए स्थान, पैकिंग और यात्रा जोखिम';

  @override
  String get personaParent => 'अभिभावक';

  @override
  String get personaParentTag => 'स्कूल आना-जाना, बारिश और चेतावनियाँ';

  @override
  String get personaAgriculture => 'कृषि';

  @override
  String get personaAgricultureTag => 'मिट्टी, वर्षा पूर्वानुमान और पाला';

  @override
  String get personaCommuter => 'दैनिक यात्री';

  @override
  String get personaCommuterTag => 'ट्रैफ़िक, दृश्यता और तूफ़ान';

  @override
  String get personaEventPlanner => 'आयोजन योजनाकार';

  @override
  String get personaEventPlannerTag =>
      'लंबी अवधि का पूर्वानुमान और बारिश की संभावना';

  @override
  String get severityInfo => 'सूचना';

  @override
  String get severityAdvisory => 'परामर्श';

  @override
  String get severityWatch => 'निगरानी';

  @override
  String get severityWarning => 'चेतावनी';

  @override
  String get severitySevere => 'गंभीर';

  @override
  String get feelsLike => 'महसूस होता है';

  @override
  String get humidity => 'आर्द्रता';

  @override
  String get wind => 'हवा';

  @override
  String get uv => 'यूवी';

  @override
  String get aqi => 'एक्यूआई';

  @override
  String get sunrise => 'सूर्योदय';

  @override
  String get sunset => 'सूर्यास्त';

  @override
  String get high => 'अधिकतम';

  @override
  String get low => 'न्यूनतम';

  @override
  String get rainChance => 'बारिश';

  @override
  String get next24Hours => 'अगले 24 घंटे';

  @override
  String get sevenDays => '7 दिन';

  @override
  String validUntil(String time) {
    return '$time तक';
  }

  @override
  String get pinnedToTop => 'सबसे ऊपर पिन किया गया';

  @override
  String get unpinned => 'पिन हटाया गया';

  @override
  String get cardMenu => 'कार्ड विकल्प';

  @override
  String learnedFromYou(int taps, int dismisses) {
    return 'आपने इसे $taps बार खोला और $dismisses बार नीचे किया।';
  }

  @override
  String rankScore(String score, String urgency) {
    return 'रैंक स्कोर $score · अर्जेंसी $urgency';
  }

  @override
  String get placesTitle => 'सहेजे गए स्थान';

  @override
  String placesSubtitle(int max) {
    return 'आपके $max पसंदीदा स्थानों का मौसम — यही यात्रा कार्ड भी चलाते हैं।';
  }

  @override
  String get placesEmpty => 'अभी कोई स्थान सहेजा नहीं गया। नीचे खोजकर जोड़ें।';

  @override
  String get placesAdd => 'स्थान जोड़ें';

  @override
  String placesFull(int max) {
    return 'आप $max स्थानों की सीमा तक पहुँच गए हैं।';
  }

  @override
  String get placesAddFailed =>
      'यह स्थान सहेजा नहीं जा सका। बैकएंड कनेक्शन जाँचें।';

  @override
  String get placesRemoveFailed => 'यह स्थान हटाया नहीं जा सका।';

  @override
  String get placeKindHome => 'घर';

  @override
  String get placeKindWork => 'कार्यस्थल';

  @override
  String get placeKindSchool => 'स्कूल';

  @override
  String get placeKindTravel => 'यात्रा';

  @override
  String get placeKindOther => 'अन्य';

  @override
  String get coastal => 'तटीय';

  @override
  String get remove => 'हटाएँ';

  @override
  String get mapTitle => 'रडार और चेतावनियाँ';

  @override
  String get mapToggleRadar => 'रडार परत बदलें';

  @override
  String get mapAttribution =>
      'बेस मैप © OpenStreetMap योगदानकर्ता · रडार फ़्रेम RainViewer से।';

  @override
  String get radarNoFrames => 'अभी रडार फ़्रेम उपलब्ध नहीं हैं।';

  @override
  String get radarPastFrame => 'देखा गया';

  @override
  String get radarForecastFrame => 'पूर्वानुमान';

  @override
  String get lowBandwidthRadarOff => 'कम-बैंडविड्थ मोड: रडार टाइल्स बंद हैं।';

  @override
  String get play => 'चलाएँ';

  @override
  String get pause => 'रोकें';

  @override
  String get openMap => 'मानचित्र खोलें';

  @override
  String get settingsUnits => 'इकाइयाँ';

  @override
  String get unitsMetric => 'मीट्रिक (°से, किमी/घं)';

  @override
  String get unitsImperial => 'इम्पीरियल (°फ़ै, मील/घं)';

  @override
  String get settingsHomeLocation => 'घर का स्थान';

  @override
  String get settingsNoLocation => 'कोई स्थान तय नहीं';

  @override
  String get settingsPlacesSubtitle =>
      'घर के अलावा जिन स्थानों को आप देखते हैं';

  @override
  String get settingsSchoolWindows => 'स्कूल आने-जाने का समय';

  @override
  String get settingsCommuteWindows => 'आवागमन का समय';

  @override
  String get settingsAccessibility => 'डेटा और सुगम्यता';

  @override
  String get settingsLowBandwidth => 'कम-बैंडविड्थ मोड';

  @override
  String get settingsLowBandwidthHelp =>
      'lite=1 भेजता है: छोटी घंटेवार सूची, रडार टाइल्स नहीं।';

  @override
  String get settingsLargeText => 'बड़ा टेक्स्ट';

  @override
  String get settingsLargeTextHelp =>
      'पूरे ऐप में न्यूनतम टेक्स्ट आकार बढ़ाता है।';

  @override
  String get settingsResetLearning => 'ऐप ने जो सीखा है उसे रीसेट करें';

  @override
  String get settingsResetLearningHelp =>
      'टैप, हटाए गए, पिन और छिपे कार्ड साफ़ करता है।';

  @override
  String get settingsResetLearningConfirm =>
      'इससे सर्वर पर हर कार्ड वरीयता और रैंकिंग इतिहास मिट जाएगा। जारी रखें?';

  @override
  String get settingsResetLearningDone =>
      'सीख रीसेट हुई। फ़ीड फिर से डिफ़ॉल्ट पर है।';

  @override
  String get settingsReset => 'रीसेट';

  @override
  String get aboutDisclaimer =>
      'SIH 2026 · PS 26076 · टीम मौसम का प्रोटोटाइप। भारत मौसम विज्ञान विभाग से संबद्ध या अनुमोदित नहीं।';

  @override
  String get change => 'बदलें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get demoTitle => 'डेमो नियंत्रण';

  @override
  String get demoSubtitle =>
      'केवल इस डिवाइस के लिए परिदृश्य, घड़ी और पर्सोना बदलाव।';

  @override
  String get demoScenario => 'परिदृश्य';

  @override
  String get demoClock => 'डेमो घड़ी (IST)';

  @override
  String get demoClockNow => 'लाइव';

  @override
  String get demoClockPick => 'समय चुनें';

  @override
  String get demoPersona => 'पर्सोना के रूप में देखें';

  @override
  String get demoPersonaMine => 'मेरे पर्सोना';

  @override
  String get demoSimulateOffline => 'ऑफ़लाइन जैसा दिखाएँ';

  @override
  String get demoSimulateOfflineHelp =>
      'नेटवर्क बंद किए बिना ऑफ़लाइन व्यवहार दिखाता है।';

  @override
  String get demoOpenConsole => 'एडमिन कंसोल खोलें';

  @override
  String get demoReset => 'डेमो रीसेट करें';

  @override
  String get demoActiveHint =>
      'डेमो बदलाव सक्रिय हैं — फ़ीड लाइव डेटा नहीं दिखा रही।';

  @override
  String get demoConsoleUnavailable => 'कंसोल नहीं खुल सका। यह URL आज़माएँ:';

  @override
  String demoLiveStatus(String status) {
    return 'लाइव अलर्ट: $status';
  }

  @override
  String get wsConnected => 'जुड़ा हुआ';

  @override
  String get wsConnecting => 'जुड़ रहा है…';

  @override
  String get wsReconnecting => 'फिर जुड़ रहा है…';

  @override
  String get wsUnauthorized => 'नया टोकन चाहिए';

  @override
  String get wsOffline => 'जुड़ा नहीं';

  @override
  String get warningMovedToTop => 'एक चेतावनी आपकी फ़ीड में सबसे ऊपर आ गई।';

  @override
  String get view => 'देखें';

  @override
  String sampleDataBanner(String url) {
    return 'नमूना डेटा — $url पर बैकएंड उपलब्ध नहीं है।';
  }

  @override
  String get liteBadge => 'लाइट';

  @override
  String get liveUpdates => 'लाइव अपडेट जुड़े हैं';

  @override
  String get engineFooterSemantics => 'रैंकिंग विवरण';

  @override
  String get aqiGood => 'अच्छा';

  @override
  String get aqiSatisfactory => 'संतोषजनक';

  @override
  String get aqiModerate => 'मध्यम';

  @override
  String get aqiPoor => 'खराब';

  @override
  String get aqiVeryPoor => 'बहुत खराब';

  @override
  String get aqiSevere => 'गंभीर';

  @override
  String get comfortUncomfortable => 'असुविधाजनक';

  @override
  String get comfortFair => 'ठीक-ठाक';

  @override
  String get comfortComfortable => 'आरामदेह';

  @override
  String get comfortIdeal => 'आदर्श';

  @override
  String get soilVeryDry => 'बहुत सूखी';

  @override
  String get soilDry => 'सूखी';

  @override
  String get soilAdequate => 'पर्याप्त';

  @override
  String get soilWet => 'गीली';

  @override
  String get soilSaturated => 'संतृप्त';

  @override
  String get seaCalm => 'शांत';

  @override
  String get seaSmooth => 'सपाट';

  @override
  String get seaSlight => 'हल्की लहरें';

  @override
  String get seaModerate => 'मध्यम लहरें';

  @override
  String get seaRough => 'अशांत';

  @override
  String get seaVeryRough => 'बहुत अशांत';

  @override
  String get seaHigh => 'ऊँची लहरें';

  @override
  String get qualityGreat => 'बहुत बढ़िया';

  @override
  String get qualityGood => 'अच्छा';

  @override
  String get qualityFair => 'ठीक';

  @override
  String get qualityPoor => 'खराब';

  @override
  String get levelLow => 'कम';

  @override
  String get levelMedium => 'मध्यम';

  @override
  String get levelHigh => 'अधिक';

  @override
  String get levelSevere => 'गंभीर';

  @override
  String get levelNone => 'कोई नहीं';

  @override
  String get intensityLight => 'हल्की';

  @override
  String get intensityModerate => 'मध्यम';

  @override
  String get intensityHeavy => 'भारी';

  @override
  String get intensityVeryHeavy => 'बहुत भारी';

  @override
  String get hazardHeavyRain => 'भारी वर्षा';

  @override
  String get hazardVeryHeavyRain => 'बहुत भारी वर्षा';

  @override
  String get hazardThunderstorm => 'आँधी-तूफ़ान';

  @override
  String get hazardLightning => 'बिजली गिरना';

  @override
  String get hazardHeatwave => 'लू';

  @override
  String get hazardColdWave => 'शीत लहर';

  @override
  String get hazardFog => 'कोहरा';

  @override
  String get hazardDustStorm => 'धूल भरी आँधी';

  @override
  String get hazardCyclone => 'चक्रवात';

  @override
  String get hazardStrongWind => 'तेज़ हवा';

  @override
  String get hazardSnow => 'बर्फ़बारी';

  @override
  String get hazardFlood => 'बाढ़';

  @override
  String get seasonWinter => 'सर्दी';

  @override
  String get seasonPreMonsoon => 'मानसून-पूर्व';

  @override
  String get seasonMonsoon => 'मानसून';

  @override
  String get seasonPostMonsoon => 'मानसून-पश्चात';

  @override
  String get windowMorningDrop => 'सुबह छोड़ना';

  @override
  String get windowAfternoonPickup => 'दोपहर लेना';

  @override
  String get windowMorning => 'सुबह';

  @override
  String get windowEvening => 'शाम';

  @override
  String get windowEarlyMorning => 'तड़के';

  @override
  String get windowLateMorning => 'देर सुबह';

  @override
  String get windowAfternoon => 'दोपहर';

  @override
  String get windowNight => 'रात';

  @override
  String get nothingToFlag => 'अभी बताने लायक कुछ नहीं।';

  @override
  String get nothingToAdd => 'जोड़ने के लिए कुछ नहीं।';

  @override
  String moreItems(int count) {
    return '+$count और';
  }

  @override
  String get placeFallback => 'स्थान';

  @override
  String nextDays(int days) {
    return 'अगले $days दिन';
  }

  @override
  String get nothingToPack => 'कुछ ख़ास पैक करने की ज़रूरत नहीं।';

  @override
  String get itemFallback => 'वस्तु';

  @override
  String get savedPlaceFallback => 'सहेजा गया स्थान';

  @override
  String riskWithLevel(String level) {
    return '$level जोखिम';
  }

  @override
  String seasonWithName(String season) {
    return '$season मौसम';
  }

  @override
  String zoneWithName(String zone) {
    return '$zone क्षेत्र';
  }

  @override
  String get cropFallback => 'फ़सल';

  @override
  String get warningInForce => 'चेतावनी लागू है';

  @override
  String peaksAround(String time) {
    return 'लगभग $time पर चरम';
  }

  @override
  String get airTemp => 'हवा का तापमान';

  @override
  String get heatIndex => 'ताप सूचकांक';

  @override
  String frostRiskWithLevel(String level) {
    return '$level पाला जोखिम';
  }

  @override
  String expectedNight(String day) {
    return '$day की रात अपेक्षित';
  }

  @override
  String get minTemp => 'न्यूनतम तापमान';

  @override
  String get cloud => 'बादल';

  @override
  String fromTime(String time) {
    return '$time से';
  }

  @override
  String untilTime(String time) {
    return '$time तक';
  }

  @override
  String peakAtTime(String time) {
    return '· चरम $time';
  }

  @override
  String rainWithIntensity(String intensity) {
    return '$intensity वर्षा';
  }

  @override
  String get peakChance => 'अधिकतम संभावना';

  @override
  String get expected => 'अपेक्षित';

  @override
  String get alertFallback => 'चेतावनी';

  @override
  String get noDailyRainfall => 'दैनिक वर्षा डेटा नहीं है।';

  @override
  String get axisRainChance => 'वर्षा की संभावना, % प्रतिदिन';

  @override
  String focusDayWithLabel(String label) {
    return 'मुख्य दिन · $label';
  }

  @override
  String get onTheDay => 'उस दिन';

  @override
  String get axisRainfallMm => 'वर्षा, मिमी प्रतिदिन';

  @override
  String wettestDayWithDate(String day) {
    return 'सबसे अधिक वर्षा · $day';
  }

  @override
  String get next24h => 'अगले 24 घं';

  @override
  String get next72h => 'अगले 72 घं';

  @override
  String get next7d => 'अगले 7 दिन';

  @override
  String get rainDays => 'वर्षा वाले दिन';

  @override
  String countOfTotal(int count, int total) {
    return '$total में से $count';
  }

  @override
  String get noDailyData => 'दैनिक डेटा नहीं है।';

  @override
  String get noHourlyData => 'घंटेवार डेटा नहीं है।';

  @override
  String get now => 'अभी';

  @override
  String itemsCount(int count) {
    return '$count आइटम';
  }

  @override
  String fieldsCount(int count) {
    return '$count फ़ील्ड';
  }

  @override
  String get noFurtherDetail => 'इससे अधिक विवरण उपलब्ध नहीं है।';

  @override
  String get noReading => 'कोई रीडिंग उपलब्ध नहीं है।';

  @override
  String aqiScaleNote(String scale) {
    return '$scale AQI · 0–500';
  }

  @override
  String get comfortScaleNote => 'आराम सूचकांक · 0–100';

  @override
  String get soilScaleNote => 'आयतनिक जल मात्रा, सतह 0–1 सेमी';

  @override
  String get dominant => 'प्रमुख';

  @override
  String get rootZone => 'जड़ क्षेत्र';

  @override
  String get soilTemp => 'मिट्टी का तापमान';

  @override
  String get sinceRain => 'वर्षा के बाद';

  @override
  String daysShort(int count) {
    return '$count दिन';
  }

  @override
  String get noNowcast => 'इस स्थान के लिए कोई नाउकास्ट जारी नहीं हुआ।';

  @override
  String validTill(String time) {
    return '$time तक मान्य';
  }

  @override
  String issuedAt(String time) {
    return '$time पर जारी';
  }

  @override
  String get noSavedPlaces => 'अभी कोई स्थान सहेजा नहीं गया।';

  @override
  String localTimeAt(String time) {
    return 'स्थानीय समय $time';
  }

  @override
  String get highLow => 'अधिकतम / न्यूनतम';

  @override
  String get activeWarning => 'सक्रिय चेतावनी';

  @override
  String get rainWithin2h => '2 घंटे में वर्षा';

  @override
  String rainWithin2hValue(String pct) {
    return '2 घंटे में वर्षा · $pct';
  }

  @override
  String radarFrameAt(String time) {
    return 'RainViewer · फ़्रेम $time';
  }

  @override
  String frameOf(int index, int total) {
    return '$total में से फ़्रेम $index';
  }

  @override
  String get frames => 'फ़्रेम';

  @override
  String get noMarineData => 'इस स्थान के लिए समुद्री डेटा नहीं है।';

  @override
  String get period => 'अवधि';

  @override
  String get seaTemp => 'समुद्र का तापमान';

  @override
  String get swell => 'स्वेल';

  @override
  String get current => 'धारा';

  @override
  String get fromDirection => 'दिशा';

  @override
  String get safeSwim => 'तैरने के लिए सुरक्षित';

  @override
  String get notSafeSwim => 'तैरने के लिए सुरक्षित नहीं';

  @override
  String waveHeightNextHours(int hours) {
    return 'लहर ऊँचाई, अगले $hours घं';
  }

  @override
  String get surf => 'सर्फ़';

  @override
  String get highestWaves => 'सबसे ऊँची लहरें';

  @override
  String get around => 'लगभग';

  @override
  String get douglasScale => 'डगलस समुद्र पैमाना';

  @override
  String get noTideTable => 'इस स्थान के लिए ज्वार तालिका नहीं है।';

  @override
  String metresNow(String value) {
    return 'अभी $value मी';
  }

  @override
  String get tideHigh => 'उच्च ज्वार';

  @override
  String get tideLow => 'निम्न ज्वार';

  @override
  String nextTide(String type, String time, String height) {
    return 'अगला: $time पर $type ज्वार ($height मी)';
  }

  @override
  String get turningPoints => 'परिवर्तन बिंदु';

  @override
  String get noWindow => 'पूर्वानुमान अवधि में कोई उपयुक्त समय नहीं।';

  @override
  String get tomorrow => 'कल';

  @override
  String overallWithVerdict(String verdict) {
    return 'कुल मिलाकर: $verdict';
  }

  @override
  String get temp => 'तापमान';

  @override
  String get delay => 'देरी';

  @override
  String minutesShort(int count) {
    return '+$count मिनट';
  }

  @override
  String get visibility => 'दृश्यता';

  @override
  String impactWithLevel(String level) {
    return '$level असर';
  }

  @override
  String get hourlyScore => 'घंटेवार स्कोर';

  @override
  String get hourlyScoreHelp =>
      '100 = आदर्श स्थिति; ऊपर दिए बैंड सबसे अच्छे घंटों के समूह हैं।';

  @override
  String get traffic => 'यातायात';

  @override
  String get congestion => 'भीड़भाड़';

  @override
  String get schoolDay => 'स्कूल का दिन';

  @override
  String get notSchoolDay => 'स्कूल का दिन नहीं';

  @override
  String get rainPerHourMm => 'प्रति घंटा वर्षा (मिमी)';

  @override
  String get rainChancePct => 'वर्षा की संभावना (%)';

  @override
  String get expectedRainfallMm => 'अपेक्षित वर्षा (मिमी)';

  @override
  String get hourByHourFocus => 'मुख्य दिन का घंटेवार विवरण';

  @override
  String get nextHours => 'अगले घंटे';

  @override
  String get next7Days => 'अगले 7 दिन';

  @override
  String get scale => 'पैमाना';

  @override
  String get bestHoursToday => 'आज के सर्वोत्तम घंटे';

  @override
  String get cachedSuffix => 'कैश से';

  @override
  String severityWarningWord(String severity, String title) {
    return '$severity चेतावनी। $title';
  }

  @override
  String get moreLanguagesNote =>
      'और भाषाएँ अनुवाद पूरा होते ही जुड़ेंगी; जो अनुवादित नहीं है वह अंग्रेज़ी में दिखेगा।';

  @override
  String get yes => 'हाँ';

  @override
  String get no => 'नहीं';

  @override
  String get verdictCaution => 'सावधानी';

  @override
  String get verdictAvoid => 'टालें';

  @override
  String get severityYellow => 'पीली';

  @override
  String get severityOrange => 'नारंगी';

  @override
  String get severityRed => 'लाल';

  @override
  String get levelModerate => 'मध्यम';

  @override
  String get quickRadar => 'रडार';

  @override
  String get quickPlaces => 'स्थान';

  @override
  String get quickDemo => 'डेमो';
}
