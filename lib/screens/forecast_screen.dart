import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/i18n.dart';
import '../app/page.dart';
import '../app/theme.dart';
import '../copilot/session.dart';
import '../data/flame.dart';
import '../data/gap_map.dart' show fmtO2;
import '../data/habitats.dart';
import '../widgets/habitat_flame_3d_card.dart';

const _psiToKpa = 6.89476;

/// Conditions the forecast runs at: the selected habitat, then whatever the sliders change.
typedef _Cond = ({
  double o2,
  double kpa,
  GravityBand band,
  double flow,
  String? material,
});

_Cond _fromHabitat(Habitat h) => (
  o2: h.o2,
  kpa: h.pressure * _psiToKpa,
  band: h.band,
  flow: cabinFlow,
  material: null,
);

/// Step 02 · Predict: the physics flame model at any condition, the curves behind it and
/// who burns first (materials, habitats).
class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  late _Cond _c = _fromHabitat(ref.read(selectedHabitatProvider));

  @override
  Widget build(BuildContext context) {
    ref.listen(
      selectedHabitatProvider,
      (_, h) => setState(() => _c = _fromHabitat(h)),
    );
    final h = ref.watch(selectedHabitatProvider);
    final model = ref.watch(flameModelProvider).value;
    final measured = ref.watch(spreadPointsProvider).value ?? const [];
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final c = _c;
    FlameForecast at({double? o2, double? flow, double? g, String? material}) =>
        model.predict(
          o2: o2 ?? c.o2,
          kpa: c.kpa,
          g: g ?? c.band.g,
          flow: flow ?? c.flow,
          material: material ?? c.material,
        );
    final f = at();
    final atHabitat = c == _fromHabitat(h);

    final controls = _Controls(
      c: c,
      model: model,
      onChanged: (v) => setState(() => _c = v),
      onReset: atHabitat ? null : () => setState(() => _c = _fromHabitat(h)),
    );
    final flame3D = HabitatFlame3DCard(
      o2Percent: c.o2,
      pressurePsi: c.kpa / _psiToKpa,
      forcedFlowCmS: c.flow,
      gravityG: c.band.g,
      materialName: f.name, // English key: the 3D card matches on it
    );
    final readout = _Readout(f: f, c: c, quiet: at(flow: 0));
    final charts = [
      _ChartCard(
        title: tr('FLAME SPREAD VS O₂', 'PROPAGACIÓN DE LLAMA VS O₂'),
        caption: tr(
          'Predicted at ${fmtO2(c.kpa)} kPa · ${c.band.short} · ${fmtO2(c.flow)} cm/s. '
              'Dots: measured ${f.name} burns.',
          'Predicción a ${fmtO2(c.kpa)} kPa · ${c.band.short} · ${fmtO2(c.flow)} cm/s. '
              'Puntos: combustiones medidas de ${trd(f.name)}.',
        ),
        chart: _SpreadChart(
          curve: [
            for (var o2 = 10.0; o2 <= math.max(40, c.o2); o2 += 1)
              FlSpot(o2, at(o2: o2).spread),
          ],
          measured: [
            for (final p in measured)
              if (model.match(p.material) == f.material) FlSpot(p.o2, p.spread),
          ],
          now: FlSpot(c.o2, f.spread),
        ),
      ),
      _ChartCard(
        title: tr(
          'FLAMMABILITY LIMIT VS FLOW',
          'LÍMITE DE INFLAMABILIDAD VS FLUJO',
        ),
        caption: tr(
          'Minimum O₂ that sustains a flame. Above a line it burns. '
              'Too little flow starves it, too much blows it off.',
          'O₂ mínimo que sostiene una llama. Por encima de una línea arde. '
              'Poco flujo la asfixia, demasiado la apaga por soplado.',
        ),
        chart: _LimitChart(
          lines: {
            for (final b in GravityBand.values)
              b: [
                for (var u = 0.0; u <= 50; u += 1)
                  FlSpot(u, at(flow: u, g: b.g).loi),
              ],
          },
          current: c.band,
          now: FlSpot(c.flow, c.o2),
        ),
      ),
    ];

    final materials = [for (final m in model.materials.keys) at(material: m)]
      ..sort((a, b) => b.margin.compareTo(a.margin));
    final habitatRisk = [
      for (final x in habitats)
        (
          h: x,
          f: model.predict(
            o2: x.o2,
            kpa: x.pressure * _psiToKpa,
            g: x.band.g,
            flow: cabinFlow,
            material: c.material,
          ),
        ),
    ]..sort((a, b) => b.f.margin.compareTo(a.f.margin));

    return PageBody(
      gap: 28,
      children: [
        PageIntro(
          step: tr('STEP 02 · PREDICT', 'PASO 02 · PREDECIR'),
          title: tr('FLAME FORECAST', 'PRONÓSTICO DE LLAMA'),
          description: TextSpan(
            text: tr(
              'How a flame behaves at any condition: a physics model (flammability limit vs '
                  'flow, buoyancy from gravity, pressure, de Ris spread), calibrated on '
                  '${model.summary}. It flags where it extrapolates. ',
              'Cómo se comporta una llama en cualquier condición: un modelo físico (límite de '
                  'inflamabilidad vs flujo, flotabilidad por gravedad, presión, propagación de de Ris), '
                  'calibrado con ${model.summary}. Señala dónde extrapola. ',
            ),
            children: [
              TextSpan(
                text: atHabitat
                    ? tr('Showing ${h.name}.', 'Mostrando ${h.name}.')
                    : tr(
                        'What-if from ${h.name}.',
                        'Escenario hipotético desde ${h.name}.',
                      ),
                style: const TextStyle(color: AppColors.text),
              ),
            ],
          ),
          trailing: FilledButton(
            onPressed: () {
              ref
                  .read(copilotProvider)
                  .ask(
                    tr(
                      'What if we run at ${fmtO2(c.o2)}% O2, ${fmtO2(c.kpa)} kPa, '
                          '${c.band.g < .01 ? 'microgravity' : '${c.band.g} g'}, '
                          '${fmtO2(c.flow)} cm/s flow'
                          '${c.material == null ? '' : ' with ${f.name}'}?',
                      '¿Qué pasa si operamos a ${fmtO2(c.o2)}% O2, ${fmtO2(c.kpa)} kPa, '
                          '${c.band.g < .01 ? 'microgravedad' : '${c.band.g} g'}, '
                          'flujo de ${fmtO2(c.flow)} cm/s'
                          '${c.material == null ? '' : ' con ${trd(f.name)}'}?',
                    ),
                  );
              context.go('/copilot');
            },
            child: Text(
              tr(
                'ASK COPILOT ABOUT THIS CONDITION',
                'PREGUNTAR AL COPILOTO POR ESTA CONDICIÓN',
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppLayout.gutter,
                  children: [
                    SizedBox(width: 340, child: controls),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppLayout.gutter,
                        children: [
                          readout,
                          flame3D,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: AppLayout.gutter,
                            children: [
                              for (final ch in charts) Expanded(child: ch),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppLayout.gutter,
                  children: [readout, flame3D, controls, ...charts],
                ),
        ),
        Wrap(
          spacing: AppLayout.gutter,
          runSpacing: AppLayout.gutter,
          children: [
            _RankCard(
              title: tr(
                'WHICH MATERIAL BURNS FIRST · THIS CONDITION',
                'QUÉ MATERIAL ARDE PRIMERO · ESTA CONDICIÓN',
              ),
              rows: [
                for (final m in materials)
                  (
                    label: trd(m.name),
                    f: m,
                    selected: m.material == f.material,
                    onTap: () => setState(
                      () => _c = (
                        o2: c.o2,
                        kpa: c.kpa,
                        band: c.band,
                        flow: c.flow,
                        material: m.material,
                      ),
                    ),
                  ),
              ],
            ),
            _RankCard(
              title: tr(
                'HABITAT FIRE RISK · ${f.name.toUpperCase()}, VENTILATED',
                'RIESGO DE INCENDIO POR HÁBITAT · ${trd(f.name).toUpperCase()}, VENTILADO',
              ),
              rows: [
                for (final r in habitatRisk)
                  (
                    label: r.h.name,
                    f: r.f,
                    selected: r.h == h,
                    onTap: () =>
                        ref.read(selectedHabitatProvider.notifier).select(r.h),
                  ),
              ],
            ),
          ],
        ),
        Text(
          tr(
            'Model: LOI = MOC + q·ln²(u/u*) + kP·ln(101.3/P), u = √(flow² + (${fmtO2(model.uBuoy1g)}·g^⅓)²), '
                'spread ∝ (O₂ − LOI). Fit: q ${model.q}, u* ${fmtO2(model.uStar)} cm/s, '
                'kP ${model.kP} · n ${model.n} · accuracy ${(model.accuracy * 100).round()} % · '
                'spread RMSE ${model.spreadRmse} mm/s.',
            'Modelo: LOI = MOC + q·ln²(u/u*) + kP·ln(101.3/P), u = √(flujo² + (${fmtO2(model.uBuoy1g)}·g^⅓)²), '
                'propagación ∝ (O₂ − LOI). Ajuste: q ${model.q}, u* ${fmtO2(model.uStar)} cm/s, '
                'kP ${model.kP} · n ${model.n} · precisión ${(model.accuracy * 100).round()} % · '
                'RMSE de propagación ${model.spreadRmse} mm/s.',
          ),
          style: AppText.mono.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.c,
    required this.model,
    required this.onChanged,
    this.onReset,
  });
  final _Cond c;
  final FlameModel model;
  final ValueChanged<_Cond> onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    Widget slider(
      String label,
      String unit,
      double value,
      double min,
      double max,
      _Cond Function(double) set,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 8,
          children: [
            Flexible(child: Text(label, style: AppText.label)),
            DataValue(
              fmtO2(double.parse(value.toStringAsFixed(1))),
              unit,
              size: 15,
              unitSize: 11,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          label: label,
          onChanged: (v) => onChanged(set(double.parse(v.toStringAsFixed(1)))),
        ),
      ],
    );

    return ChamferCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tr('CONDITIONS', 'CONDICIONES'), style: AppText.label),
              TextButton(
                onPressed: onReset,
                child: Text(tr('RESET TO HABITAT', 'VOLVER AL HÁBITAT')),
              ),
            ],
          ),
          slider(
            tr('OXYGEN', 'OXÍGENO'),
            '% O₂',
            c.o2,
            10,
            100,
            (v) => (
              o2: v,
              kpa: c.kpa,
              band: c.band,
              flow: c.flow,
              material: c.material,
            ),
          ),
          slider(
            tr('PRESSURE', 'PRESIÓN'),
            'kPa',
            c.kpa,
            20,
            105,
            (v) => (
              o2: c.o2,
              kpa: v,
              band: c.band,
              flow: c.flow,
              material: c.material,
            ),
          ),
          slider(
            tr('VENTILATION FLOW', 'FLUJO DE VENTILACIÓN'),
            'cm/s',
            c.flow,
            0,
            50,
            (v) => (
              o2: c.o2,
              kpa: c.kpa,
              band: c.band,
              flow: v,
              material: c.material,
            ),
          ),
          Text(tr('GRAVITY', 'GRAVEDAD'), style: AppText.label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in GravityBand.values.reversed)
                ToggleChip(
                  b.short,
                  selected: b == c.band,
                  accent: true,
                  onTap: () => onChanged((
                    o2: c.o2,
                    kpa: c.kpa,
                    band: b,
                    flow: c.flow,
                    material: c.material,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('MATERIAL', style: AppText.label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final MapEntry(:key, :value) in model.materials.entries)
                ToggleChip(
                  trd(value.name),
                  selected: key == (c.material ?? model.defaultMaterial),
                  accent: true,
                  onTap: () => onChanged((
                    o2: c.o2,
                    kpa: c.kpa,
                    band: c.band,
                    flow: c.flow,
                    material: key,
                  )),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.f, required this.c, required this.quiet});
  final FlameForecast f, quiet;
  final _Cond c;

  @override
  Widget build(BuildContext context) {
    final burns = f.margin > 0;
    final level = switch (f.regime) {
      FlameRegime.vigorous => TagLevel.critical,
      FlameRegime.sustained || FlameRegime.marginal => TagLevel.high,
      FlameRegime.extinguishes => TagLevel.neutral,
    };
    String sign(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    final why = !burns
        ? f.oxygenStarved
              ? tr(
                  'Too little flow reaches the flame (${fmtO2(f.uEff)} cm/s): it starves of oxygen and goes out.',
                  'Llega muy poco flujo a la llama (${fmtO2(f.uEff)} cm/s): se queda sin oxígeno y se apaga.',
                )
              : tr(
                  'The flow (${fmtO2(f.uEff)} cm/s) blows the flame off before it can spread.',
                  'El flujo (${fmtO2(f.uEff)} cm/s) apaga la llama por soplado antes de que se propague.',
                )
        : c.band.g > .01
        ? tr(
            'Buoyancy at ${c.band.short} feeds it ${f.uBuoy.toStringAsFixed(1)} cm/s of fresh air: '
                'turning ventilation off does not starve it (${quiet.regime.label.toLowerCase()}).',
            'La flotabilidad a ${c.band.short} le aporta ${f.uBuoy.toStringAsFixed(1)} cm/s de aire fresco: '
                'apagar la ventilación no la asfixia (${quiet.regime.label.toLowerCase()}).',
          )
        : tr(
            'In microgravity only ventilation feeds it: fans off → limit '
                '${quiet.loi.toStringAsFixed(1)} % O₂ (${quiet.regime.label.toLowerCase()}).',
            'En microgravedad solo la alimenta la ventilación: ventiladores apagados → límite '
                '${quiet.loi.toStringAsFixed(1)} % O₂ (${quiet.regime.label.toLowerCase()}).',
          );

    Widget stat(String label, String value, String unit) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(label, style: AppText.label),
        DataValue(value, unit, size: 26, unitSize: 12),
      ],
    );

    return ChamferCard(
      selected: burns,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 18,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                tr('FORECAST · ', 'PRONÓSTICO · ') + trd(f.name).toUpperCase(),
                style: AppText.label,
              ),
              AppTag(f.regime.label, mono: true, level: level),
              if (f.extrapolated.isEmpty)
                AppTag(
                  tr('WITHIN TESTED RANGE', 'DENTRO DEL RANGO ENSAYADO'),
                  mono: true,
                )
              else
                AppTag(
                  tr(
                    'PHYSICS EXTRAPOLATION · UNTESTED',
                    'EXTRAPOLACIÓN FÍSICA · SIN ENSAYAR',
                  ),
                  mono: true,
                  level: TagLevel.high,
                ),
            ],
          ),
          Wrap(
            spacing: 36,
            runSpacing: 16,
            children: [
              stat(
                tr('P(BURN)', 'P(ARDER)'),
                (f.pBurn * 100).toStringAsFixed(0),
                '%',
              ),
              stat(
                tr('SPREAD RATE', 'VEL. DE PROPAGACIÓN'),
                f.spread.toStringAsFixed(1),
                'mm/s',
              ),
              stat(
                tr('FLAMMABILITY LIMIT', 'LÍMITE DE INFLAMABILIDAD'),
                f.loi.toStringAsFixed(1),
                '% O₂',
              ),
              stat(tr('MARGIN', 'MARGEN'), sign(f.margin), '% O₂'),
              stat(
                tr('FLOW AT FLAME', 'FLUJO EN LA LLAMA'),
                f.uEff.toStringAsFixed(1),
                'cm/s',
              ),
            ],
          ),
          Text(why, style: AppText.body.copyWith(color: AppColors.textSoft)),
          for (final e in f.extrapolated)
            Text(
              tr('· untested: $e', '· sin ensayar: $e'),
              style: AppText.mono.copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.caption,
    required this.chart,
  });
  final String title, caption;
  final Widget chart;

  @override
  Widget build(BuildContext context) => ChamferCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(title, style: AppText.label),
        SizedBox(height: 220, child: chart),
        Text(caption, style: AppText.caption),
      ],
    ),
  );
}

FlTitlesData _titles(String x, String y) {
  final tick = AppText.mono.copyWith(fontSize: 10);
  final axis = AppText.label.copyWith(fontSize: 10);
  SideTitles side(double reserved) => SideTitles(
    showTitles: true,
    reservedSize: reserved,
    getTitlesWidget: (v, meta) => SideTitleWidget(
      meta: meta,
      child: Text(fmtO2(v), style: tick),
    ),
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      axisNameWidget: Text(y, style: axis),
      sideTitles: side(32),
    ),
    bottomTitles: AxisTitles(
      axisNameWidget: Text(x, style: axis),
      sideTitles: side(22),
    ),
  );
}

final _grid = FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.grid, strokeWidth: 1),
);
final _border = FlBorderData(
  show: true,
  border: const Border(
    left: BorderSide(color: AppColors.lineStrong),
    bottom: BorderSide(color: AppColors.lineStrong),
  ),
);

LineChartBarData _dots(List<FlSpot> spots, {bool now = false}) =>
    LineChartBarData(
      spots: spots..sort((a, b) => a.x.compareTo(b.x)),
      barWidth: 0,
      color: Colors.transparent,
      dotData: FlDotData(
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: now ? 5 : 3.5,
          color: now ? AppColors.red : AppColors.ground,
          strokeColor: now ? Colors.white : AppColors.textMuted,
          strokeWidth: 2,
        ),
      ),
    );

class _SpreadChart extends StatelessWidget {
  const _SpreadChart({
    required this.curve,
    required this.measured,
    required this.now,
  });
  final List<FlSpot> curve, measured;
  final FlSpot now;

  @override
  Widget build(BuildContext context) {
    final maxY =
        [...curve, ...measured].fold(1.0, (m, s) => math.max(m, s.y)) * 1.15;
    return Semantics(
      label: tr(
        'Predicted flame spread rate versus oxygen, ${measured.length} measured points',
        'Velocidad de propagación predicha frente a oxígeno, ${measured.length} puntos medidos',
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY.ceilToDouble(),
          titlesData: _titles('O₂ %', 'mm/s'),
          gridData: _grid,
          borderData: _border,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: curve,
              color: AppColors.text,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            if (measured.isNotEmpty) _dots(measured),
            _dots([now], now: true),
          ],
        ),
      ),
    );
  }
}

class _LimitChart extends StatelessWidget {
  const _LimitChart({
    required this.lines,
    required this.current,
    required this.now,
  });
  final Map<GravityBand, List<FlSpot>> lines;
  final GravityBand current;
  final FlSpot now;

  @override
  Widget build(BuildContext context) {
    final ys = [for (final l in lines.values) ...l.map((s) => s.y), now.y];
    final maxY = math.min(60.0, ys.reduce(math.max) + 2).ceilToDouble();
    final minY = math.max(0.0, ys.reduce(math.min) - 2).floorToDouble();
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: tr(
              'Flammability limit versus ventilation flow for each gravity level',
              'Límite de inflamabilidad frente a flujo de ventilación para cada nivel de gravedad',
            ),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 50,
                minY: minY,
                maxY: maxY,
                clipData: const FlClipData.all(),
                titlesData: _titles(
                  tr('flow cm/s', 'flujo cm/s'),
                  tr('limit % O₂', 'límite % O₂'),
                ),
                gridData: _grid,
                borderData: _border,
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  for (final MapEntry(key: b, value: spots) in lines.entries)
                    LineChartBarData(
                      spots: spots,
                      color: b == current
                          ? AppColors.text
                          : AppColors.lineSelected,
                      barWidth: b == current ? 2.5 : 1.5,
                      dashArray: b == current ? null : [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                  if (now.y <= maxY) _dots([now], now: true),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            for (final b in GravityBand.values)
              Text(
                b == current ? '— ${b.short}' : '-- ${b.short}',
                style: AppText.mono.copyWith(
                  fontSize: 10,
                  color: b == current ? AppColors.text : AppColors.secondary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

typedef _RankRow = ({
  String label,
  FlameForecast f,
  bool selected,
  VoidCallback onTap,
});

class _RankCard extends StatelessWidget {
  const _RankCard({required this.title, required this.rows});
  final String title;
  final List<_RankRow> rows;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 300, maxWidth: 632),
    child: ChamferCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(title, style: AppText.label),
          const SizedBox(height: 6),
          for (final (i, r) in rows.indexed)
            Tappable(
              selected: r.selected,
              label: '${i + 1}. ${r.label}, ${r.f.regime.label.toLowerCase()}',
              onTap: r.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: r.selected
                        ? AppColors.lineSelected
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}', style: AppText.mono),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            r.label,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          MeterBar(
                            r.f.pBurn,
                            color: r.f.margin > 0
                                ? AppColors.red
                                : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        '${r.f.regime.label}\n'
                        '${r.f.spread.toStringAsFixed(1)} mm/s · lim ${r.f.loi.toStringAsFixed(1)} %'
                        '${r.f.extrapolated.isEmpty ? '' : tr(' · untested', ' · sin ensayar')}',
                        textAlign: TextAlign.right,
                        style: AppText.mono.copyWith(fontSize: 10, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
