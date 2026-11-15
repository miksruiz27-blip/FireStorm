import 'dart:convert';
import 'dart:io';

import 'package:firestorm/data/predictor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final m = BurnPredictor(jsonDecode(File('assets/snapshot/model.json').readAsStringSync()) as Map);

  test('Dart regression = backend model.js fallbackP', () {
    // Reference values from node (backend/src/model.js fallbackP) on the same model.json.
    for (final (x, p) in [
      ((21.0, 101.3, 10.0), 0.877968),
      ((16.0, 101.3, 10.0), 0.086787),
      ((30.0, 56.5, 0.0), 0.999559),
      ((18.0, 101.3, 20.0), 0.230128),
    ]) {
      final r = m.predict(o2: x.$1, kpa: x.$2, flow: x.$3, g: 0);
      expect(r.p, closeTo(p, 1e-6));
      expect(r.outside, isEmpty);
    }
  });

  test('outside the ISS training domain it refuses', () {
    expect(m.predict(o2: 34, kpa: 56.5, flow: 10, g: .166).outside, isNotEmpty); // lunar gravity
    expect(m.predict(o2: 100, kpa: 29.6, flow: 0, g: 0).outside, isNotEmpty); // suit O₂
  });
}
