import '../../l10n/gen/app_localizations.dart';

/// Persona id (docs/00_VISION.md, docs/02 affinity matrix) → localized label / one-liner.
/// Kept in one place because the onboarding grid, the home persona chips and the why sheet all
/// need it.
String personaLabel(L l, String id) {
  switch (id) {
    case 'health':
      return l.personaHealth;
    case 'fitness':
      return l.personaFitness;
    case 'beach':
      return l.personaBeach;
    case 'traveler':
      return l.personaTraveler;
    case 'parent':
      return l.personaParent;
    case 'agriculture':
      return l.personaAgriculture;
    case 'commuter':
      return l.personaCommuter;
    case 'event_planner':
      return l.personaEventPlanner;
    default:
      return id;
  }
}

String personaTagline(L l, String id) {
  switch (id) {
    case 'health':
      return l.personaHealthTag;
    case 'fitness':
      return l.personaFitnessTag;
    case 'beach':
      return l.personaBeachTag;
    case 'traveler':
      return l.personaTravelerTag;
    case 'parent':
      return l.personaParentTag;
    case 'agriculture':
      return l.personaAgricultureTag;
    case 'commuter':
      return l.personaCommuterTag;
    case 'event_planner':
      return l.personaEventPlannerTag;
    default:
      return '';
  }
}
