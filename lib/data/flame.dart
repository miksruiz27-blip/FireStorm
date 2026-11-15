import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import 'api.dart';

/// Physics-informed flame model: port of backend/src/flame.js (same params, parity-tested).
/// LOI = MOC + q·ln²(u_eff/u*) + kP·ln(101.3/P); u_eff = √(flow² + (U1g·g^⅓)²); p = σ(margin/s).
class FlameModel {
  FlameModel(Map j)
    : uBuoy1g = _d(j['u_buoy_1g']),
      uMin = _d(j['u_min']),
      uStar = _d(j['u_star']),
      q = _d(j['q']),
      kP = _d(j['k_p']),
      s = _d(j['s']),
      b = _d(j['b']),
      defaultMaterial = j['default_material'] as String,
      materials = {
        for (final e in (j['materials'] as Map).entries)
          e.key as String: (
            name: (e.value['name'] ?? e.key) as String,
            moc: _d(e.value['moc_1g']),
            c: _d(e.value['c']),
          ),
      },
      aliases = {
        for (final e in ((j['aliases'] as Map?) ?? const {}).entries)
          e.key as String: RegExp(e.value as String, caseSensitive: false),
      },
      o2Range = _range(j['fit_range']['o2_pct']),
      kpaRange = _range(j['fit_range']['pressure_kpa']),
      testedG = [for (final g in j['fit_range']['gravity_g'] as List) _d(g)],
      n = (j['metrics']['n'] as num).toInt(),
      accuracy = _d(j['metrics']['accuracy']),
      spreadRmse = _d(j['metrics']['spread_rmse_mm_s']);

  final double uBuoy1g, uMin, uStar, q, kP, s, b, accuracy, spreadRmse;
  final String defaultMaterial;
  final Map<String, ({String name, double moc, double c})> materials;
  final Map<String, RegExp> aliases;
  final (double, double) o2Range, kpaRange;
  final List<double> testedG;
  final int n;

  /// The one model figure every screen shows (F6): same n, same definition.
  String get summary => tr(
    'n = $n test points labelled burn/extinct · accuracy ${(accuracy * 100).round()} %',
    'n = $n puntos de ensayo etiquetados arde/se extingue · precisión ${(accuracy * 100).round()} %',
  );

  static double _d(Object? v) => (v as num).toDouble();
  static (double, double) _range(Object? v) => (_d((v as List)[0]), _d(v[1]));

  /// Modelled material for a specimen name (backend matchMaterial): exact key, alias, or prefix; null if none.
  String? match(String name) {
    final n = name.toLowerCase();
    final first = n.split(' ').first;
    for (final k in materials.keys) {
      if (k == n) return k;
    }
    for (final k in materials.keys) {
      if (aliases[k]?.hasMatch(n) ?? false) return k;
    }
    for (final k in materials.keys) {
      if (n.startsWith(k) || k.startsWith(first)) return k;
    }
    return null;
  }

  double _ln2(double u) =>
      math.pow(math.log(math.max(uMin, u) / uStar), 2) as double;

  FlameForecast predict({
    required double o2,
    required double kpa,
    required double g,
    double flow = 0,
    String? material,
  }) {
    final key = materials.containsKey(material) ? material! : defaultMaterial;
    final m = materials[key]!;
    final uBuoy = uBuoy1g * math.pow(math.max(0, g), 1 / 3);
    final uEff = math.max(uMin, math.sqrt(flow * flow + uBuoy * uBuoy));
    final loi =
        m.moc + q * (_ln2(uEff) - _ln2(uBuoy1g)) + kP * math.log(101.3 / kpa);
    final margin = o2 - loi;
    return FlameForecast(
      material: key,
      name: m.name,
      pBurn: 1 / (1 + math.exp(-margin / s)),
      loi: loi,
      margin: margin,
      spread: margin > 0 ? m.c * margin * math.pow(uEff / 10, b) : 0,
      uBuoy: uBuoy.toDouble(),
      uEff: uEff,
      oxygenStarved: uEff < uStar,
      extrapolated: [
        if (o2 < o2Range.$1 - 2 || o2 > o2Range.$2 + 2)
          'O₂ ${_f(o2)} % ($_tested ${_f(o2Range.$1)}–${_f(o2Range.$2)})',
        if (kpa < kpaRange.$1 - 5 || kpa > kpaRange.$2 + 5)
          '${_f(kpa)} kPa ($_tested ${_f(kpaRange.$1)}–${_f(kpaRange.$2)})',
        if (!testedG.any((t) => (t - g).abs() < .05))
          '${_f(g, 3)} g ($_tested ${testedG.map(_f).join(', ')} g)',
      ],
    );
  }
}

String get _tested => tr('tested', 'ensayado');

String _f(num v, [int d = 1]) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(d);

enum FlameRegime {
  extinguishes('SELF-EXTINGUISHES', 'SE AUTOEXTINGUE'),
  marginal('MARGINAL', 'MARGINAL'),
  sustained('SUSTAINED', 'SOSTENIDA'),
  vigorous('VIGOROUS', 'VIGOROSA');

  const FlameRegime(this._en, this._es);
  final String _en, _es;
  String get label => tr(_en, _es);
}

class FlameForecast {
  const FlameForecast({
    required this.material,
    required this.name,
    required this.pBurn,
    required this.loi,
    required this.margin,
    required this.spread,
    required this.uBuoy,
    required this.uEff,
    required this.oxygenStarved,
    required this.extrapolated,
  });
  final String material, name;
  final double pBurn, loi, margin, spread, uBuoy, uEff;
  final bool oxygenStarved;
  final List<String> extrapolated;

  FlameRegime get regime => margin < -1
      ? FlameRegime.extinguishes
      : margin < 1
      ? FlameRegime.marginal
      : margin < 5
      ? FlameRegime.sustained
      : FlameRegime.vigorous;
}

/// Cabin ventilation the habitat forecast assumes (backend CABIN_FLOW).
const cabinFlow = 10.0;

final flameModelProvider = FutureProvider<FlameModel>(
  (ref) async =>
      FlameModel(await getJson('/flame/model', snapshot: 'flame.json') as Map),
);

/// Measured spread rates (test points with a rate), for overlaying on the predicted curve.
typedef SpreadPoint = ({String material, double o2, double spread, double g});

final spreadPointsProvider = FutureProvider<List<SpreadPoint>>((ref) async {
  final points = await getJson(
    '/gapmap?habitat=iss',
    snapshot: 'test_points.json',
  ) as List;
  return [
    for (final t in points.cast<Map>())
      if (t['spread_rate_mm_s'] case final num s)
        (
          material: (t['material'] as String).toLowerCase(),
          o2: (t['o2_pct'] as num).toDouble(),
          spread: s.toDouble(),
          g: (t['gravity_g'] as num).toDouble(),
        ),
  ];
});
