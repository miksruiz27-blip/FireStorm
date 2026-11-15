import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../app/theme.dart';
import 'api.dart';
import 'habitats.dart';

class ScoreFactor {
  const ScoreFactor(this.label, this.value);
  final String label;
  final double value; // 0..1
}

class Source {
  const Source(this.title, this.description, this.ref);
  final String title, description, ref;
}

class Investigation {
  const Investigation({
    required this.id,
    required this.title,
    required this.fuel,
    required this.domains,
    required this.o2Range,
    required this.pressureRange,
    required this.gravity,
    required this.score,
    this.flowRange = '',
    this.materials = const [],
    this.platform = '',
    this.hardware = '',
    this.keyFindings = const [],
    this.modifications = const [],
    this.researchGroup = '',
    this.rationale,
    this.factors = const [],
    this.sources = const [],
  });

  /// One experiment from the API contract (scored when fetched with ?habitat=).
  factory Investigation.fromJson(Map<String, Object?> j) {
    String fmt(num v) =>
        v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    String range(String k, [double div = 1]) {
      final [lo, hi] = [for (final v in j[k] as List) fmt((v as num) / div)];
      return lo == hi ? lo : '$lo–$hi';
    }

    final b = (j['score_breakdown'] as Map?)?.cast<String, num>();
    List<String> strings(String k) => [
      for (final s in (j[k] as List?)?.cast<String>() ?? const <String>[])
        trd(s),
    ];
    final findings = strings('key_findings');
    final o2 = range('o2_range'), psi = range('pressure_kpa_range', 6.89476);
    final g = j['gravity'] == 'micro' ? 'μg' : j['gravity'] as String;
    // Built from the linked records only: test envelope, strongest score factor, first finding.
    String? rationale;
    if (b != null) {
      final top = {
        tr(
          'its test conditions overlap this atmosphere',
          'sus condiciones de ensayo se solapan con esta atmósfera',
        ): b['conditions']!,
        tr(
          'it covers several safety domains',
          'cubre varios dominios de seguridad',
        ): b['safety']!,
        tr('it has dense test data', 'tiene datos de ensayo densos'):
            b['data']!,
      }.entries.reduce((x, y) => y.value > x.value ? y : x).key;
      rationale = tr(
        'Tested at $o2 % O₂, $psi psi, $g. Ranked here mainly because $top.'
            '${findings.isEmpty ? '' : ' Finding: ${findings.first}'}',
        'Ensayado a $o2 % O₂, $psi psi, $g. Está aquí sobre todo porque $top.'
            '${findings.isEmpty ? '' : ' Hallazgo: ${findings.first}'}',
      );
    }
    return Investigation(
      id: j['id'] as String,
      title: trd(j['name'] as String),
      fuel: Fuel.values.byName(j['fuel_type'] as String),
      domains: [
        for (final d in (j['domain'] as List).cast<String>().map(trd))
          '${d[0].toUpperCase()}${d.substring(1)}',
      ],
      o2Range: o2,
      pressureRange: psi,
      flowRange: j['flow_cm_s_range'] == null ? '' : range('flow_cm_s_range'),
      materials: strings('materials'),
      gravity: g,
      rationale: rationale,
      score: (((j['score'] as num?) ?? 0) * 100).round(),
      platform: trd(j['platform'] as String? ?? ''),
      hardware: trd(j['hardware'] as String? ?? ''),
      keyFindings: findings,
      modifications: strings('modifications'),
      researchGroup: trd(j['research_group'] as String? ?? ''),
      factors: b == null
          ? const []
          : [
              ScoreFactor(
                tr('Condition overlap', 'Solape de condiciones'),
                b['conditions']!.toDouble(),
              ),
              ScoreFactor(
                tr('Safety domains', 'Dominios de seguridad'),
                b['safety']!.toDouble(),
              ),
              ScoreFactor(
                tr('Data density', 'Densidad de datos'),
                b['data']!.toDouble(),
              ),
            ],
      sources: [
        for (final s in (j['sources'] as List).cast<Map>())
          Source(
            trd(s['title'] as String),
            s['url'] as String? ?? '',
            (s['ntrs_id'] as String?)?.isNotEmpty == true
                ? 'NTRS ${s['ntrs_id']}'
                : '[PSI ID]',
          ),
      ],
    );
  }

  final String id, title, platform, hardware, researchGroup;
  final Fuel fuel;

  /// Required design modifications from the team catalog.
  final List<String> domains, keyFindings, materials, modifications;
  final String o2Range,
      pressureRange,
      flowRange,
      gravity; // display strings: %, psi, cm/s, μg
  final int score; // 0..100 relevance to the selected habitat
  // Grounded rationale comes from the copilot over linked PSI records; null until generated.
  final String? rationale;
  final List<ScoreFactor> factors;
  final List<Source> sources;

  String get code => id.toUpperCase();
  String get domain => domains.first;
  int get docs => sources.length; // PSI records linked (copilot scope)

  String get fuelLabel => switch (fuel) {
    Fuel.solid => tr('Solid', 'Sólido'),
    Fuel.liquid => tr('Liquid', 'Líquido'),
    Fuel.gas => tr('Gas', 'Gas'),
  };
}

/// Experiments ranked for the selected habitat: API, or the bundled snapshot after 3 s.
final experimentsProvider = FutureProvider<List<Investigation>>((ref) async {
  final h = ref.watch(selectedHabitatProvider);
  ref.watch(langProvider); // text is translated when parsed
  final j = await getJson(
    '/experiments?habitat=${h.id}',
    snapshot: 'experiments.json',
    key: h.id,
  );
  return [
    for (final e in (j as List).cast<Map>()) Investigation.fromJson(e.cast()),
  ];
});
