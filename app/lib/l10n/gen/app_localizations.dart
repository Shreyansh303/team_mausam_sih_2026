import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('ta'),
  ];

  /// App display name (Team Mausam prototype, not IMD)
  ///
  /// In en, this message translates to:
  /// **'Mausam Personalized'**
  String get appTitle;

  /// No description provided for @onboardingLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingLanguageTitle;

  /// No description provided for @onboardingLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get onboardingLanguageSubtitle;

  /// No description provided for @onboardingPersonaTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we watch for you?'**
  String get onboardingPersonaTitle;

  /// No description provided for @onboardingPersonaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick 1 to 3. The first one you pick is your primary.'**
  String get onboardingPersonaSubtitle;

  /// No description provided for @onboardingLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use this to fetch weather for your area.'**
  String get onboardingLocationSubtitle;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @personaLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You can pick up to 3.'**
  String get personaLimitReached;

  /// No description provided for @personaPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get personaPrimary;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get searchCity;

  /// No description provided for @popularCities.
  ///
  /// In en, this message translates to:
  /// **'Popular cities'**
  String get popularCities;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Search for your city instead.'**
  String get locationPermissionDenied;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Turn them on or search for your city.'**
  String get locationServicesOff;

  /// No description provided for @locatingYou.
  ///
  /// In en, this message translates to:
  /// **'Finding you…'**
  String get locatingYou;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @moreForYou.
  ///
  /// In en, this message translates to:
  /// **'More for you'**
  String get moreForYou;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @pinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinToTop;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @hideCard.
  ///
  /// In en, this message translates to:
  /// **'Hide this card'**
  String get hideCard;

  /// No description provided for @restoreHidden.
  ///
  /// In en, this message translates to:
  /// **'Restore hidden cards'**
  String get restoreHidden;

  /// No description provided for @whyThisCard.
  ///
  /// In en, this message translates to:
  /// **'Why am I seeing this?'**
  String get whyThisCard;

  /// No description provided for @drivenBy.
  ///
  /// In en, this message translates to:
  /// **'Driven by'**
  String get drivenBy;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimated;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get allClear;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline — showing saved data.'**
  String get offlineBanner;

  /// No description provided for @staleBanner.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing saved data.'**
  String get staleBanner;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @updatedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get updatedJustNow;

  /// No description provided for @updatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes} min ago'**
  String updatedMinutesAgo(int minutes);

  /// No description provided for @updatedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {hours} h ago'**
  String updatedHoursAgo(int hours);

  /// No description provided for @sampleDataBadge.
  ///
  /// In en, this message translates to:
  /// **'Sample data'**
  String get sampleDataBadge;

  /// No description provided for @viewingAs.
  ///
  /// In en, this message translates to:
  /// **'Viewing as {persona}'**
  String viewingAs(String persona);

  /// No description provided for @saveRole.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveRole;

  /// No description provided for @clearRoleView.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearRoleView;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsBackendUrl.
  ///
  /// In en, this message translates to:
  /// **'Backend URL'**
  String get settingsBackendUrl;

  /// No description provided for @settingsBackendUrlHint.
  ///
  /// In en, this message translates to:
  /// **'http://localhost:8000'**
  String get settingsBackendUrlHint;

  /// No description provided for @settingsBackendUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Point this at the machine running the FastAPI backend. On a phone use the PC\'s LAN IP.'**
  String get settingsBackendUrlHelp;

  /// No description provided for @settingsPersonas.
  ///
  /// In en, this message translates to:
  /// **'Your interests'**
  String get settingsPersonas;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) URL.'**
  String get invalidUrl;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// No description provided for @errorNoData.
  ///
  /// In en, this message translates to:
  /// **'No weather data available right now.'**
  String get errorNoData;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @personaHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get personaHealth;

  /// No description provided for @personaHealthTag.
  ///
  /// In en, this message translates to:
  /// **'Air quality, pollen and health advice'**
  String get personaHealthTag;

  /// No description provided for @personaFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get personaFitness;

  /// No description provided for @personaFitnessTag.
  ///
  /// In en, this message translates to:
  /// **'Best windows to run, ride or train'**
  String get personaFitnessTag;

  /// No description provided for @personaBeach.
  ///
  /// In en, this message translates to:
  /// **'Beach & sea'**
  String get personaBeach;

  /// No description provided for @personaBeachTag.
  ///
  /// In en, this message translates to:
  /// **'Waves, tides and sea temperature'**
  String get personaBeachTag;

  /// No description provided for @personaTraveler.
  ///
  /// In en, this message translates to:
  /// **'Traveller'**
  String get personaTraveler;

  /// No description provided for @personaTravelerTag.
  ///
  /// In en, this message translates to:
  /// **'Saved places, packing and travel risk'**
  String get personaTravelerTag;

  /// No description provided for @personaParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get personaParent;

  /// No description provided for @personaParentTag.
  ///
  /// In en, this message translates to:
  /// **'School run, rain alerts and warnings'**
  String get personaParentTag;

  /// No description provided for @personaAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Farming'**
  String get personaAgriculture;

  /// No description provided for @personaAgricultureTag.
  ///
  /// In en, this message translates to:
  /// **'Soil, rainfall outlook and frost'**
  String get personaAgricultureTag;

  /// No description provided for @personaCommuter.
  ///
  /// In en, this message translates to:
  /// **'Commuter'**
  String get personaCommuter;

  /// No description provided for @personaCommuterTag.
  ///
  /// In en, this message translates to:
  /// **'Traffic, visibility and storms'**
  String get personaCommuterTag;

  /// No description provided for @personaEventPlanner.
  ///
  /// In en, this message translates to:
  /// **'Event planner'**
  String get personaEventPlanner;

  /// No description provided for @personaEventPlannerTag.
  ///
  /// In en, this message translates to:
  /// **'Long-range outlook and rain chance'**
  String get personaEventPlannerTag;

  /// No description provided for @severityInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get severityInfo;

  /// No description provided for @severityAdvisory.
  ///
  /// In en, this message translates to:
  /// **'Advisory'**
  String get severityAdvisory;

  /// No description provided for @severityWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get severityWatch;

  /// No description provided for @severityWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get severityWarning;

  /// No description provided for @severitySevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severitySevere;

  /// No description provided for @feelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like'**
  String get feelsLike;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @uv.
  ///
  /// In en, this message translates to:
  /// **'UV'**
  String get uv;

  /// No description provided for @aqi.
  ///
  /// In en, this message translates to:
  /// **'AQI'**
  String get aqi;

  /// No description provided for @sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunrise;

  /// No description provided for @sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunset;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @rainChance.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get rainChance;

  /// No description provided for @next24Hours.
  ///
  /// In en, this message translates to:
  /// **'Next 24 hours'**
  String get next24Hours;

  /// No description provided for @sevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get sevenDays;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {time}'**
  String validUntil(String time);

  /// No description provided for @pinnedToTop.
  ///
  /// In en, this message translates to:
  /// **'Pinned to the top'**
  String get pinnedToTop;

  /// No description provided for @unpinned.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get unpinned;

  /// No description provided for @cardMenu.
  ///
  /// In en, this message translates to:
  /// **'Card options'**
  String get cardMenu;

  /// No description provided for @learnedFromYou.
  ///
  /// In en, this message translates to:
  /// **'You opened this {taps} times and pushed it down {dismisses} times.'**
  String learnedFromYou(int taps, int dismisses);

  /// No description provided for @rankScore.
  ///
  /// In en, this message translates to:
  /// **'Rank score {score} · urgency {urgency}'**
  String rankScore(String score, String urgency);

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get placesTitle;

  /// No description provided for @placesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Weather for up to {max} places you care about — they also power the traveller cards.'**
  String placesSubtitle(int max);

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet. Search below to add one.'**
  String get placesEmpty;

  /// No description provided for @placesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get placesAdd;

  /// No description provided for @placesFull.
  ///
  /// In en, this message translates to:
  /// **'You have reached the limit of {max} saved places.'**
  String placesFull(int max);

  /// No description provided for @placesAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save that place. Check the backend connection.'**
  String get placesAddFailed;

  /// No description provided for @placesRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove that place.'**
  String get placesRemoveFailed;

  /// No description provided for @placeKindHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get placeKindHome;

  /// No description provided for @placeKindWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get placeKindWork;

  /// No description provided for @placeKindSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get placeKindSchool;

  /// No description provided for @placeKindTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get placeKindTravel;

  /// No description provided for @placeKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get placeKindOther;

  /// No description provided for @coastal.
  ///
  /// In en, this message translates to:
  /// **'Coastal'**
  String get coastal;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @mapTitle.
  ///
  /// In en, this message translates to:
  /// **'Radar & warnings'**
  String get mapTitle;

  /// No description provided for @mapToggleRadar.
  ///
  /// In en, this message translates to:
  /// **'Toggle the radar layer'**
  String get mapToggleRadar;

  /// No description provided for @mapAttribution.
  ///
  /// In en, this message translates to:
  /// **'Base map © OpenStreetMap contributors · radar frames from RainViewer.'**
  String get mapAttribution;

  /// No description provided for @radarNoFrames.
  ///
  /// In en, this message translates to:
  /// **'No radar frames available right now.'**
  String get radarNoFrames;

  /// No description provided for @radarPastFrame.
  ///
  /// In en, this message translates to:
  /// **'observed'**
  String get radarPastFrame;

  /// No description provided for @radarForecastFrame.
  ///
  /// In en, this message translates to:
  /// **'forecast'**
  String get radarForecastFrame;

  /// No description provided for @lowBandwidthRadarOff.
  ///
  /// In en, this message translates to:
  /// **'Low-bandwidth mode: radar tiles are off.'**
  String get lowBandwidthRadarOff;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @settingsUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// No description provided for @unitsMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric (°C, km/h)'**
  String get unitsMetric;

  /// No description provided for @unitsImperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial (°F, mph)'**
  String get unitsImperial;

  /// No description provided for @settingsHomeLocation.
  ///
  /// In en, this message translates to:
  /// **'Home location'**
  String get settingsHomeLocation;

  /// No description provided for @settingsNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location set'**
  String get settingsNoLocation;

  /// No description provided for @settingsPlacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Places you follow beyond home'**
  String get settingsPlacesSubtitle;

  /// No description provided for @settingsSchoolWindows.
  ///
  /// In en, this message translates to:
  /// **'School run windows'**
  String get settingsSchoolWindows;

  /// No description provided for @settingsCommuteWindows.
  ///
  /// In en, this message translates to:
  /// **'Commute windows'**
  String get settingsCommuteWindows;

  /// No description provided for @settingsAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Data & accessibility'**
  String get settingsAccessibility;

  /// No description provided for @settingsLowBandwidth.
  ///
  /// In en, this message translates to:
  /// **'Low-bandwidth mode'**
  String get settingsLowBandwidth;

  /// No description provided for @settingsLowBandwidthHelp.
  ///
  /// In en, this message translates to:
  /// **'Sends lite=1: trimmed hourly arrays, no radar tiles.'**
  String get settingsLowBandwidthHelp;

  /// No description provided for @settingsLargeText.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get settingsLargeText;

  /// No description provided for @settingsLargeTextHelp.
  ///
  /// In en, this message translates to:
  /// **'Raises the minimum text size across the app.'**
  String get settingsLargeTextHelp;

  /// No description provided for @settingsResetLearning.
  ///
  /// In en, this message translates to:
  /// **'Reset what the app learned'**
  String get settingsResetLearning;

  /// No description provided for @settingsResetLearningHelp.
  ///
  /// In en, this message translates to:
  /// **'Clears taps, dismissals, pins and hidden cards.'**
  String get settingsResetLearningHelp;

  /// No description provided for @settingsResetLearningConfirm.
  ///
  /// In en, this message translates to:
  /// **'This clears every card preference and the ranking history on the server. Continue?'**
  String get settingsResetLearningConfirm;

  /// No description provided for @settingsResetLearningDone.
  ///
  /// In en, this message translates to:
  /// **'Learning reset. The feed is back to its defaults.'**
  String get settingsResetLearningDone;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'SIH 2026 · PS 26076 · a Team Mausam prototype. Not affiliated with, and not endorsed by, the India Meteorological Department.'**
  String get aboutDisclaimer;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @demoTitle.
  ///
  /// In en, this message translates to:
  /// **'Demo controls'**
  String get demoTitle;

  /// No description provided for @demoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scenario, clock and persona overrides for this device only.'**
  String get demoSubtitle;

  /// No description provided for @demoScenario.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get demoScenario;

  /// No description provided for @demoClock.
  ///
  /// In en, this message translates to:
  /// **'Demo clock (IST)'**
  String get demoClock;

  /// No description provided for @demoClockNow.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get demoClockNow;

  /// No description provided for @demoClockPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get demoClockPick;

  /// No description provided for @demoPersona.
  ///
  /// In en, this message translates to:
  /// **'View as persona'**
  String get demoPersona;

  /// No description provided for @demoPersonaMine.
  ///
  /// In en, this message translates to:
  /// **'My personas'**
  String get demoPersonaMine;

  /// No description provided for @demoSimulateOffline.
  ///
  /// In en, this message translates to:
  /// **'Simulate offline'**
  String get demoSimulateOffline;

  /// No description provided for @demoSimulateOfflineHelp.
  ///
  /// In en, this message translates to:
  /// **'Shows the offline behaviour without touching the radio.'**
  String get demoSimulateOfflineHelp;

  /// No description provided for @demoOpenConsole.
  ///
  /// In en, this message translates to:
  /// **'Open admin console'**
  String get demoOpenConsole;

  /// No description provided for @demoReset.
  ///
  /// In en, this message translates to:
  /// **'Reset demo'**
  String get demoReset;

  /// No description provided for @demoActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Demo overrides are active — the feed is not showing live data.'**
  String get demoActiveHint;

  /// No description provided for @demoConsoleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the console. Try this URL:'**
  String get demoConsoleUnavailable;

  /// No description provided for @demoLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live alerts: {status}'**
  String demoLiveStatus(String status);

  /// No description provided for @wsConnected.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get wsConnected;

  /// No description provided for @wsConnecting.
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get wsConnecting;

  /// No description provided for @wsReconnecting.
  ///
  /// In en, this message translates to:
  /// **'reconnecting…'**
  String get wsReconnecting;

  /// No description provided for @wsUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'needs a new token'**
  String get wsUnauthorized;

  /// No description provided for @wsOffline.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get wsOffline;

  /// No description provided for @warningMovedToTop.
  ///
  /// In en, this message translates to:
  /// **'A warning moved to the top of your feed.'**
  String get warningMovedToTop;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @sampleDataBanner.
  ///
  /// In en, this message translates to:
  /// **'Sample data — the backend at {url} is not reachable.'**
  String sampleDataBanner(String url);

  /// No description provided for @liteBadge.
  ///
  /// In en, this message translates to:
  /// **'Lite'**
  String get liteBadge;

  /// No description provided for @liveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Live updates connected'**
  String get liveUpdates;

  /// No description provided for @engineFooterSemantics.
  ///
  /// In en, this message translates to:
  /// **'Ranking details'**
  String get engineFooterSemantics;

  /// No description provided for @aqiGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get aqiGood;

  /// No description provided for @aqiSatisfactory.
  ///
  /// In en, this message translates to:
  /// **'Satisfactory'**
  String get aqiSatisfactory;

  /// No description provided for @aqiModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get aqiModerate;

  /// No description provided for @aqiPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get aqiPoor;

  /// No description provided for @aqiVeryPoor.
  ///
  /// In en, this message translates to:
  /// **'Very poor'**
  String get aqiVeryPoor;

  /// No description provided for @aqiSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get aqiSevere;

  /// No description provided for @comfortUncomfortable.
  ///
  /// In en, this message translates to:
  /// **'Uncomfortable'**
  String get comfortUncomfortable;

  /// No description provided for @comfortFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get comfortFair;

  /// No description provided for @comfortComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortComfortable;

  /// No description provided for @comfortIdeal.
  ///
  /// In en, this message translates to:
  /// **'Ideal'**
  String get comfortIdeal;

  /// No description provided for @soilVeryDry.
  ///
  /// In en, this message translates to:
  /// **'Very dry'**
  String get soilVeryDry;

  /// No description provided for @soilDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get soilDry;

  /// No description provided for @soilAdequate.
  ///
  /// In en, this message translates to:
  /// **'Adequate'**
  String get soilAdequate;

  /// No description provided for @soilWet.
  ///
  /// In en, this message translates to:
  /// **'Wet'**
  String get soilWet;

  /// No description provided for @soilSaturated.
  ///
  /// In en, this message translates to:
  /// **'Saturated'**
  String get soilSaturated;

  /// No description provided for @seaCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get seaCalm;

  /// No description provided for @seaSmooth.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get seaSmooth;

  /// No description provided for @seaSlight.
  ///
  /// In en, this message translates to:
  /// **'Slight'**
  String get seaSlight;

  /// No description provided for @seaModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get seaModerate;

  /// No description provided for @seaRough.
  ///
  /// In en, this message translates to:
  /// **'Rough'**
  String get seaRough;

  /// No description provided for @seaVeryRough.
  ///
  /// In en, this message translates to:
  /// **'Very rough'**
  String get seaVeryRough;

  /// No description provided for @seaHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get seaHigh;

  /// No description provided for @qualityGreat.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get qualityGreat;

  /// No description provided for @qualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get qualityGood;

  /// No description provided for @qualityFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get qualityFair;

  /// No description provided for @qualityPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get qualityPoor;

  /// No description provided for @levelLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get levelLow;

  /// No description provided for @levelMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get levelMedium;

  /// No description provided for @levelHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get levelHigh;

  /// No description provided for @levelSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get levelSevere;

  /// No description provided for @levelNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get levelNone;

  /// No description provided for @intensityLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get intensityLight;

  /// No description provided for @intensityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get intensityModerate;

  /// No description provided for @intensityHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get intensityHeavy;

  /// No description provided for @intensityVeryHeavy.
  ///
  /// In en, this message translates to:
  /// **'Very heavy'**
  String get intensityVeryHeavy;

  /// No description provided for @hazardHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get hazardHeavyRain;

  /// No description provided for @hazardVeryHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Very heavy rain'**
  String get hazardVeryHeavyRain;

  /// No description provided for @hazardThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get hazardThunderstorm;

  /// No description provided for @hazardLightning.
  ///
  /// In en, this message translates to:
  /// **'Lightning'**
  String get hazardLightning;

  /// No description provided for @hazardHeatwave.
  ///
  /// In en, this message translates to:
  /// **'Heatwave'**
  String get hazardHeatwave;

  /// No description provided for @hazardColdWave.
  ///
  /// In en, this message translates to:
  /// **'Cold wave'**
  String get hazardColdWave;

  /// No description provided for @hazardFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get hazardFog;

  /// No description provided for @hazardDustStorm.
  ///
  /// In en, this message translates to:
  /// **'Dust storm'**
  String get hazardDustStorm;

  /// No description provided for @hazardCyclone.
  ///
  /// In en, this message translates to:
  /// **'Cyclone'**
  String get hazardCyclone;

  /// No description provided for @hazardStrongWind.
  ///
  /// In en, this message translates to:
  /// **'Strong wind'**
  String get hazardStrongWind;

  /// No description provided for @hazardSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get hazardSnow;

  /// No description provided for @hazardFlood.
  ///
  /// In en, this message translates to:
  /// **'Flood'**
  String get hazardFlood;

  /// No description provided for @seasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get seasonWinter;

  /// No description provided for @seasonPreMonsoon.
  ///
  /// In en, this message translates to:
  /// **'Pre-monsoon'**
  String get seasonPreMonsoon;

  /// No description provided for @seasonMonsoon.
  ///
  /// In en, this message translates to:
  /// **'Monsoon'**
  String get seasonMonsoon;

  /// No description provided for @seasonPostMonsoon.
  ///
  /// In en, this message translates to:
  /// **'Post-monsoon'**
  String get seasonPostMonsoon;

  /// No description provided for @windowMorningDrop.
  ///
  /// In en, this message translates to:
  /// **'Morning drop'**
  String get windowMorningDrop;

  /// No description provided for @windowAfternoonPickup.
  ///
  /// In en, this message translates to:
  /// **'Afternoon pickup'**
  String get windowAfternoonPickup;

  /// No description provided for @windowMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get windowMorning;

  /// No description provided for @windowEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get windowEvening;

  /// No description provided for @windowEarlyMorning.
  ///
  /// In en, this message translates to:
  /// **'Early morning'**
  String get windowEarlyMorning;

  /// No description provided for @windowLateMorning.
  ///
  /// In en, this message translates to:
  /// **'Late morning'**
  String get windowLateMorning;

  /// No description provided for @windowAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get windowAfternoon;

  /// No description provided for @windowNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get windowNight;

  /// No description provided for @nothingToFlag.
  ///
  /// In en, this message translates to:
  /// **'Nothing to flag right now.'**
  String get nothingToFlag;

  /// No description provided for @nothingToAdd.
  ///
  /// In en, this message translates to:
  /// **'Nothing to add.'**
  String get nothingToAdd;

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreItems(int count);

  /// No description provided for @placeFallback.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeFallback;

  /// No description provided for @nextDays.
  ///
  /// In en, this message translates to:
  /// **'next {days} days'**
  String nextDays(int days);

  /// No description provided for @nothingToPack.
  ///
  /// In en, this message translates to:
  /// **'Nothing special to pack.'**
  String get nothingToPack;

  /// No description provided for @itemFallback.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get itemFallback;

  /// No description provided for @savedPlaceFallback.
  ///
  /// In en, this message translates to:
  /// **'Saved place'**
  String get savedPlaceFallback;

  /// No description provided for @riskWithLevel.
  ///
  /// In en, this message translates to:
  /// **'{level} risk'**
  String riskWithLevel(String level);

  /// No description provided for @seasonWithName.
  ///
  /// In en, this message translates to:
  /// **'{season} season'**
  String seasonWithName(String season);

  /// No description provided for @zoneWithName.
  ///
  /// In en, this message translates to:
  /// **'{zone} zone'**
  String zoneWithName(String zone);

  /// No description provided for @cropFallback.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get cropFallback;

  /// No description provided for @warningInForce.
  ///
  /// In en, this message translates to:
  /// **'Warning in force'**
  String get warningInForce;

  /// No description provided for @peaksAround.
  ///
  /// In en, this message translates to:
  /// **'Peaks around {time}'**
  String peaksAround(String time);

  /// No description provided for @airTemp.
  ///
  /// In en, this message translates to:
  /// **'Air temp'**
  String get airTemp;

  /// No description provided for @heatIndex.
  ///
  /// In en, this message translates to:
  /// **'Heat index'**
  String get heatIndex;

  /// No description provided for @frostRiskWithLevel.
  ///
  /// In en, this message translates to:
  /// **'{level} frost risk'**
  String frostRiskWithLevel(String level);

  /// No description provided for @expectedNight.
  ///
  /// In en, this message translates to:
  /// **'Expected on {day} night'**
  String expectedNight(String day);

  /// No description provided for @minTemp.
  ///
  /// In en, this message translates to:
  /// **'Min temp'**
  String get minTemp;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @fromTime.
  ///
  /// In en, this message translates to:
  /// **'From {time}'**
  String fromTime(String time);

  /// No description provided for @untilTime.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String untilTime(String time);

  /// No description provided for @peakAtTime.
  ///
  /// In en, this message translates to:
  /// **'· peak {time}'**
  String peakAtTime(String time);

  /// No description provided for @rainWithIntensity.
  ///
  /// In en, this message translates to:
  /// **'{intensity} rain'**
  String rainWithIntensity(String intensity);

  /// No description provided for @peakChance.
  ///
  /// In en, this message translates to:
  /// **'Peak chance'**
  String get peakChance;

  /// No description provided for @expected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get expected;

  /// No description provided for @alertFallback.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alertFallback;

  /// No description provided for @noDailyRainfall.
  ///
  /// In en, this message translates to:
  /// **'No daily rainfall data.'**
  String get noDailyRainfall;

  /// No description provided for @axisRainChance.
  ///
  /// In en, this message translates to:
  /// **'Chance of rain, % per day'**
  String get axisRainChance;

  /// No description provided for @focusDayWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Focus day · {label}'**
  String focusDayWithLabel(String label);

  /// No description provided for @onTheDay.
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get onTheDay;

  /// No description provided for @axisRainfallMm.
  ///
  /// In en, this message translates to:
  /// **'Rainfall, mm per day'**
  String get axisRainfallMm;

  /// No description provided for @wettestDayWithDate.
  ///
  /// In en, this message translates to:
  /// **'Wettest day · {day}'**
  String wettestDayWithDate(String day);

  /// No description provided for @next24h.
  ///
  /// In en, this message translates to:
  /// **'Next 24 h'**
  String get next24h;

  /// No description provided for @next72h.
  ///
  /// In en, this message translates to:
  /// **'Next 72 h'**
  String get next72h;

  /// No description provided for @next7d.
  ///
  /// In en, this message translates to:
  /// **'Next 7 d'**
  String get next7d;

  /// No description provided for @rainDays.
  ///
  /// In en, this message translates to:
  /// **'Rain days'**
  String get rainDays;

  /// No description provided for @countOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String countOfTotal(int count, int total);

  /// No description provided for @noDailyData.
  ///
  /// In en, this message translates to:
  /// **'No daily data.'**
  String get noDailyData;

  /// No description provided for @noHourlyData.
  ///
  /// In en, this message translates to:
  /// **'No hourly data.'**
  String get noHourlyData;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @fieldsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String fieldsCount(int count);

  /// No description provided for @noFurtherDetail.
  ///
  /// In en, this message translates to:
  /// **'No further detail available.'**
  String get noFurtherDetail;

  /// No description provided for @noReading.
  ///
  /// In en, this message translates to:
  /// **'No reading available.'**
  String get noReading;

  /// No description provided for @aqiScaleNote.
  ///
  /// In en, this message translates to:
  /// **'{scale} AQI · 0–500'**
  String aqiScaleNote(String scale);

  /// No description provided for @comfortScaleNote.
  ///
  /// In en, this message translates to:
  /// **'Comfort index · 0–100'**
  String get comfortScaleNote;

  /// No description provided for @soilScaleNote.
  ///
  /// In en, this message translates to:
  /// **'Volumetric water content, surface 0–1 cm'**
  String get soilScaleNote;

  /// No description provided for @dominant.
  ///
  /// In en, this message translates to:
  /// **'Dominant'**
  String get dominant;

  /// No description provided for @rootZone.
  ///
  /// In en, this message translates to:
  /// **'Root zone'**
  String get rootZone;

  /// No description provided for @soilTemp.
  ///
  /// In en, this message translates to:
  /// **'Soil temp'**
  String get soilTemp;

  /// No description provided for @sinceRain.
  ///
  /// In en, this message translates to:
  /// **'Since rain'**
  String get sinceRain;

  /// No description provided for @daysShort.
  ///
  /// In en, this message translates to:
  /// **'{count} d'**
  String daysShort(int count);

  /// No description provided for @noNowcast.
  ///
  /// In en, this message translates to:
  /// **'No nowcast issued for this location.'**
  String get noNowcast;

  /// No description provided for @validTill.
  ///
  /// In en, this message translates to:
  /// **'Valid till {time}'**
  String validTill(String time);

  /// No description provided for @issuedAt.
  ///
  /// In en, this message translates to:
  /// **'Issued {time}'**
  String issuedAt(String time);

  /// No description provided for @noSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'No saved places yet.'**
  String get noSavedPlaces;

  /// No description provided for @localTimeAt.
  ///
  /// In en, this message translates to:
  /// **'local time {time}'**
  String localTimeAt(String time);

  /// No description provided for @highLow.
  ///
  /// In en, this message translates to:
  /// **'High / low'**
  String get highLow;

  /// No description provided for @activeWarning.
  ///
  /// In en, this message translates to:
  /// **'Active warning'**
  String get activeWarning;

  /// No description provided for @rainWithin2h.
  ///
  /// In en, this message translates to:
  /// **'Rain within 2 h'**
  String get rainWithin2h;

  /// No description provided for @rainWithin2hValue.
  ///
  /// In en, this message translates to:
  /// **'Rain within 2 h · {pct}'**
  String rainWithin2hValue(String pct);

  /// No description provided for @radarFrameAt.
  ///
  /// In en, this message translates to:
  /// **'RainViewer · frame {time}'**
  String radarFrameAt(String time);

  /// No description provided for @frameOf.
  ///
  /// In en, this message translates to:
  /// **'Frame {index} of {total}'**
  String frameOf(int index, int total);

  /// No description provided for @frames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get frames;

  /// No description provided for @noMarineData.
  ///
  /// In en, this message translates to:
  /// **'No marine data for this location.'**
  String get noMarineData;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @seaTemp.
  ///
  /// In en, this message translates to:
  /// **'Sea temp'**
  String get seaTemp;

  /// No description provided for @swell.
  ///
  /// In en, this message translates to:
  /// **'Swell'**
  String get swell;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @fromDirection.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromDirection;

  /// No description provided for @safeSwim.
  ///
  /// In en, this message translates to:
  /// **'Safe for swimming'**
  String get safeSwim;

  /// No description provided for @notSafeSwim.
  ///
  /// In en, this message translates to:
  /// **'Not safe for swimming'**
  String get notSafeSwim;

  /// No description provided for @waveHeightNextHours.
  ///
  /// In en, this message translates to:
  /// **'Wave height, next {hours} h'**
  String waveHeightNextHours(int hours);

  /// No description provided for @surf.
  ///
  /// In en, this message translates to:
  /// **'Surf'**
  String get surf;

  /// No description provided for @highestWaves.
  ///
  /// In en, this message translates to:
  /// **'Highest waves'**
  String get highestWaves;

  /// No description provided for @around.
  ///
  /// In en, this message translates to:
  /// **'Around'**
  String get around;

  /// No description provided for @douglasScale.
  ///
  /// In en, this message translates to:
  /// **'Douglas sea scale'**
  String get douglasScale;

  /// No description provided for @noTideTable.
  ///
  /// In en, this message translates to:
  /// **'No tide table for this location.'**
  String get noTideTable;

  /// No description provided for @metresNow.
  ///
  /// In en, this message translates to:
  /// **'{value} m now'**
  String metresNow(String value);

  /// No description provided for @tideHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tideHigh;

  /// No description provided for @tideLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tideLow;

  /// No description provided for @nextTide.
  ///
  /// In en, this message translates to:
  /// **'Next: {type} tide at {time} ({height} m)'**
  String nextTide(String type, String time, String height);

  /// No description provided for @turningPoints.
  ///
  /// In en, this message translates to:
  /// **'Turning points'**
  String get turningPoints;

  /// No description provided for @noWindow.
  ///
  /// In en, this message translates to:
  /// **'No window in the forecast period.'**
  String get noWindow;

  /// No description provided for @overallWithVerdict.
  ///
  /// In en, this message translates to:
  /// **'Overall: {verdict}'**
  String overallWithVerdict(String verdict);

  /// No description provided for @temp.
  ///
  /// In en, this message translates to:
  /// **'Temp'**
  String get temp;

  /// No description provided for @delay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get delay;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'+{count} min'**
  String minutesShort(int count);

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @impactWithLevel.
  ///
  /// In en, this message translates to:
  /// **'{level} impact'**
  String impactWithLevel(String level);

  /// No description provided for @hourlyScore.
  ///
  /// In en, this message translates to:
  /// **'Hourly score'**
  String get hourlyScore;

  /// No description provided for @hourlyScoreHelp.
  ///
  /// In en, this message translates to:
  /// **'100 = perfect conditions; the window bands above are the best runs of hours.'**
  String get hourlyScoreHelp;

  /// No description provided for @traffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get traffic;

  /// No description provided for @congestion.
  ///
  /// In en, this message translates to:
  /// **'Congestion'**
  String get congestion;

  /// No description provided for @schoolDay.
  ///
  /// In en, this message translates to:
  /// **'School day'**
  String get schoolDay;

  /// No description provided for @notSchoolDay.
  ///
  /// In en, this message translates to:
  /// **'Not a school day'**
  String get notSchoolDay;

  /// No description provided for @rainPerHourMm.
  ///
  /// In en, this message translates to:
  /// **'Rain per hour (mm)'**
  String get rainPerHourMm;

  /// No description provided for @rainChancePct.
  ///
  /// In en, this message translates to:
  /// **'Chance of rain (%)'**
  String get rainChancePct;

  /// No description provided for @expectedRainfallMm.
  ///
  /// In en, this message translates to:
  /// **'Expected rainfall (mm)'**
  String get expectedRainfallMm;

  /// No description provided for @hourByHourFocus.
  ///
  /// In en, this message translates to:
  /// **'Hour by hour on the focus day'**
  String get hourByHourFocus;

  /// No description provided for @nextHours.
  ///
  /// In en, this message translates to:
  /// **'Next hours'**
  String get nextHours;

  /// No description provided for @next7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get next7Days;

  /// No description provided for @scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// No description provided for @bestHoursToday.
  ///
  /// In en, this message translates to:
  /// **'Best hours today'**
  String get bestHoursToday;

  /// No description provided for @cachedSuffix.
  ///
  /// In en, this message translates to:
  /// **'cached'**
  String get cachedSuffix;

  /// No description provided for @severityWarningWord.
  ///
  /// In en, this message translates to:
  /// **'{severity} warning. {title}'**
  String severityWarningWord(String severity, String title);

  /// No description provided for @moreLanguagesNote.
  ///
  /// In en, this message translates to:
  /// **'More languages arrive as the translations land; anything untranslated falls back to English.'**
  String get moreLanguagesNote;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @verdictCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get verdictCaution;

  /// No description provided for @verdictAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid'**
  String get verdictAvoid;

  /// No description provided for @severityYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get severityYellow;

  /// No description provided for @severityOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get severityOrange;

  /// No description provided for @severityRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get severityRed;

  /// No description provided for @levelModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get levelModerate;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en', 'hi', 'mr', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return LBn();
    case 'en':
      return LEn();
    case 'hi':
      return LHi();
    case 'mr':
      return LMr();
    case 'ta':
      return LTa();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
