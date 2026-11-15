import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/i18n.dart';
import '../app/page.dart';
import '../app/theme.dart';
import '../data/api.dart';

/// The team's catalog (experiments, PSI repositories, findings, incidents, PSI-166): API or snapshot.
final catalogProvider = FutureProvider<List<Map<String, Object?>>>((ref) async {
  ref.watch(langProvider); // values are translated when parsed
  final j = await getJson('/catalog', snapshot: 'catalog.json') as List;
  return [
    for (final e in j.cast<Map>())
      {
        for (final MapEntry(:key, :value) in e.cast<String, Object?>().entries)
          key: key == 'tipo' || value is! String ? value : trd(value),
      },
  ];
});

/// Step 06 · Models: the team's two classifiers (live API) and the full catalog.
class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) => PageBody(
    gap: 28,
    children: [
      PageIntro(
        step: tr('STEP 06 · MODELS', 'PASO 06 · MODELOS'),
        title: tr('TEAM LAB', 'LABORATORIO DEL EQUIPO'),
        description: TextSpan(
          text: tr(
            'The team\'s ONNX classifiers and catalog. Describe an experiment or hazard to get its '
                'research group and the design modifications it requires, or classify PSI-166 melt-flow '
                'telemetry. Classifiers need the live API.',
            'Los clasificadores ONNX y el catálogo del equipo. Describe un experimento o riesgo para '
                'obtener su grupo de investigación y las modificaciones de diseño que requiere, o clasifica '
                'la telemetría de flujo de fusión PSI-166. Los clasificadores necesitan la API en vivo.',
          ),
        ),
      ),
      const _ExperimentClassifier(),
      const _FlowClassifier(),
      const _Catalog(),
    ],
  );
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.children);
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ChamferCard(
    padding: const EdgeInsets.all(26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(label, style: AppText.label),
        ...children,
      ],
    ),
  );
}

TextStyle get _soft => AppText.body.copyWith(color: AppColors.textSoft);
String _pct(Object? p) => '${((p as num) * 100).toStringAsFixed(1)} %';
String _human(String s) => s.replaceAll('_', ' ');

Widget _error(Object e) => Text(
  '${tr('Unavailable', 'No disponible')}: ${e.toString().replaceFirst('Exception: ', '')}',
  style: AppText.caption.copyWith(color: AppColors.red),
);

Widget _bullets(List<String> items) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 10,
  children: [
    for (final m in items)
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox.square(
              dimension: 6,
              child: ColoredBox(color: AppColors.red),
            ),
          ),
          Expanded(child: Text(trd(m), style: _soft)),
        ],
      ),
  ],
);

class _ExperimentClassifier extends StatefulWidget {
  const _ExperimentClassifier();

  @override
  State<_ExperimentClassifier> createState() => _ExperimentClassifierState();
}

class _ExperimentClassifierState extends State<_ExperimentClassifier> {
  final _text = TextEditingController(
    text: tr(
      'Flame over cotton fabric with slow ventilation in microgravity',
      'Llama sobre tela de algodón con ventilación lenta en microgravedad',
    ),
  );
  Future<Map<String, Object?>>? _result;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _run() => setState(
    () => _result = postJson('/classify/experiment', {'text': _text.text}),
  );

  @override
  Widget build(BuildContext context) => _Card(
    tr(
      'EXPERIMENT & MODIFICATION CLASSIFIER',
      'CLASIFICADOR DE EXPERIMENTOS Y MODIFICACIONES',
    ),
    [
      TextField(
        controller: _text,
        minLines: 2,
        maxLines: 4,
        style: AppText.body,
        decoration: InputDecoration(
          hintText: tr(
            'Material, conditions, hazard… (Spanish or English)',
            'Material, condiciones, riesgo… (español o inglés)',
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: _run,
          child: Text(tr('CLASSIFY', 'CLASIFICAR')),
        ),
      ),
      if (_result != null)
        FutureBuilder(
          future: _result,
          builder: (context, s) {
            if (s.hasError) return _error(s.error!);
            final r = s.data;
            if (r == null) return const LinearProgressIndicator();
            final ranked = (r['ranked'] as List).cast<Map>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, c) in ranked.indexed)
                      AppTag(
                        '${_human(trd(c['class'] as String))} · ${_pct(c['p'])}',
                        mono: true,
                        level: i == 0 ? TagLevel.high : TagLevel.neutral,
                      ),
                  ],
                ),
                if ((r['category'] as String?)?.isNotEmpty == true)
                  Text(trd(r['category'] as String), style: AppText.caption),
                Text(
                  tr('REQUIRED MODIFICATIONS', 'MODIFICACIONES REQUERIDAS'),
                  style: AppText.label,
                ),
                _bullets((r['modifications'] as List).cast<String>()),
              ],
            );
          },
        ),
    ],
  );
}

/// PSI-166 inputs in physical units, prefilled with dataset record PSI166-0002.
List<(String, String, double)> get _flowFields => [
  ('temperature_k', tr('Temperature (K)', 'Temperatura (K)'), 955.0),
  ('diameter_mm', tr('Diameter (mm)', 'Diámetro (mm)'), 6.5),
  (
    'max_velocity_m_s',
    tr('Max velocity (m/s)', 'Velocidad máx. (m/s)'),
    0.0002407,
  ),
  (
    'max_shear_rate_s',
    tr('Max shear rate (1/s)', 'Tasa de corte máx. (1/s)'),
    0.5469,
  ),
  ('reynolds_number', tr('Reynolds number', 'Número de Reynolds'), 0.0098),
  (
    'mhd_max_force_n_m3',
    tr('Max MHD force (N/m³)', 'Fuerza MHD máx. (N/m³)'),
    10432.19,
  ),
];

class _FlowClassifier extends StatefulWidget {
  const _FlowClassifier();

  @override
  State<_FlowClassifier> createState() => _FlowClassifierState();
}

class _FlowClassifierState extends State<_FlowClassifier> {
  final _c = {
    for (final (k, _, v) in _flowFields) k: TextEditingController(text: '$v'),
  };
  Future<Map<String, Object?>>? _result;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _run() {
    final body = {
      for (final MapEntry(:key, :value) in _c.entries)
        key: double.tryParse(value.text.trim()),
    };
    setState(
      () => _result = body.values.any((v) => v == null || v <= 0)
          ? Future.error(
              Exception(
                tr(
                  'every value must be a positive number',
                  'cada valor debe ser un número positivo',
                ),
              ),
            )
          : postJson('/classify/psi166', body),
    );
  }

  @override
  Widget build(BuildContext context) => _Card(
    tr(
      'PSI-166 MELT-FLOW CLASSIFIER',
      'CLASIFICADOR DE FLUJO DE FUSIÓN PSI-166',
    ),
    [
      Text(
        tr(
          'ISS-EML levitated melt: predicts the flow regime and the correction the analysis needs.',
          'Fusión levitada ISS-EML: predice el régimen de flujo y la corrección que necesita el análisis.',
        ),
        style: AppText.caption,
      ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (k, label, _) in _flowFields)
            SizedBox(
              width: 200,
              child: TextField(
                controller: _c[k],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppText.data,
                decoration: InputDecoration(labelText: label),
              ),
            ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: _run,
          child: Text(tr('CLASSIFY FLOW', 'CLASIFICAR FLUJO')),
        ),
      ),
      if (_result != null)
        FutureBuilder(
          future: _result,
          builder: (context, s) {
            if (s.hasError) return _error(s.error!);
            final r = s.data;
            if (r == null) return const LinearProgressIndicator();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppTag(
                      '${_human(trd(r['class'] as String))} · ${_pct(r['p'])}',
                      mono: true,
                      level: TagLevel.high,
                    ),
                    AppTag(
                      '${tr('model', 'modelo')} ${r['model']}',
                      mono: true,
                    ),
                  ],
                ),
                if ((r['modification'] as String?)?.isNotEmpty == true)
                  _bullets([r['modification'] as String]),
              ],
            );
          },
        ),
    ],
  );
}

Map<String, String> get _types => {
  'experimento': tr('Experiments', 'Experimentos'),
  'repositorio_psi': tr('PSI repositories', 'Repositorios PSI'),
  'hallazgo': tr('Findings', 'Hallazgos'),
  'incidente': tr('Incidents', 'Incidentes'),
  'investigacion_psi166': 'PSI-166',
};

class _Catalog extends ConsumerStatefulWidget {
  const _Catalog();

  @override
  ConsumerState<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<_Catalog> {
  String _type = 'experimento';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(catalogProvider);
    return _Card(tr('TEAM CATALOG', 'CATÁLOGO DEL EQUIPO'), [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(:key, :value) in _types.entries)
            ToggleChip(
              '$value (${all.value?.where((e) => e['tipo'] == key).length ?? 0})',
              selected: _type == key,
              onTap: () => setState(() => _type = key),
            ),
        ],
      ),
      ...switch (all) {
        AsyncData(:final value) => [
          for (final e in value.where((e) => e['tipo'] == _type))
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              // Own Material: the card's colored box would hide the tile's ink.
              child: Material(
                type: MaterialType.transparency,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  iconColor: AppColors.text,
                  collapsedIconColor: AppColors.secondary,
                  title: Text(
                    '${e['codigo_corto']}',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e['id']} · ${e['experimento_investigacion']}',
                    style: AppText.caption,
                  ),
                  children: [
                    for (final (k, label) in [
                      ('instalacion_hardware', 'Hardware'),
                      (
                        'investigador_responsable',
                        tr('Investigators', 'Investigadores'),
                      ),
                      ('fecha_periodo', tr('Period', 'Periodo')),
                      (
                        'material_combustible',
                        tr('Fuel / material', 'Combustible / material'),
                      ),
                      ('condiciones', tr('Conditions', 'Condiciones')),
                      ('descripcion_objetivo', tr('Objective', 'Objetivo')),
                      ('consecuencia_hallazgo', tr('Finding', 'Hallazgo')),
                      (
                        'modificaciones_necesarias',
                        tr(
                          'Required modifications',
                          'Modificaciones requeridas',
                        ),
                      ),
                      ('fuente', tr('Source', 'Fuente')),
                      ('referencia', tr('Reference', 'Referencia')),
                    ])
                      if ((e[k] as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(label.toUpperCase(), style: AppText.label),
                              SelectableText(e[k] as String, style: _soft),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
        AsyncError(:final error) => [_error(error)],
        _ => [const LinearProgressIndicator()],
      },
    ]);
  }
}
