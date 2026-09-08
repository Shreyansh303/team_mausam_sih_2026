// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mausam Personalized';

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingLanguageSubtitle =>
      'You can change this later in Settings.';

  @override
  String get onboardingPersonaTitle => 'What should we watch for you?';

  @override
  String get onboardingPersonaSubtitle =>
      'Pick 1 to 3. The first one you pick is your primary.';

  @override
  String get onboardingLocationTitle => 'Where are you?';

  @override
  String get onboardingLocationSubtitle =>
      'We use this to fetch weather for your area.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Finish';

  @override
  String get skip => 'Skip';

  @override
  String get personaLimitReached => 'You can pick up to 3.';

  @override
  String get personaPrimary => 'Primary';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get searchCity => 'Search for a city';

  @override
  String get popularCities => 'Popular cities';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Search for your city instead.';

  @override
  String get locationServicesOff =>
      'Location services are off. Turn them on or search for your city.';

  @override
  String get locatingYou => 'Finding you…';

  @override
  String get homeTitle => 'Home';

  @override
  String get moreForYou => 'More for you';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get details => 'Details';

  @override
  String get share => 'Share';

  @override
  String get pinToTop => 'Pin to top';

  @override
  String get unpin => 'Unpin';

  @override
  String get hideCard => 'Hide this card';

  @override
  String get restoreHidden => 'Restore hidden cards';

  @override
  String get whyThisCard => 'Why am I seeing this?';

  @override
  String get drivenBy => 'Driven by';

  @override
  String get estimated => 'Estimated';

  @override
  String get pinned => 'Pinned';

  @override
  String get allClear => 'All clear';

  @override
  String get offlineBanner => 'You are offline — showing saved data.';

  @override
  String get staleBanner => 'Could not refresh. Showing saved data.';

  @override
  String get retry => 'Retry';

  @override
  String get updatedJustNow => 'Updated just now';

  @override
  String updatedMinutesAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String updatedHoursAgo(int hours) {
    return 'Updated $hours h ago';
  }

  @override
  String get sampleDataBadge => 'Sample data';

  @override
  String viewingAs(String persona) {
    return 'Viewing as $persona';
  }

  @override
  String get saveRole => 'Save';

  @override
  String get clearRoleView => 'Clear';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsBackendUrl => 'Backend URL';

  @override
  String get settingsBackendUrlHint => 'http://localhost:8000';

  @override
  String get settingsBackendUrlHelp =>
      'Point this at the machine running the FastAPI backend. On a phone use the PC\'s LAN IP.';

  @override
  String get settingsPersonas => 'Your interests';

  @override
  String get settingsAbout => 'About';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get invalidUrl => 'Enter a valid http(s) URL.';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get errorNoData => 'No weather data available right now.';

  @override
  String get loading => 'Loading…';

  @override
  String get personaHealth => 'Health';

  @override
  String get personaHealthTag => 'Air quality, pollen and health advice';

  @override
  String get personaFitness => 'Fitness';

  @override
  String get personaFitnessTag => 'Best windows to run, ride or train';

  @override
  String get personaBeach => 'Beach & sea';

  @override
  String get personaBeachTag => 'Waves, tides and sea temperature';

  @override
  String get personaTraveler => 'Traveller';

  @override
  String get personaTravelerTag => 'Saved places, packing and travel risk';

  @override
  String get personaParent => 'Parent';

  @override
  String get personaParentTag => 'School run, rain alerts and warnings';

  @override
  String get personaAgriculture => 'Farming';

  @override
  String get personaAgricultureTag => 'Soil, rainfall outlook and frost';

  @override
  String get personaCommuter => 'Commuter';

  @override
  String get personaCommuterTag => 'Traffic, visibility and storms';

  @override
  String get personaEventPlanner => 'Event planner';

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
  String get feelsLike => 'Feels like';

  @override
  String get humidity => 'Humidity';

  @override
  String get wind => 'Wind';

  @override
  String get uv => 'UV';

  @override
  String get aqi => 'AQI';

  @override
  String get sunrise => 'Sunrise';

  @override
  String get sunset => 'Sunset';

  @override
  String get high => 'High';

  @override
  String get low => 'Low';

  @override
  String get rainChance => 'Rain';

  @override
  String get next24Hours => 'Next 24 hours';

  @override
  String get sevenDays => '7 days';

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
  String get placesTitle => 'Saved places';

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
}
