import 'package:flutter/material.dart';

import '../../../data/models/card.dart';
import 'advice_list.dart';
import 'alert.dart';
import 'daily.dart';
import 'gauge.dart';
import 'generic.dart';
import 'hero.dart';
import 'hourly.dart';
import 'metric.dart';
import 'timeline.dart';
import 'warnings.dart';

/// docs/06_MOBILE_SPEC.md §Layout `home/renderers/registry.dart`.
///
/// B1 implemented hero, warnings, hourly, daily and metric plus the generic fallback; B2a is
/// filling in the ten kinds that were left pending, one commit at a time. Anything still in
/// [pending] resolves to `generic`, which is why docs/06 insists the generic renderer never
/// crashes: it is what every not-yet-written card falls back to.
class RendererRegistry {
  RendererRegistry._();

  /// Renderer kinds with a dedicated widget in this build.
  static const Set<String> implemented = <String>{
    'hero',
    'warnings',
    'hourly',
    'daily',
    'metric',
    'gauge',
    'timeline',
    'alert',
    'advice_list',
  };

  /// Renderer kinds named in docs/02 that currently fall back to `generic`.
  static const Set<String> pending = <String>{
    'nowcast',
    'radar',
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
      case 'gauge':
        return GaugeRenderer(card: card);
      case 'timeline':
        return TimelineRenderer(card: card);
      case 'alert':
        return AlertRenderer(card: card);
      case 'advice_list':
        return AdviceListRenderer(card: card);
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
