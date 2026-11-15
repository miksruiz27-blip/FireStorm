import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import 'api.dart';

/// Gravity rows of the data gap map, top to bottom.
enum GravityBand {
  earth('Earth', '1 g', '1 g', 1, 'at 1 g'),
  mars('Mars', '0.38 g', '0.38 g', .38, 'at Martian gravity'),
  lunar('Lunar', '0.166 g', '0.166 g', .166, 'at lunar gravity'),
  micro('Micro', '~10⁻⁶ g', 'μg', 1e-6, 'in microgravity');

  const GravityBand(this.label, this.axis, this.short, this.g, this.phrase);
  final String label, axis, short, phrase;
  final double g;
}

class Habitat {
  const Habitat({
    required this.id,
    required this.code,
    required this.zone,
    required this.name,
    required this.blurb,
    required this.o2,
    required this.pressure,
    required this.g,
    required this.risk,
    required this.source,
    this.gravityText,
  });

  final String id; // API habitat id
  final String code, zone, name, blurb, source;
  final double o2; // % O₂
  final double pressure; // psia
  final double g;
  final String? gravityText; // presentation override (spacesuit spans μg–lunar)
  final TagLevel risk;

  static String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : '$v';
  String get o2Label => _num(o2);
  String get pressureLabel => _num(pressure);
  String get gravityLabel => gravityText ?? (g < 0.05 ? 'μg' : _num(g));
  GravityBand get band => bandFor(g);

  String get riskLabel => switch (risk) {
    TagLevel.neutral => 'NOMINAL',
    TagLevel.high => 'HIGH',
    TagLevel.critical => 'CRITICAL',
  };
}

GravityBand bandFor(double g) => g < 0.05
    ? GravityBand.micro
    : g < 0.25
    ? GravityBand.lunar
    : g < 0.6
    ? GravityBand.mars
    : GravityBand.earth;

/// Presentation only. Atmospheres (O₂, pressure, gravity, source) come from GET /habitats,
/// the single source of truth; the bundled snapshot answers offline.
const _presentation = {
  'iss': (
    code: '01',
    zone: 'LEO · ORBITAL',
    blurb: 'Sea-level air, continuous crew',
    risk: TagLevel.neutral,
    gravityText: null,
  ),
  'lunar': (
    code: '02',
    zone: 'SURFACE · MOON',
    blurb: 'Exploration atmosphere, enriched O₂',
    risk: TagLevel.high,
    gravityText: null,
  ),
  'rover': (
    code: '03',
    zone: 'SURFACE · MOBILE',
    blurb: 'Exploration atmosphere, small volume',
    risk: TagLevel.high,
    gravityText: null,
  ),
  'eva': (
    code: '04',
    zone: 'EVA',
    blurb: 'Pure oxygen, lowest pressure',
    risk: TagLevel.critical,
    gravityText: 'μg–0.17',
  ),
};

/// Filled by [loadHabitats] before the app starts.
List<Habitat> habitats = const [];

Future<void> loadHabitats() async {
  final rows = (await getJson('/habitats', snapshot: 'habitats.json') as List)
      .cast<Map>();
  final byId = {for (final r in rows) r['id'] as String: r};
  habitats = [
    for (final MapEntry(key: id, value: p) in _presentation.entries)
      if (byId[id] case final r?)
        Habitat(
          id: id,
          code: p.code,
          zone: p.zone,
          name: r['name'] as String,
          blurb: p.blurb,
          o2: (r['o2_pct'] as num).toDouble(),
          pressure: (r['pressure_psia'] as num).toDouble(),
          g: (r['gravity_g'] as num).toDouble(),
          risk: p.risk,
          source: r['source'] as String,
          gravityText: p.gravityText,
        ),
  ];
}

class SelectedHabitat extends Notifier<Habitat> {
  @override
  Habitat build() =>
      habitats.firstWhere((h) => h.id == 'lunar', orElse: () => habitats.first);
  void select(Habitat h) => state = h;
}

/// The chosen habitat; every screen recalculates from this.
final selectedHabitatProvider = NotifierProvider<SelectedHabitat, Habitat>(
  SelectedHabitat.new,
);
