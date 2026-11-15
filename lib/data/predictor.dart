import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// "Does it burn or go out?": the team's logistic regression (trained in Python, coefficients
/// exported to model.json), evaluated in Dart so it answers in airplane mode.
/// Port of backend/src/model.js fallbackP + domainCheck (parity-tested).
class BurnPredictor {
  BurnPredictor(Map j)
    : features = (j['features'] as List).cast<String>(),
      mean = _ds(j['mean']),
      std = _ds(j['std']),
      coef = _ds(j['coef']),
      intercept = (j['intercept'] as num).toDouble(),
      trainG = (j['train_gravity_g'] as num?)?.toDouble() ?? 0,
      accuracy = ((j['metrics'] as Map?)?['linear_accuracy'] as num?)?.toDouble();

  final List<String> features; // o2_pct, pressure_kpa, flow_cm_s
  final List<double> mean, std, coef;
  final double intercept, trainG;
  final double? accuracy; // cross-validated accuracy of this linear model

  static List<double> _ds(Object? l) => [for (final v in l as List) (v as num).toDouble()];

  /// p(burn), plus why it can't be trusted (empty = inside the training domain).
  ({double p, List<String> outside}) predict({
    required double o2,
    required double kpa,
    required double flow,
    required double g,
  }) {
    final row = {'o2_pct': o2, 'pressure_kpa': kpa, 'flow_cm_s': flow};
    var z = intercept;
    final outside = <String>[];
    for (final (j, f) in features.indexed) {
      final x = row[f] ?? 0;
      final s = (x - mean[j]) / std[j];
      z += coef[j] * s;
      if (s.abs() > 3) {
        outside.add('$f ${x.toStringAsFixed(1)} (${mean[j].toStringAsFixed(1)} ± ${std[j].toStringAsFixed(1)})');
      }
    }
    if (g > trainG + .01) outside.add('${g.toStringAsFixed(3)} g ($trainG g)');
    return (p: 1 / (1 + math.exp(-z)), outside: outside);
  }
}

/// GET /model, or the bundled snapshot offline.
final burnPredictorProvider = FutureProvider<BurnPredictor>(
  (ref) async => BurnPredictor(await getJson('/model', snapshot: 'model.json') as Map),
);
