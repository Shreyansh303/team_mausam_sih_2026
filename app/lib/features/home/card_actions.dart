import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/card.dart';
import '../../data/repositories/events_repo.dart';
import 'providers.dart';

/// Every card gesture in one place: it queues the `/events` action (docs/04 §Engagement events),
/// applies the local effect so the UI reacts instantly, and — for the actions the backend turns
/// into card-prefs — flushes the queue and re-fetches `/home` so the next frame shows the
/// re-ranked feed (docs/06 §Why sheet: "Each sends the event and refreshes home").
///
/// Order matters: flush **before** invalidating `/home`, otherwise the ranker answers with the
/// old preferences.
class CardActions {
  CardActions(this._ref);

  final Ref _ref;

  EventsRepo get _events => _ref.read(eventsRepoProvider);

  /// Fire-and-forget actions (docs/04: `impression|tap|expand`).
  void impression(String type, {int? position}) =>
      _events.recordImpression(type, position: position);

  void tap(HomeCard card, {int? position}) =>
      _events.record(card.type, 'tap', position: position);

  void expand(HomeCard card, {int? position}) =>
      _events.record(card.type, 'expand', position: position);

  /// docs/06 §Card shell — swipe-left / "Show less": the card drops to "More for you". The
  /// server records a `dismiss` and lowers the type's affinity; the feed is not re-fetched,
  /// because the card the user just pushed down must not jump straight back.
  void dismiss(HomeCard card, {int? position}) {
    _events.record(card.type, 'dismiss', position: position);
    _ref.read(demotedCardsProvider.notifier).demote(card.type);
  }

  Future<void> pin(HomeCard card, {int? position}) =>
      _prefAction(card, card.pinned ? 'unpin' : 'pin', position: position);

  Future<void> hide(HomeCard card, {int? position}) async {
    _ref.read(hiddenCardsProvider.notifier).hide(card.type);
    await _prefAction(card, 'hide', position: position);
  }

  Future<void> unhide(String type) async {
    _ref.read(hiddenCardsProvider.notifier).unhide(type);
    _events.record(type, 'unhide');
    await _flushAndRefresh();
  }

  /// "Restore hidden cards" from the why sheet / feed footer.
  Future<void> restoreAll() async {
    final hidden = _ref.read(hiddenCardsProvider);
    for (final type in hidden) {
      _events.record(type, 'unhide');
    }
    _ref.read(hiddenCardsProvider.notifier).restoreAll();
    _ref.read(demotedCardsProvider.notifier).restoreAll();
    await _flushAndRefresh();
  }

  /// docs/04 `POST /me/reset-learning` (Settings → "Reset what the app learned").
  Future<bool> resetLearning() async {
    _ref.read(hiddenCardsProvider.notifier).restoreAll();
    _ref.read(demotedCardsProvider.notifier).restoreAll();
    final ok = await _ref.read(profileRepoProvider).resetLearning();
    await _flushAndRefresh();
    return ok;
  }

  /// docs/04 `Action.id == "share"`. Shares the card's own words, never a screenshot.
  Future<void> share(HomeCard card) async {
    _events.record(card.type, 'tap');
    final lines = <String>[
      card.title,
      if (card.subtitle.isNotEmpty) card.subtitle,
      if (card.insight != null && card.insight!.headline.isNotEmpty) card.insight!.headline,
      if (card.insight != null && card.insight!.detail.isNotEmpty) card.insight!.detail,
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  Future<void> _prefAction(HomeCard card, String action, {int? position}) async {
    _events.record(card.type, action, position: position);
    await _flushAndRefresh();
  }

  Future<void> _flushAndRefresh() async {
    await _events.flush();
    _ref.invalidate(homeProvider(_ref.read(homeQueryProvider)));
  }
}

// `profileRepoProvider` moved to providers.dart in S-app, next to the start-up seeding that
// reads `/me/card-prefs`; it is re-exported through the `providers.dart` import above.

final cardActionsProvider = Provider<CardActions>(CardActions.new);
