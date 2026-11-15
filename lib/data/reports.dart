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
  sheet('Flat sheet'),
  rod('Rod'),
  sphere('Sphere');

  const Geometry(this.label);
  final String label;
}

const reports = {
  'BASS-II': Report(
    platform: 'ISS · Microgravity Science Glovebox',
    domains: ['Prevention', 'Suppression'],
    objective:
        'Examine how flow speed, oxygen level and sample geometry affect ignition, flame spread '
        'and extinguishment of solid materials in microgravity — and how well a suppressant puts '
        'those flames out.',
    // Sample values · bind to PSI dataset [ID]
    series: [
      (label: '20 cm/s', points: [(16, 1.1), (18, 2.4), (21, 4.1)]),
      (label: '10 cm/s', points: [(16, .9), (18, 2.0), (21, 3.5)]),
      (label: '5 cm/s', points: [(16, .6), (18, 1.4), (21, 2.6)]),
    ],
    extrapolateTo: (34, 8),
    findings: [
      'In microgravity, flame spread over solids depends strongly on slow ventilation flow — '
          'remove the flow and many flames weaken or go out.',
      'Some materials kept burning at oxygen levels below what normal-gravity screening '
          'predicts: ground tests are not always conservative.',
      'BASS-II stops near sea-level oxygen. The enriched lunar atmosphere (8.2 psia / 34 % O₂) '
          'is covered by the SAFFIRE and SoFIE exploration-atmosphere series, not by this one.',
    ],
    hardware: 'Microgravity Science Glovebox',
    hardwareNote:
        'Sealed work volume aboard ISS with a small flow duct, hot-wire igniter and suppressant '
        'nozzle.',
    geometries: Geometry.values,
    sensors: [
      ('Color video', 'IMG'),
      ('Thermocouples', '°C'),
      ('Radiometer', 'W/m²'),
      ('Flow sensor', 'cm/s'),
      ('Oxygen sensor', '% O₂'),
    ],
  ),
};
