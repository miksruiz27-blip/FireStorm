import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';

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
    required this.o2Label,
    required this.pressure,
    required this.pressureLabel,
    required this.gravityLabel,
    required this.band,
    required this.risk,
  });

  final String id; // API habitat id
  final String code, zone, name, blurb;
  final double o2; // % O₂, positions the envelope tick
  final String o2Label;
  final double pressure; // psi
  final String pressureLabel, gravityLabel;
  final GravityBand band;
  final TagLevel risk;

  String get riskLabel => switch (risk) {
    TagLevel.neutral => 'NOMINAL',
    TagLevel.high => 'HIGH',
    TagLevel.critical => 'CRITICAL',
  };
}

// Atmospheres: design values, verify before mission use.
const habitats = [
  Habitat(
    id: 'iss',
    code: '01',
    zone: 'LEO · ORBITAL',
    name: 'ISS',
    blurb: 'Sea-level air, continuous crew',
    o2: 21,
    o2Label: '21',
    pressure: 14.7,
    pressureLabel: '14.7',
    gravityLabel: 'μg',
    band: GravityBand.micro,
    risk: TagLevel.neutral,
  ),
  Habitat(
    id: 'lunar',
    code: '02',
    zone: 'SURFACE · MOON',
    name: 'Lunar Base',
    blurb: 'Enriched O₂ at reduced pressure',
    o2: 30,
    o2Label: '≥30',
    pressure: 10.2,
    pressureLabel: '≤10.2',
    gravityLabel: '0.166',
    band: GravityBand.lunar,
    risk: TagLevel.high,
  ),
  Habitat(
    id: 'rover',
    code: '03',
    zone: 'SURFACE · MOBILE',
    name: 'Pressurized Rover',
    blurb: 'Exploration atmosphere, small volume',
    o2: 34,
    o2Label: '34',
    pressure: 8.2,
    pressureLabel: '8.2',
    gravityLabel: '0.166',
    band: GravityBand.lunar,
    risk: TagLevel.high,
  ),
  Habitat(
    id: 'eva',
    code: '04',
    zone: 'EVA',
    name: 'Spacesuit',
    blurb: 'Pure oxygen, lowest pressure',
    o2: 100,
    o2Label: '100',
    pressure: 4.3,
    pressureLabel: '4.3',
    gravityLabel: 'μg–0.17',
    band: GravityBand.lunar,
    risk: TagLevel.critical,
  ),
];

class SelectedHabitat extends Notifier<Habitat> {
  @override
  Habitat build() => habitats[1];
  void select(Habitat h) => state = h;
}

/// The chosen habitat; every screen recalculates from this.
final selectedHabitatProvider = NotifierProvider<SelectedHabitat, Habitat>(
  SelectedHabitat.new,
);
