import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firestorm/data/habitats.dart';
import 'package:firestorm/main.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: FirestormApp()));
}

/// Data loads through real IO (mocked HTTP → bundled snapshot), which fake time can't
/// advance: let it run, then settle. Twice for chained providers (marks ← experiments).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  await tester.pumpAndSettle();
}

/// Copilot turns mix real IO (backend → snapshot) with fake-time chunk delays.
Future<void> _answers(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  setUpAll(loadHabitats);
  testWidgets('selecting a habitat updates telemetry and stats', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1400));
    await _settle(tester);
    expect(find.text('SELECT HABITAT'), findsOneWidget);
    expect(
      find.text('13 / 58'),
      findsOneWidget,
    ); // Lunar Base: relevance ≥ 50 (snapshot)
    expect(
      find.text('DENSE'),
      findsOneWidget,
    ); // partial-g drop: 6 series within ±4 % O₂ at lunar g

    await tester.tap(find.text('SPACESUIT'));
    await _settle(tester);
    expect(find.text('2 / 58'), findsOneWidget);
    expect(find.text('CRITICAL'), findsNWidgets(2)); // card tag + telemetry bar
  });

  testWidgets('ranking: navigate, filter by fuel, selection follows', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1400));
    await tester.tap(find.text('VIEW RANKING'));
    await _settle(tester);

    expect(find.text('INVESTIGATION RANKING'), findsOneWidget);
    expect(
      find.text('STD-6001B-SMAC'),
      findsNWidgets(2),
    ); // top row (8.2 psia / 37 % O₂ materials test) + why panel
    expect(find.text('SCORE FACTORS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Liquid fuel')));
    await tester.pump();
    expect(find.text('STD-6001B-SMAC'), findsNothing);
    expect(
      find.text('PSI-68'),
      findsNWidgets(2),
    ); // first liquid row (FLEX-2 droplets) is auto-selected
    expect(find.text('SCORE FACTORS'), findsOneWidget); // API breakdown
  });

  testWidgets('gap map: lunar base has partial-g evidence; ISS in training range', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1400));
    await tester.tap(find.text('ANALYZE HABITAT'));
    await _settle(tester);

    expect(find.text('DATA GAP MAP'), findsOneWidget);
    expect(find.text('EVIDENCE PRESENT'), findsOneWidget);
    // nearest evidence for Lunar Base (snapshot): SoFIE at 32 % in μg, LUCI at 26.5 % at 0.166 g.
    expect(find.text('ΔO₂ +3'), findsOneWidget);
    expect(find.text('34 % O₂ · 0.166 g'), findsOneWidget);
    // The data model has no gravity input → still blind here, even with partial-g burns.
    expect(find.text('MODEL BLIND HERE'), findsOneWidget);
    expect(find.text('Burn tests at 17 % O₂ · 1 g'), findsOneWidget);

    await tester.tap(find.text('Habitat')); // nav rail
    await _settle(tester);
    await tester.tap(find.text('ISS'));
    await tester.tap(find.text('Gap map'));
    await _settle(tester);
    expect(find.text('UNVALIDATED ZONE'), findsNothing);
    expect(find.text('EVIDENCE PRESENT'), findsOneWidget);
    expect(
      find.text('IN TRAINING RANGE'),
      findsOneWidget,
    ); // ISS air at ~101 kPa, μg
  });

  testWidgets(
    'copilot: GenUI answer, coverage warning, follow-up from the gap map',
    (tester) async {
      await _pumpApp(tester, const Size(1440, 1800));
      await tester.tap(find.text('Copilot')); // nav rail
      await _answers(tester);

      // Tests have no network → snapshot. Turn 1 is in the cached demo script.
      expect(find.text('COPILOT · ANSWER'), findsWidgets);
      expect(find.textContaining('OFFLINE CACHE'), findsOneWidget);
      expect(
        find.text('WHAT-IF · 34 % O₂'),
        findsOneWidget,
      ); // RiskCard: physics forecast at the question's O₂
      expect(find.text('MATERIALS THAT BURN AT 34 % O₂'), findsOneWidget);
      expect(find.textContaining('Con base en'), findsOneWidget);
      // Turn 2 is not cached → offline coverage check from the gap-map snapshot:
      // lunar 30 % O₂ is covered since the partial-g drop, so no coverage warning.
      expect(find.textContaining('Outside data coverage'), findsNothing);
      expect(find.text('OFFLINE'), findsOneWidget);

      await tester.tap(find.text('Gap map'));
      await _settle(tester);
      await tester.ensureVisible(find.text('ASK COPILOT ABOUT THIS GAP'));
      await tester.tap(find.text('ASK COPILOT ABOUT THIS GAP'));
      await _answers(tester);
      expect(
        find.textContaining('What would it take to validate'),
        findsOneWidget,
      );
      expect(find.text('OFFLINE'), findsNWidgets(2));
    },
  );

  for (final button in [null, 'VIEW RANKING', 'ANALYZE HABITAT']) {
    testWidgets('${button ?? 'habitat'} lays out on a phone without overflow', (
      tester,
    ) async {
      await _pumpApp(tester, const Size(390, 844));
      if (button != null) {
        await tester.tap(find.text(button));
        await _settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lab: team catalog from the snapshot, lays out on a phone', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Lab')); // bottom bar
    await _settle(tester);
    expect(find.text('TEAM LAB'), findsOneWidget);
    expect(find.text('Experiments (27)'), findsOneWidget);
    expect(find.text('Incidents (3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copilot lays out on a phone without overflow', (tester) async {
    await _pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Copilot')); // bottom bar
    await _answers(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'report: open from ranking, chart marks the habitat, breadcrumb back',
    (tester) async {
      await _pumpApp(tester, const Size(1440, 1800));
      await tester.tap(find.text('VIEW RANKING'));
      await _settle(tester);
      await tester.tap(find.text('BASS-II'));
      await tester.pump();
      await tester.tap(find.text('OPEN REPORT'));
      await _settle(tester);

      expect(find.text('KEY FINDINGS'), findsOneWidget);
      expect(find.text('RELEVANCE · LUNAR BASE'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Measured up to 21 % O₂; Lunar Base sits at 34 %'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel(RegExp('^Back to ranking')));
      await _settle(tester);
      expect(find.text('INVESTIGATION RANKING'), findsOneWidget);

      await tester.tap(find.text('Report')); // nav rail → top-ranked (PSI-68)
      await _settle(tester);
      expect(find.text('KEY FINDINGS'), findsOneWidget);
      expect(find.text('REQUIRED MODIFICATIONS'), findsOneWidget);
    },
  );

  testWidgets('report lays out on a phone without overflow', (tester) async {
    await _pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('VIEW RANKING'));
    await _settle(tester);
    await tester.tap(find.text('BASS-II'));
    await tester.pump();
    await tester.ensureVisible(find.text('OPEN REPORT'));
    await tester.tap(find.text('OPEN REPORT'));
    await _settle(tester);
    expect(find.text('KEY FINDINGS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forecast: lunar burns within tested range, sliders and ranks react', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 2000));
    await tester.tap(find.text('Forecast')); // nav rail
    await _settle(tester);
    expect(find.text('FLAME FORECAST'), findsOneWidget);
    expect(find.text('VIGOROUS'), findsWidgets);
    expect(find.text('WITHIN TESTED RANGE'), findsOneWidget);

    await tester.tap(
      find.text('μg'),
    ); // gravity → microgravity, cabin flow 10 cm/s
    await tester.pump();
    expect(find.text('RESET TO HABITAT'), findsOneWidget);
    await tester.tap(find.text('RESET TO HABITAT'));
    await tester.pump();
    expect(find.text('WITHIN TESTED RANGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forecast lays out on a phone without overflow', (tester) async {
    await _pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Forecast')); // bottom bar
    await _settle(tester);
    expect(find.text('FLAME FORECAST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
