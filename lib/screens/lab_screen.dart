import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/page.dart';
import '../app/theme.dart';
import '../data/api.dart';

/// The team's catalog (experiments, PSI repositories, findings, incidents, PSI-166): API or snapshot.
final catalogProvider = FutureProvider<List<Map<String, Object?>>>((ref) async {
  final j = await getJson('/catalog', snapshot: 'catalog.json') as List;
  return [for (final e in j.cast<Map>()) e.cast<String, Object?>()];
});

/// Step 06 · Models: the team's two classifiers (live API) and the full catalog.
class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
    gap: 28,
    children: [
      PageIntro(
        step: 'STEP 06 · MODELS',
        title: 'TEAM LAB',
        description: TextSpan(
          text:
              'The team\'s ONNX classifiers and catalog. Describe an experiment or hazard to get its '
              'research group and the design modifications it requires, or classify PSI-166 melt-flow '
              'telemetry. Classifiers need the live API.',
        ),
      ),
      _ExperimentClassifier(),
      _FlowClassifier(),
      _Catalog(),
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
  'Unavailable: ${e.toString().replaceFirst('Exception: ', '')}',
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
          Expanded(child: Text(m, style: _soft)),
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
    text: 'Llama sobre tela de algodón con ventilación lenta en microgravedad',
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
  Widget build(BuildContext context) =>
      _Card('EXPERIMENT & MODIFICATION CLASSIFIER', [
        TextField(
          controller: _text,
          minLines: 2,
          maxLines: 4,
          style: AppText.body,
          decoration: const InputDecoration(
            hintText: 'Material, conditions, hazard… (Spanish or English)',
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _run, child: const Text('CLASSIFY')),
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
                          '${_human(c['class'] as String)} · ${_pct(c['p'])}',
                          mono: true,
                          level: i == 0 ? TagLevel.high : TagLevel.neutral,
                        ),
                    ],
                  ),
                  if ((r['category'] as String?)?.isNotEmpty == true)
                    Text(r['category'] as String, style: AppText.caption),
                  Text('REQUIRED MODIFICATIONS', style: AppText.label),
                  _bullets((r['modifications'] as List).cast<String>()),
                ],
              );
            },
          ),
      ]);
}

/// PSI-166 inputs in physical units, prefilled with dataset record PSI166-0002.
const _flowFields = [
  ('temperature_k', 'Temperature (K)', 955.0),
  ('diameter_mm', 'Diameter (mm)', 6.5),
  ('max_velocity_m_s', 'Max velocity (m/s)', 0.0002407),
  ('max_shear_rate_s', 'Max shear rate (1/s)', 0.5469),
  ('reynolds_number', 'Reynolds number', 0.0098),
  ('mhd_max_force_n_m3', 'Max MHD force (N/m³)', 10432.19),
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
          ? Future.error(Exception('every value must be a positive number'))
          : postJson('/classify/psi166', body),
    );
  }

  @override
  Widget build(BuildContext context) => _Card('PSI-166 MELT-FLOW CLASSIFIER', [
    Text(
      'ISS-EML levitated melt: predicts the flow regime and the correction the analysis needs.',
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
        child: const Text('CLASSIFY FLOW'),
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
                    '${_human(r['class'] as String)} · ${_pct(r['p'])}',
                    mono: true,
                    level: TagLevel.high,
                  ),
                  AppTag('model ${r['model']}', mono: true),
                ],
              ),
              if ((r['modification'] as String?)?.isNotEmpty == true)
                _bullets([r['modification'] as String]),
            ],
          );
        },
      ),
  ]);
}

const _types = {
  'experimento': 'Experiments',
  'repositorio_psi': 'PSI repositories',
  'hallazgo': 'Findings',
  'incidente': 'Incidents',
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
    return _Card('TEAM CATALOG', [
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
                    for (final (k, label) in const [
                      ('instalacion_hardware', 'Hardware'),
                      ('investigador_responsable', 'Investigators'),
                      ('fecha_periodo', 'Period'),
                      ('material_combustible', 'Fuel / material'),
                      ('condiciones', 'Conditions'),
                      ('descripcion_objetivo', 'Objective'),
                      ('consecuencia_hallazgo', 'Finding'),
                      ('modificaciones_necesarias', 'Required modifications'),
                      ('fuente', 'Source'),
                      ('referencia', 'Reference'),
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
