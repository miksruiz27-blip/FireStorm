import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firestorm/app/i18n.dart';
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

/// The physics model's one figure (assets/snapshot/flame.json), shown on Forecast and Gap map.
const _modelN = 'n = 137 test points labelled burn/extinct · accuracy 77 %';

void main() {
  setUpAll(() => (loadHabitats(), loadDataTranslations()).wait);
  tearDown(() => lang.value = Lang.en);
  testWidgets('selecting a habitat updates telemetry and stats', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1400));
    await _settle(tester);
    expect(find.text('SELECT HABITAT'), findsOneWidget);
    expect(
      find.text('6 / 49'),
      findsOneWidget,
    ); // Lunar Base: relevance ≥ 50 (snapshot)
    expect(
      find.text('EMPTY'),
      findsOneWidget,
    ); // no verified series near 34 % O₂ at lunar g (F4 audit)

    await tester.tap(find.text('SPACESUIT'));
    await _settle(tester);
    expect(find.text('2 / 49'), findsOneWidget);
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
      find.text('SAFFIRE-IV-VI'),
      findsNWidgets(2),
    ); // top row (exploration-atmosphere fire tests) + why panel
    expect(find.text('SCORE FACTORS'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Liquid fuel')));
    await tester.pump();
    expect(find.text('SAFFIRE-IV-VI'), findsNothing);
    expect(
      find.text('PSI-68'),
      findsNWidgets(2),
    ); // first liquid row (FLEX-2 droplets) is auto-selected
    expect(find.text('SCORE FACTORS'), findsOneWidget); // API breakdown
  });

  testWidgets('gap map: lunar base sits in an unvalidated zone; ISS does not', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1400));
    await tester.tap(find.text('ANALYZE HABITAT'));
    await _settle(tester);

    expect(find.text('DATA GAP MAP'), findsOneWidget);
    expect(find.text('UNVALIDATED ZONE'), findsOneWidget);
    // nearest evidence for Lunar Base (snapshot): SAFFIRE at 34 % in μg, SoFIE (ISS CIR) at 37 % in μg.
    expect(find.text('Δg μg'), findsOneWidget);
    expect(find.text('ΔO₂ +3'), findsOneWidget);
    // Model blind spot → the backend's top suggested test sits right at the habitat.
    expect(find.text('MODEL BLIND HERE'), findsOneWidget);
    expect(find.textContaining(_modelN), findsOneWidget); // same figure as Forecast (F6)
    expect(find.text('Burn tests at 34 % O₂ · 0.166 g'), findsOneWidget);

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
        find.text('FLAME FORECAST · LUNAR BASE'),
        findsNWidgets(2),
      ); // RiskCard: physics forecast at the habitat (34 % O₂), cached turn + offline turn
      expect(find.text('SAFE AT 34 % O₂ · MOC ABOVE 34 %'), findsOneWidget);
      // Offline cache still cites real records: title, PSI/NTRS ref and link (F2 + F8).
      expect(find.textContaining('https://psi.nasa.gov/physci/repo/data/investigations/PSI-'), findsWidgets);
      expect(find.text('BURNS AT 34 % O₂ · MOC AT OR BELOW 34 %'), findsOneWidget);
      expect(find.textContaining('Based on'), findsNWidgets(2));
      // Turn 2 is not cached → offline copilot, retrieval routed by the ONNX classifier (FFI).
      expect(find.textContaining('ON-DEVICE AI · ONNX'), findsOneWidget);
      expect(find.textContaining('ON-DEVICE ONNX CLASSIFIER ·'), findsOneWidget);
      // Lunar gravity is untested → flagged as a physics extrapolation.
      expect(find.textContaining('Physics extrapolation, untested'), findsWidgets);

      await tester.tap(find.text('Gap map'));
      await _settle(tester);
      await tester.ensureVisible(find.text('ASK COPILOT ABOUT THIS GAP'));
      await tester.tap(find.text('ASK COPILOT ABOUT THIS GAP'));
      await _answers(tester);
      expect(
        find.textContaining('What would it take to validate'),
        findsOneWidget,
      );
      expect(find.textContaining('ON-DEVICE AI · ONNX'), findsNWidgets(2));
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
    expect(find.text('Incidents (2)'), findsOneWidget);
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

  testWidgets('forecast: lunar burns untested, sliders and ranks react', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 2000));
    await tester.tap(find.text('Forecast')); // nav rail
    await _settle(tester);
    expect(find.text('FLAME FORECAST'), findsOneWidget);
    expect(find.textContaining(_modelN), findsOneWidget); // same figure as Gap map (F6)
    expect(find.text('VIGOROUS'), findsWidgets);
    expect(find.text('PHYSICS EXTRAPOLATION · UNTESTED'), findsOneWidget);

    await tester.tap(
      find.text('μg'),
    ); // gravity → microgravity, cabin flow 10 cm/s
    await tester.pump();
    expect(find.text('RESET TO HABITAT'), findsOneWidget);
    await tester.tap(find.text('RESET TO HABITAT'));
    await tester.pump();
    expect(find.text('PHYSICS EXTRAPOLATION · UNTESTED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forecast lays out on a phone without overflow', (tester) async {
    await _pumpApp(tester, const Size(390, 844));
    await tester.tap(find.text('Forecast')); // bottom bar
    await _settle(tester);
    expect(find.text('FLAME FORECAST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN/ES switch flips UI and catalog data, stays on the screen', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1440, 1800));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Switch language to Spanish'));
    await _settle(tester);
    expect(find.text('ELIGE EL HÁBITAT'), findsOneWidget);
    expect(find.text('Pronóstico'), findsOneWidget); // nav rail
    expect(find.text('CRÍTICO'), findsOneWidget); // spacesuit card
    expect(find.text('ALTO'), findsNWidgets(3)); // lunar + rover cards, telemetry bar (Lunar Base)

    await tester.tap(find.text('VER RANKING'));
    await _settle(tester);
    expect(find.text('RANKING DE INVESTIGACIONES'), findsOneWidget);
    await tester.tap(find.text('BASS-II'));
    await tester.pump();
    await tester.tap(find.text('ABRIR REPORTE'));
    await _settle(tester);
    expect(find.text('HALLAZGOS CLAVE'), findsOneWidget);
    expect(find.text('RELEVANCIA · BASE LUNAR'), findsOneWidget);
    expect(find.text('EXPORTAR PDF'), findsOneWidget);
    // Catalog text back in its Spanish original (translations_en.json, inverted).
    expect(
      find.textContaining('Las muestras de PMMA y tejido SIBAL'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Cambiar idioma a inglés'));
    await _settle(tester);
    expect(find.text('KEY FINDINGS'), findsOneWidget); // same report, English
    expect(find.text('EXPORT PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Spanish runs longer: every screen must still fit a phone.
  for (final tab in [
    null,
    'Pronóstico',
    'Ranking',
    'Mapa de vacíos',
    'Copiloto',
    'Reporte',
    'Laboratorio',
  ]) {
    testWidgets('${tab ?? 'Hábitat'} (ES) lays out on a phone', (tester) async {
      lang.value = Lang.es;
      await _pumpApp(tester, const Size(390, 844));
      if (tab != null) {
        await tester.tap(find.text(tab)); // bottom bar
        await _settle(tester);
        if (tab == 'Copiloto') await _answers(tester);
      } else {
        await _settle(tester);
      }
      final e = tester.takeException();
      expect(e, isNull, reason: e is FlutterError ? e.toStringDeep() : '$e');
    });
  }
}
