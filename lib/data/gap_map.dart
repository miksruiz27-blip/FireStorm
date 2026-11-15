import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../app/theme.dart';
import 'api.dart';
import 'habitats.dart';
import 'investigations.dart';

/// One tested condition from a PSI investigation (or ground/partial-g campaign).
class TestMark {
  const TestMark(
    this.series,
    this.o2,
    this.band,
    this.fuel, {
    this.partialG = false,
    this.callout = false,
  });
  final String series;
  final double o2; // % by volume
  final GravityBand band;
  final Fuel fuel;
  final bool partialG; // sparse partial-gravity flight data (dashed mark)
  final bool callout; // label it on the map
}

/// Region with no tests. Values above 45 % O₂ fall in the pure-oxygen column.
class GapZone {
  const GapZone(this.from, this.to, this.o2From, this.o2To, [this.label = '']);
  final GravityBand from, to;
  final double o2From, o2To;
  final String label;
}

String fmtO2(double o2) =>
    o2 % 1 == 0 ? o2.toStringAsFixed(0) : o2.toStringAsFixed(1);

/// Test points from /gapmap (snapshot after 3 s), one mark per series × O₂ × gravity.
/// Fuel comes from the experiment the point belongs to.
final testMarksProvider = FutureProvider<List<TestMark>>((ref) async {
  final h = ref.watch(selectedHabitatProvider);
  final fuel = {
    for (final e in await ref.watch(experimentsProvider.future)) e.id: e.fuel,
  };
  final points = await getJson(
    '/gapmap?habitat=${h.id}',
    snapshot: 'test_points.json',
  ) as List;
  final seen = <String>{};
  final marks = [
    for (final t in points.cast<Map>())
      if (fuel[t['experiment_id']] case final f?)
        if (seen.add('${t['experiment_id']}|${t['o2_pct']}|${t['gravity_g']}'))
          TestMark(
            (t['experiment_id'] as String).toUpperCase(),
            (t['o2_pct'] as num).toDouble(),
            bandFor((t['gravity_g'] as num).toDouble()),
            f,
            partialG: {
              GravityBand.lunar,
              GravityBand.mars,
            }.contains(bandFor((t['gravity_g'] as num).toDouble())),
          ),
  ];
  if (marks.isEmpty) return marks;
  // Label the richest-O₂ test on the map.
  final top = marks.reduce((a, b) => b.o2 > a.o2 ? b : a);
  return [
    for (final m in marks)
      identical(m, top)
          ? TestMark(
              m.series,
              m.o2,
              m.band,
              m.fuel,
              partialG: m.partialG,
              callout: true,
            )
          : m,
  ];
});

/// Left edge of the gap map's O₂ axis: the lowest-O₂ tests (SoFIE, LUCI) sit at 12–14 %.
const gapMapO2Min = 10.0;

/// Hatched "no data" regions, derived from the marks: per gravity band, O₂ runs (10–45 %)
/// with no test series within ±[gapWindow], plus the pure-O₂ slot when nothing was burned above 45 %.
List<GapZone> gapZonesFor(List<TestMark> marks) => [
  for (final b in GravityBand.values) ...[
    ..._emptyRuns(marks, b).map(
      (r) => GapZone(
        b,
        b,
        r.$1,
        r.$2,
        b == GravityBand.mars && r.$1 <= gapMapO2Min && r.$2 >= 45
            ? tr('NO DATA · MARTIAN GRAVITY', 'SIN DATOS · GRAVEDAD MARCIANA')
            : tr('NO DATA', 'SIN DATOS'),
      ),
    ),
    if (!marks.any((m) => m.band == b && m.o2 > 45)) GapZone(b, b, 46, 100, ''),
  ],
];

Iterable<(double, double)> _emptyRuns(
  List<TestMark> marks,
  GravityBand b,
) sync* {
  double? start;
  for (var o2 = gapMapO2Min; o2 <= 46; o2++) {
    final empty = o2 <= 45 && seriesAt(marks, o2, b) == 0;
    if (empty) start ??= o2;
    if (!empty && start != null) {
      if (o2 - 1 - start >= 2) yield (start, o2 - 1);
      start = null;
    }
  }
}

/// A cell the backend ranks for the next experiment: data gap × closeness × model uncertainty.
class Recommendation {
  const Recommendation(this.o2, this.band, this.priority, this.why);
  final double o2, priority;
  final GravityBand band;
  final String why;
}

/// The backend's recommendation template (scoring.js `why`) in the current language.
String whyEs(String why) {
  if (!isEs) return why;
  var s = why.replaceFirstMapped(
    RegExp(r'^(\d+) tests? nearby at'),
    (m) => '${m[1]} ensayo(s) cercano(s) a',
  );
  for (final (en, es) in const [
    ('No tests at', 'Sin ensayos a'),
    ('(gap ', '(vacío '),
    ('closeness to ambient', 'cercanía al hábitat'),
    ('physics: ', 'física: '),
    ('self-extinguishes', 'se autoextingue'),
    ('sustained', 'sostenida'),
    ('vigorous', 'vigorosa'),
    ('(limit ', '(límite '),
    (
      'extrapolated — a test here would confirm it.',
      'extrapolado — un ensayo aquí lo confirmaría.',
    ),
    ('uncertainty', 'incertidumbre'),
  ]) {
    s = s.replaceAll(en, es);
  }
  return s;
}

final recommendationsProvider = FutureProvider<List<Recommendation>>((
  ref,
) async {
  final h = ref.watch(selectedHabitatProvider);
  ref.watch(langProvider);
  final j = await getJson(
    '/recommendations?habitat=${h.id}',
    snapshot: 'recommendations.json',
    key: h.id,
  );
  return [
    for (final r in (j as List).cast<Map>())
      Recommendation(
        (r['cell']['o2_pct'] as num).toDouble(),
        bandFor((r['cell']['gravity_g'] as num).toDouble()),
        (r['priority'] as num).toDouble(),
        whyEs(r['why'] as String),
      ),
  ];
});

const gapWindow = 4.0; // ± % O₂ that counts as "at your condition"

/// Distinct test series within ±[gapWindow] % O₂ in [band].
int seriesAt(List<TestMark> marks, double o2, GravityBand band) => {
  for (final m in marks)
    if (m.band == band && (m.o2 - o2).abs() <= gapWindow) m.series,
}.length;

int seriesAtCondition(List<TestMark> marks, Habitat h) =>
    seriesAt(marks, h.o2, h.band);

/// Other gravity bands with tests within ±[gapWindow] % O₂: what an answer would extrapolate from.
List<GravityBand> bandsWithEvidenceAt(
  List<TestMark> marks,
  double o2,
  GravityBand except,
) => [
  for (final b in GravityBand.values)
    if (b != except && seriesAt(marks, o2, b) > 0) b,
];

int marksIn(List<TestMark> marks, GravityBand b) =>
    marks.where((m) => m.band == b).length;

T? _minBy<T>(Iterable<T> xs, double Function(T) key) => xs.isEmpty
    ? null
    : xs.reduce((a, b) => key(b) < key(a) ? b : a); // ties keep list order

String _dO2(TestMark m, Habitat h) {
  final d = (m.o2 - h.o2).round();
  return 'ΔO₂ ${d > 0
      ? '+'
      : d < 0
      ? '−'
      : '±'}${d.abs()}';
}

/// Closest evidence along each axis: same O₂ at another gravity, richer O₂ elsewhere,
/// same gravity at another O₂. Each entry is (mark, delta label).
List<(TestMark, String)> nearestEvidence(List<TestMark> testMarks, Habitat h) {
  final sameO2 = _minBy(
    testMarks.where((m) => m.band != h.band && (m.o2 - h.o2).abs() <= 1),
    (m) => math.log(m.band.g / h.band.g).abs(),
  );
  final richer = _minBy(
    testMarks.where((m) => m.band != h.band && m.o2 > h.o2 + 1),
    (m) => m.o2,
  );
  final sameG = _minBy(
    testMarks.where((m) => m.band == h.band),
    (m) => (m.o2 - h.o2).abs(),
  );
  String dG(TestMark m) {
    final r = math.max(m.band.g, h.band.g) / math.min(m.band.g, h.band.g);
    return r > 100 ? 'Δg μg' : 'Δg ×${r.round()}';
  }

  return [
    if (sameO2 != null) (sameO2, dG(sameO2)),
    if (richer != null) (richer, _dO2(richer, h)),
    if (sameG != null) (sameG, _dO2(sameG, h)),
  ];
}
