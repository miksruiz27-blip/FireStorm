import '../app/i18n.dart';

/// Investigation report (telemetry sheet). Content comes from the mockup; bind to PSI metadata.
class Report {
  const Report({
    required this.platform,
    required this.domains,
    required this.objective,
    required this.series,
    required this.extrapolateTo,
    required this.findings,
    required this.hardware,
    required this.hardwareNote,
    required this.geometries,
    required this.sensors,
  });

  final String platform, objective, hardware, hardwareNote;
  final List<String> domains, findings;

  /// Flame spread (mm/s) vs O₂ (%), one series per flow velocity, fastest first.
  final List<({String label, List<(double, double)> points})> series;

  /// End of the dashed extrapolation from the fastest series' last measured point.
  final (double, double) extrapolateTo;
  final List<Geometry> geometries;
  final List<(String, String)> sensors;
}

enum Geometry {
  sheet('Flat sheet', 'Lámina plana'),
  rod('Rod', 'Varilla'),
  sphere('Sphere', 'Esfera');

  const Geometry(this._en, this._es);
  final String _en, _es;
  String get label => tr(_en, _es);
}

Map<String, Report> get reports => {
  'BASS-II': Report(
    platform: 'ISS · Microgravity Science Glovebox',
    domains: [tr('Prevention', 'Prevención'), tr('Suppression', 'Supresión')],
    objective: tr(
      'Examine how flow speed, oxygen level and sample geometry affect ignition, flame spread '
          'and extinguishment of solid materials in microgravity — and how well a suppressant puts '
          'those flames out.',
      'Examinar cómo la velocidad del flujo, el nivel de oxígeno y la geometría de la muestra afectan '
          'la ignición, la propagación de la llama y la extinción de materiales sólidos en microgravedad, '
          'y qué tan bien un supresor apaga esas llamas.',
    ),
    // Sample values · bind to PSI dataset [ID]
    series: [
      (label: '20 cm/s', points: [(16, 1.1), (18, 2.4), (21, 4.1)]),
      (label: '10 cm/s', points: [(16, .9), (18, 2.0), (21, 3.5)]),
      (label: '5 cm/s', points: [(16, .6), (18, 1.4), (21, 2.6)]),
    ],
    extrapolateTo: (34, 8),
    findings: [
      tr(
        'In microgravity, flame spread over solids depends strongly on slow ventilation flow — '
            'remove the flow and many flames weaken or go out.',
        'En microgravedad, la propagación de llama sobre sólidos depende mucho del flujo lento de '
            'ventilación: si se quita el flujo, muchas llamas se debilitan o se apagan.',
      ),
      tr(
        'Some materials kept burning at oxygen levels below what normal-gravity screening '
            'predicts: ground tests are not always conservative.',
        'Algunos materiales siguieron ardiendo con niveles de oxígeno inferiores a lo que predicen '
            'los ensayos en gravedad normal: las pruebas en tierra no siempre son conservadoras.',
      ),
      tr(
        'BASS-II stops near sea-level oxygen. The enriched lunar atmosphere (8.2 psia / 34 % O₂) '
            'is covered by the SAFFIRE and SoFIE exploration-atmosphere series, not by this one.',
        'BASS-II llega solo hasta el oxígeno a nivel del mar. La atmósfera lunar enriquecida '
            '(8.2 psia / 34 % O₂) la cubren las series de atmósfera de exploración SAFFIRE y SoFIE, no esta.',
      ),
    ],
    hardware: 'Microgravity Science Glovebox',
    hardwareNote: tr(
      'Sealed work volume aboard ISS with a small flow duct, hot-wire igniter and suppressant '
          'nozzle.',
      'Volumen de trabajo sellado a bordo de la ISS con un pequeño conducto de flujo, ignitor de hilo '
          'caliente y boquilla de supresor.',
    ),
    geometries: Geometry.values,
    sensors: [
      (tr('Color video', 'Video a color'), 'IMG'),
      (tr('Thermocouples', 'Termopares'), '°C'),
      (tr('Radiometer', 'Radiómetro'), 'W/m²'),
      (tr('Flow sensor', 'Sensor de flujo'), 'cm/s'),
      (tr('Oxygen sensor', 'Sensor de oxígeno'), '% O₂'),
    ],
  ),
};
