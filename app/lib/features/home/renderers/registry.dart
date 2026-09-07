import 'package:flutter/material.dart';

import '../../../data/models/card.dart';
import 'daily.dart';
import 'generic.dart';
import 'hero.dart';
import 'hourly.dart';
import 'metric.dart';
import 'warnings.dart';

/// docs/06_MOBILE_SPEC.md §Layout `home/renderers/registry.dart`.
///
/// B1 implements the six renderers listed in docs/07 §B1 — hero, warnings, hourly, daily,
/// metric — plus the generic fallback. The remaining kinds (nowcast, radar, gauge, advice_list,
/// timeline, alert, sea, tides, places, bar_chart) resolve to `generic` for now, which is why
/// docs/06 insists the generic renderer never crashes: it is what every not-yet-written card
/// falls back to. B2 fills the table in.
class RendererRegistry {
  RendererRegistry._();

  /// Renderer kinds with a dedicated widget in this build.
  static const Set<String> implemented = <String>{
    'hero',
    'warnings',
    'hourly',
    'daily',
    'metric',
  };

  /// Renderer kinds named in docs/02 that currently fall back to `generic`.
  static const Set<String> pending = <String>{
    'nowcast',
    'radar',
    'gauge',
    'advice_list',
    'timeline',
    'alert',
    'sea',
    'tides',
    'places',
    'bar_chart',
  };

  static Widget _dispatch(HomeCard card) {
    switch (card.renderer) {
      case 'hero':
        return HeroRenderer(card: card);
      case 'warnings':
        return WarningsRenderer(card: card);
      case 'hourly':
        return HourlyRenderer(card: card);
      case 'daily':
        return DailyRenderer(card: card, maxRows: card.type == 'extended_forecast' ? 10 : 7);
      case 'metric':
        return MetricRenderer(card: card);
      default:
        return GenericRenderer(card: card);
    }
  }

  /// Builds the body for [card].
  ///
  /// There is deliberately no try/catch here: a widget's `build` runs later, inside the
  /// framework, so a wrapper could not catch it anyway. Safety comes from construction instead —
  /// every renderer reads `card.data` through the coercing helpers in `data/models/json.dart`
  /// and treats a missing or wrongly-typed field as absent, and anything unrecognised lands on
  /// [GenericRenderer]. `app/test/renderers_test.dart` pumps every card in the fixture to keep
  /// that promise honest.
  static Widget build(BuildContext context, HomeCard card) => _dispatch(card);
}
