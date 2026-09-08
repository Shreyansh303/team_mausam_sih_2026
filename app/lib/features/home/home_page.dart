import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/card.dart';
import '../../data/models/warning.dart';
import '../../data/repositories/home_repo.dart';
import '../../l10n/gen/app_localizations.dart';
import '../demo/demo_sheet.dart';
import 'card_actions.dart';
import 'live_alerts.dart';
import 'providers.dart';
import 'widgets/card_shell.dart';
import 'widgets/freshness_chip.dart';
import 'widgets/offline_banner.dart';
import 'widgets/persona_chips.dart';
import 'widgets/quick_actions.dart';
import 'widgets/warning_banner.dart';

/// docs/06_MOBILE_SPEC.md §Layout `home/home_page.dart` —
/// CustomScrollView: AppBar(location, demo icon), persona chips row, warning banner, quick
/// actions, pinned, hero, cards, "More for you" expander, freshness chip, offline banner.
///
/// docs/06 §Home behaviour also puts the live-alert reaction here: a `warning_issued` that
/// affects this location shows its banner immediately, the feed re-fetches, and the cards whose
/// rank improved flash while a SnackBar says what moved.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _pinnedKey = GlobalKey();
  bool _showMore = false;

  /// instance id → position in the previous payload, for the re-rank diff.
  Map<String, int> _lastOrder = <String, int>{};
  Set<String> _promoted = <String>{};
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(homeProvider(ref.read(homeQueryProvider)));
    await ref.read(homeProvider(ref.read(homeQueryProvider)).future);
  }

  void _scrollToPinned() {
    final ctx = _pinnedKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  /// docs/06 §Packages — "a highlight flash on cards whose position improved + a SnackBar
  /// 'Warning moved to top'". The diff is computed against the previous payload's order, so it
  /// fires for a WebSocket re-rank, a pull-to-refresh and a persona switch alike.
  void _onPayload(HomeResult result) {
    final order = <String, int>{};
    final cards = result.home.orderedCards;
    for (var i = 0; i < cards.length; i++) {
      order[cards[i].instanceId] = i;
    }

    if (_lastOrder.isNotEmpty) {
      final promoted = <String>{};
      for (final entry in order.entries) {
        final before = _lastOrder[entry.key];
        if (before != null && entry.value < before) promoted.add(entry.key);
      }
      final newlyPinned = result.home.pinned
          .where((c) => !_lastOrder.containsKey(c.instanceId) || promoted.contains(c.instanceId))
          .toList();

      if (promoted.isNotEmpty || newlyPinned.isNotEmpty) {
        setState(() => _promoted = <String>{
              ...promoted,
              ...newlyPinned.map((c) => c.instanceId),
            });
        _highlightTimer?.cancel();
        _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _promoted = <String>{});
        });

        final warningCard =
            newlyPinned.where((c) => c.renderer == 'warnings' || c.severity == 'severe');
        if (warningCard.isNotEmpty && mounted) {
          final l = L.of(context);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text(l.warningMovedToTop),
              action: SnackBarAction(label: l.view, onPressed: _scrollToPinned),
            ));
        }
      }
    }
    _lastOrder = order;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = ref.watch(homeQueryProvider);
    final async = ref.watch(homeProvider(query));
    final settings = ref.watch(settingsProvider);
    final role = ref.watch(roleViewProvider);
    final offline = ref.watch(offlineProvider).value ?? false;
    // Watching the live-alerts notifier is what opens `/ws/alerts` (docs/06 §Home behaviour:
    // "connect on home").
    final live = ref.watch(liveAlertsProvider);

    ref.listen<AsyncValue<HomeResult>>(homeProvider(query), (previous, next) {
      final value = next.value;
      if (value != null) _onPayload(value);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              async.value?.home.location.name ?? settings.homeLocation?.name ?? l.homeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (async.hasValue)
              FreshnessChip(result: async.value!, onRefresh: _refresh, live: live.isLive),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.demoTitle,
            onPressed: () => DemoSheet.show(context),
            icon: const Icon(Icons.science_outlined),
          ),
          IconButton(
            tooltip: l.settingsTitle,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: async.when(
          loading: () => const _HomeSkeleton(),
          error: (error, _) => _HomeError(message: '$error', onRetry: _refresh),
          data: (result) => _HomeBody(
            result: result,
            offline: offline,
            role: role,
            live: live,
            promoted: _promoted,
            showMore: _showMore,
            onToggleMore: () => setState(() => _showMore = !_showMore),
            pinnedKey: _pinnedKey,
            onBannerTap: _scrollToPinned,
            onRetry: _refresh,
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.result,
    required this.offline,
    required this.role,
    required this.live,
    required this.promoted,
    required this.showMore,
    required this.onToggleMore,
    required this.pinnedKey,
    required this.onBannerTap,
    required this.onRetry,
  });

  final HomeResult result;
  final bool offline;
  final String? role;
  final LiveAlertsState live;
  final Set<String> promoted;
  final bool showMore;
  final VoidCallback onToggleMore;
  final GlobalKey pinnedKey;
  final VoidCallback onBannerTap;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final home = result.home;
    final hidden = ref.watch(hiddenCardsProvider);
    final demoted = ref.watch(demotedCardsProvider);
    final settings = ref.watch(settingsProvider);
    final actions = ref.read(cardActionsProvider);

    bool visible(HomeCard c) => !hidden.contains(c.type);

    final pinned = home.pinned.where(visible).toList();
    final main = home.cards.where((c) => visible(c) && !demoted.contains(c.type)).toList();
    final more = <HomeCard>[
      ...home.cards.where((c) => visible(c) && demoted.contains(c.type)),
      ...home.moreCards.where(visible),
    ];

    // docs/06 §Home behaviour — one impression per card per load.
    var position = 0;
    for (final card in <HomeCard>[...pinned, if (home.hero != null) home.hero!, ...main]) {
      actions.impression(card.type, position: position++);
    }

    // The banner is either the one the payload carries, or a warning that arrived over the
    // socket a moment ago and has not made it into `/home` yet (docs/06 §Home behaviour).
    final banner = home.banner ?? _bannerFor(live.warning);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: PersonaChips()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverList.list(
            children: [
              if (role != null) RoleViewStrip(personaId: role!),
              // docs/PROGRESS "B2 — what B1 hands you": with the backend down B1 stacked two
              // banners saying the same thing. One strip, chosen by priority.
              _FeedStatus(result: result, offline: offline, onRetry: onRetry),
              if (banner != null) ...[
                WarningBanner(
                  key: ValueKey<String>('banner_${banner.warningId}'),
                  banner: banner,
                  onTap: onBannerTap,
                  onShare: () => SharePlus.instance.share(
                      ShareParams(text: '${banner.title} — ${home.location.name}')),
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < pinned.length; i++)
                Padding(
                  key: i == 0 ? pinnedKey : null,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(
                    key: ValueKey<String>('card_${pinned[i].instanceId}'),
                    card: pinned[i],
                    position: i,
                    highlighted: promoted.contains(pinned[i].instanceId),
                  )
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.08, end: 0, duration: 280.ms),
                ),
              if (home.hero != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(
                    key: ValueKey<String>('card_${home.hero!.instanceId}'),
                    card: home.hero!,
                    position: pinned.length,
                    highlighted: promoted.contains(home.hero!.instanceId),
                  ),
                ),
              const QuickActions(),
              for (var i = 0; i < main.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(
                    key: ValueKey<String>('card_${main[i].instanceId}'),
                    card: main[i],
                    position: pinned.length + 1 + i,
                    highlighted: promoted.contains(main[i].instanceId),
                  ),
                ),
              if (more.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(l.moreForYou, style: theme.textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onToggleMore,
                      icon: Icon(showMore ? Icons.expand_less : Icons.expand_more),
                      label: Text(showMore ? l.showLess : l.showMore),
                    ),
                  ],
                ),
                if (showMore)
                  for (final card in more)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CardShell(
                        key: ValueKey<String>('more_${card.instanceId}'),
                        card: card,
                      ),
                    ),
              ],
              if (hidden.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: actions.restoreAll,
                    icon: const Icon(Icons.restore),
                    label: Text('${l.restoreHidden} (${hidden.length})'),
                  ),
                ),
              const SizedBox(height: 8),
              Semantics(
                label: l.engineFooterSemantics,
                child: Text(
                  'engine v${home.engine['version'] ?? '—'} · '
                  '${home.context.activePersonas.join(", ")} · ${home.context.daypart} · '
                  '${home.context.season}'
                  '${settings.lowBandwidth ? " · ${l.liteBadge}" : ""}'
                  '${home.context.scenario != "live" ? " · ${home.context.scenario}" : ""}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static HomeBanner? _bannerFor(WeatherWarning? warning) {
    if (warning == null || !warning.isOrangeOrAbove) return null;
    return HomeBanner(
      warningId: warning.id,
      severity: warning.severity,
      title: warning.title,
      colorHex: warning.colorHex,
    );
  }
}

/// One status strip at a time, in priority order: offline → bundled sample → stale cache.
/// Showing two of them (B1's behaviour) said the same thing twice and got the wording wrong for
/// the fixture case.
class _FeedStatus extends ConsumerWidget {
  const _FeedStatus({required this.result, required this.offline, required this.onRetry});

  final HomeResult result;
  final bool offline;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    if (result.isFixture) {
      return StatusStrip(
        message: l.sampleDataBanner(ref.watch(settingsProvider).backendUrl),
        icon: Icons.science_outlined,
        tone: StatusTone.neutral,
        retryLabel: offline ? null : l.retry,
        onRetry: offline ? null : onRetry,
      );
    }
    if (offline) {
      return StatusStrip(
        message: l.offlineBanner,
        icon: Icons.cloud_off_outlined,
        tone: StatusTone.neutral,
      );
    }
    if (result.error != null && !result.isLive) {
      return StatusStrip(
        message: l.staleBanner,
        icon: Icons.sync_problem_outlined,
        tone: StatusTone.warning,
        retryLabel: l.retry,
        onRetry: onRetry,
      );
    }
    return const SizedBox.shrink();
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final height in <double>[150, 110, 110, 90])
          Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(l.errorGeneric, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Center(child: FilledButton(onPressed: onRetry, child: Text(l.retry))),
      ],
    );
  }
}
