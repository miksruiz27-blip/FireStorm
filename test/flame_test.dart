import 'dart:convert';
import 'dart:io';

import 'package:firestorm/data/flame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Expected values from backend/src/flame.js with the same params (assets/snapshot/flame.json).
  final m = FlameModel(
    jsonDecode(File('assets/snapshot/flame.json').readAsStringSync()) as Map,
  );

  test('Dart forecast = backend flame.js', () {
    final lunar = m.predict(
      o2: 30,
      kpa: 70.33,
      g: .165,
      flow: 10,
      material: 'pmma',
    );
    expect(lunar.loi, closeTo(16.19, .01));
    expect(lunar.spread, closeTo(.86, .01));
    expect(lunar.uEff, closeTo(19.3, .05));
    expect(lunar.regime, FlameRegime.vigorous);
    expect(lunar.extrapolated, isEmpty); // tested at 0.16 g since the partial-g drop
    expect(m.predict(o2: 30, kpa: 70.33, g: .6, flow: 10, material: 'pmma').extrapolated, hasLength(1));

    final quietIss = m.predict(o2: 21, kpa: 101.35, g: 0, material: 'silicone');
    expect(quietIss.loi, closeTo(35.31, .01));
    expect(quietIss.regime, FlameRegime.extinguishes);
    expect(quietIss.oxygenStarved, isTrue);
    expect(quietIss.extrapolated, isEmpty);

    final mars = m.predict(
      o2: 34,
      kpa: 56.5,
      g: .38,
      flow: 25,
      material: 'cotton-fiberglass fabric',
    );
    expect(mars.loi, closeTo(20.21, .01));
    expect(mars.spread, closeTo(4.7, .01));
  });
}
