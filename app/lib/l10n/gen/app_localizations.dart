import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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
    Locale('en'),
    Locale('hi'),
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
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'hi':
      return LHi();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
