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
}
