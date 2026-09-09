import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/data/api_client.dart';
import 'package:mausam_app/data/repositories/profile_repo.dart';
import 'package:mausam_app/features/home/providers.dart';

/// A `ProfileRepo` that answers `/me/card-prefs` from memory. `cardPrefs()` already maps every
/// [ApiException] to `null` (that is the offline contract), so "the backend is down" is modelled
/// as `null` — and `_ThrowingProfileRepo` below covers the case where something *else* throws.
class _FakeProfileRepo extends ProfileRepo {
  _FakeProfileRepo(this.prefs) : super(api: ApiClient(baseUrl: 'http://127.0.0.1:1'));

  final CardPrefs? prefs;
  int calls = 0;

  @override
  Future<CardPrefs?> cardPrefs() async {
    calls++;
    return prefs;
  }
}

class _ThrowingProfileRepo extends ProfileRepo {
  _ThrowingProfileRepo(this.error) : super(api: ApiClient(baseUrl: 'http://127.0.0.1:1'));

  final Object error;

  @override
  Future<CardPrefs?> cardPrefs() async => throw error;
}

void main() {
  ProviderContainer containerWith(ProfileRepo repo) {
    final container = ProviderContainer(
      overrides: [profileRepoProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('seedCardPrefs (docs/04 GET /me/card-prefs)', () {
    test('seeds the hidden ids the server already knows about', () async {
      final repo = _FakeProfileRepo(
        const CardPrefs(pins: <String>['warnings'], hidden: <String>['aqi', 'pollen']),
      );
      final container = containerWith(repo);

      expect(container.read(hiddenCardsProvider), isEmpty);
      await seedCardPrefs(container);

      expect(repo.calls, 1);
      expect(container.read(hiddenCardsProvider), <String>{'aqi', 'pollen'});
    });

    test('a failing repo leaves the defaults alone', () async {
      // `cardPrefs()` returns null for any ApiException — an unreachable backend, a 401 before
      // the guest token lands, a timeout.
      final container = containerWith(_FakeProfileRepo(null));

      await seedCardPrefs(container);

      expect(container.read(hiddenCardsProvider), isEmpty);
    });

    test('a repo that throws does not escape, so start-up is never blocked', () async {
      final api = containerWith(_ThrowingProfileRepo(ApiException('offline', isNetwork: true)));
      await expectLater(seedCardPrefs(api), completes);
      expect(api.read(hiddenCardsProvider), isEmpty);

      final other = containerWith(_ThrowingProfileRepo(StateError('boom')));
      await expectLater(seedCardPrefs(other), completes);
      expect(other.read(hiddenCardsProvider), isEmpty);
    });

    test('empty prefs are a no-op', () async {
      final container = containerWith(_FakeProfileRepo(const CardPrefs()));

      await seedCardPrefs(container);

      expect(container.read(hiddenCardsProvider), isEmpty);
    });

    test('the seed unions with hides made while it was in flight', () async {
      final container = containerWith(_FakeProfileRepo(const CardPrefs(hidden: <String>['aqi'])));

      // The user hides a card before the round trip comes back; it must not pop back into the
      // feed when the server's (older) set arrives.
      container.read(hiddenCardsProvider.notifier).hide('tides');
      await seedCardPrefs(container);

      expect(container.read(hiddenCardsProvider), <String>{'tides', 'aqi'});
    });

    test('seed ignores blank ids and an empty list', () {
      final container = containerWith(_FakeProfileRepo(null));
      final notifier = container.read(hiddenCardsProvider.notifier);

      notifier.seed(const <String>[]);
      expect(container.read(hiddenCardsProvider), isEmpty);

      notifier.seed(const <String>['', 'radar']);
      expect(container.read(hiddenCardsProvider), <String>{'radar'});
    });
  });
}
