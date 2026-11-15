import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../app/theme.dart';
import 'api.dart';

/// Gravity rows of the data gap map, top to bottom.
enum GravityBand {
  earth('Earth', 'Tierra', '1 g', '1 g', 1, 'at 1 g', 'a 1 g'),
  mars(
    'Mars',
    'Marte',
    '0.38 g',
    '0.38 g',
    .38,
    'at Martian gravity',
    'a gravedad marciana',
  ),
  lunar(
    'Lunar',
    'Lunar',
    '0.166 g',
    '0.166 g',
    .166,
    'at lunar gravity',
    'a gravedad lunar',
  ),
  micro(
    'Micro',
    'Micro',
    '~10⁻⁶ g',
    'μg',
    1e-6,
    'in microgravity',
    'en microgravedad',
  );

  const GravityBand(
    this._en,
    this._es,
    this.axis,
    this.short,
    this.g,
    this._phraseEn,
    this._phraseEs,
  );
  final String _en, _es, axis, short, _phraseEn, _phraseEs;
  final double g;
  String get label => tr(_en, _es);
  String get phrase => tr(_phraseEn, _phraseEs);
}

class Habitat {
  const Habitat({
    required this.id,
    required this.code,
    required this._zone,
    required this._name,
    required this._blurb,
    required this.o2,
    required this.pressure,
    required this.g,
    required this.risk,
    required this.source,
    this.gravityText,
  });

  final String id; // API habitat id
  final String code, source, _name;
  final (String, String) _zone, _blurb; // (English, Spanish)
  String get zone => tr(_zone.$1, _zone.$2);
  String get blurb => tr(_blurb.$1, _blurb.$2);
  String get name => switch (_name) {
    'Lunar Base' => tr(_name, 'Base Lunar'),
    'Pressurized Rover' => tr(_name, 'Rover Presurizado'),
    'Spacesuit' => tr(_name, 'Traje espacial'),
    _ => _name,
  };
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
    TagLevel.high => tr('HIGH', 'ALTO'),
    TagLevel.critical => tr('CRITICAL', 'CRÍTICO'),
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
    zone: ('LEO · ORBITAL', 'LEO · ORBITAL'),
    blurb: (
      'Sea-level air, continuous crew',
      'Aire a nivel del mar, tripulación continua',
    ),
    risk: TagLevel.neutral,
    gravityText: null,
  ),
  'lunar': (
    code: '02',
    zone: ('SURFACE · MOON', 'SUPERFICIE · LUNA'),
    blurb: (
      'Exploration atmosphere, enriched O₂',
      'Atmósfera de exploración, O₂ enriquecido',
    ),
    risk: TagLevel.high,
    gravityText: null,
  ),
  'rover': (
    code: '03',
    zone: ('SURFACE · MOBILE', 'SUPERFICIE · MÓVIL'),
    blurb: (
      'Exploration atmosphere, small volume',
      'Atmósfera de exploración, volumen reducido',
    ),
    risk: TagLevel.high,
    gravityText: null,
  ),
  'eva': (
    code: '04',
    zone: ('EVA', 'EVA'),
    blurb: ('Pure oxygen, lowest pressure', 'Oxígeno puro, presión mínima'),
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
