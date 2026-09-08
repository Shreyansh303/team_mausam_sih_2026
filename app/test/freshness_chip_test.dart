import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mausam_app/data/models/home_response.dart';
import 'package:mausam_app/data/repositories/home_repo.dart';
import 'package:mausam_app/features/home/widgets/freshness_chip.dart';
import 'package:mausam_app/l10n/gen/app_localizations.dart';

import 'fixture.dart';

/// C1 regression for the freshness chip's reference clock.
///
/// `docs/06 §Home behaviour` promises "Updated 12 min ago". The payload's `freshness` block is
/// stamped with the **demo clock** when one is set (docs/04 `now_override`), so measuring it
/// against the device clock made the chip read "Updated 16 h ago" the moment a judge moved the
/// clock to 07:30 in the middle of a live demo.
void main() {
  late HomeResponse home;

  setUpAll(() {
    home = HomeResponse.fromJson(loadDocsFixture('home_parent.json'));
  });

  Future<void> pump(WidgetTester tester, HomeResult result, {String? nowOverride}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: FreshnessChip(result: result, nowOverride: nowOverride),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a demo clock is the reference the age is measured from', (tester) async {
    // The reference payload is generated at 07:30 IST on the demo clock.
    expect(home.context.now, startsWith('2026-09-08T07:30'));
    final result = HomeResult(home: home, source: HomeSource.network);

    await pump(tester, result, nowOverride: '2026-09-08T07:30:00+05:30');
    expect(find.textContaining('just now'), findsOneWidget);

    await pump(tester, result, nowOverride: '2026-09-08T08:20:00+05:30');
    expect(find.textContaining('50 min ago'), findsOneWidget);
  });

  testWidgets('a live payload falls back to the server clock it was generated on', (tester) async {
    // The admin console can set the demo clock before the app even starts, so there is no
    // local override to read; `context.now` carries it instead.
    await pump(tester, HomeResult(home: home, source: HomeSource.network));
    expect(find.textContaining('just now'), findsOneWidget);
  });

  testWidgets('without a demo clock it still ages against the device clock', (tester) async {
    // A cached payload with no usable freshness stamps falls back to `storedAt`.
    final stale = HomeResponse.fromJson(<String, dynamic>{
      ...loadDocsFixture('home_parent.json'),
      'freshness': <String, dynamic>{},
      'generated_at': '',
    });
    await pump(
      tester,
      HomeResult(
        home: stale,
        source: HomeSource.cache,
        storedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      ),
    );
    expect(find.textContaining('12 min ago'), findsOneWidget);
    expect(find.textContaining('cached'), findsOneWidget);
  });
}
