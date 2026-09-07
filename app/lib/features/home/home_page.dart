import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/card.dart';
import '../../data/repositories/home_repo.dart';
import '../../l10n/gen/app_localizations.dart';
import 'providers.dart';
import 'widgets/card_shell.dart';
import 'widgets/freshness_chip.dart';
import 'widgets/offline_banner.dart';
import 'widgets/persona_chips.dart';
import 'widgets/warning_banner.dart';

/// docs/06_MOBILE_SPEC.md §Layout `home/home_page.dart` —
/// CustomScrollView: AppBar(location, demo icon), persona chips row, warning banner, pinned,
/// hero, cards, "More for you" expander, freshness chip, offline banner.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _pinnedKey = GlobalKey();
  bool _showMore = false;

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

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final query = ref.watch(homeQueryProvider);
    final async = ref.watch(homeProvider(query));
    final settings = ref.watch(settingsProvider);
    final role = ref.watch(roleViewProvider);
    final offline = ref.watch(offlineProvider).value ?? false;

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
              FreshnessChip(result: async.value!, onRefresh: _refresh),
          ],
        ),
        actions: [
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
    required this.showMore,
    required this.onToggleMore,
    required this.pinnedKey,
    required this.onBannerTap,
    required this.onRetry,
  });

  final HomeResult result;
  final bool offline;
  final String? role;
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
    final events = ref.read(eventsRepoProvider);

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
      events.recordImpression(card.type, position: position++);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: const PersonaChips()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverList.list(
            children: [
              if (role != null) RoleViewStrip(personaId: role!),
              if (offline)
                StatusStrip(
                  message: l.offlineBanner,
                  icon: Icons.cloud_off_outlined,
                  tone: StatusTone.neutral,
                ),
              if (!offline && result.error != null && !result.isLive)
                StatusStrip(
                  message: l.staleBanner,
                  icon: Icons.sync_problem_outlined,
                  tone: StatusTone.warning,
                  retryLabel: l.retry,
                  onRetry: onRetry,
                ),
              if (result.isFixture)
                StatusStrip(
                  message:
                      '${l.sampleDataBadge} — the backend at ${ref.watch(settingsProvider).backendUrl} is not reachable.',
                  icon: Icons.science_outlined,
                  tone: StatusTone.neutral,
                  retryLabel: l.retry,
                  onRetry: onRetry,
                ),
              if (home.banner != null) ...[
                WarningBanner(banner: home.banner!, onTap: onBannerTap),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < pinned.length; i++)
                Padding(
                  key: i == 0 ? pinnedKey : null,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(card: pinned[i], position: i)
                      .animate()
                      .fadeIn(duration: 240.ms)
                      .slideY(begin: 0.08, end: 0, duration: 280.ms),
                ),
              if (home.hero != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(card: home.hero!, position: pinned.length),
                ),
              for (var i = 0; i < main.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardShell(card: main[i], position: pinned.length + 1 + i),
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
                      child: CardShell(card: card),
                    ),
              ],
              if (hidden.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      ref.read(hiddenCardsProvider.notifier).restoreAll();
                      ref.read(demotedCardsProvider.notifier).restoreAll();
                    },
                    icon: const Icon(Icons.restore),
                    label: Text('${l.restoreHidden} (${hidden.length})'),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'engine v${home.engine['version'] ?? '—'} · ${home.context.activePersonas.join(", ")} · ${home.context.daypart} · ${home.context.season}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
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
