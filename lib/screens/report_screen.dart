import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/i18n.dart';
import '../app/page.dart';
import '../app/theme.dart';
import '../copilot/session.dart';
import '../data/gap_map.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';
import '../data/reports.dart';
import 'gap_map_screen.dart' show drawDashed, paintHatch;
import 'report_pdf.dart';

/// Investigation report: objective, flame-spread chart, findings, hardware and test sheet.
class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, this.code});
  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(selectedHabitatProvider);
    final all = ref.watch(experimentsProvider).value;
    if (all == null || all.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }
    final i = all.firstWhere(
      (i) => i.code == code?.toUpperCase(),
      orElse: () => all.first,
    );
    final rank = all.indexOf(i) + 1;
    final r =
        reports[i.code]; // mockup sheet (chart, sensors) where we have one
    // Real catalog findings first; the mockup sheet's only where the data has none.
    final findings = i.keyFindings.isNotEmpty
        ? i.keyFindings
        : r?.findings ?? const <String>[];

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        if (r != null) ...[
          _Panel(
            label: tr('Objective', 'Objetivo'),
            child: Text(r.objective, style: _soft),
          ),
          _ChartPanel(r, h),
        ],
        if (findings.isEmpty)
          _Panel(
            label: tr('Report', 'Reporte'),
            child: Text(
              tr(
                'Report not generated yet. It is built only from linked PSI records.',
                'Reporte aún no generado. Se construye solo a partir de registros PSI vinculados.',
              ),
              style: _soft,
            ),
          )
        else
          _Panel(
            label: tr('Key findings', 'Hallazgos clave'),
            child: Column(
              spacing: 14,
              children: [
                for (final (n, f) in findings.indexed)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${n + 1}'.padLeft(2, '0'),
                          style: AppText.mono.copyWith(
                            fontSize: 15,
                            height: 23 / 15,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          f,
                          style: _soft.copyWith(fontSize: 15, height: 23 / 15),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (i.modifications.isNotEmpty)
          _Panel(
            label: tr('Required modifications', 'Modificaciones requeridas'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final m in i.modifications)
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
            ),
          ),
      ],
    );
    final aside = _Aside(i, r);

    return PageBody(
      gap: 28,
      children: [
        Row(
          spacing: 10,
          children: [
            Tappable(
              label: tr('Back to ranking', 'Volver al ranking'),
              onTap: () => context.go('/ranking'),
              child: Text('Ranking', style: AppText.caption),
            ),
            Text('/', style: AppText.caption),
            Text(
              i.code,
              style: AppText.caption.copyWith(color: AppColors.text),
            ),
          ],
        ),
        _Header(i: i, r: r, h: h, rank: rank, findings: findings),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24,
                  children: [
                    Expanded(child: main),
                    SizedBox(width: 340, child: aside),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 24,
                  children: [main, aside],
                ),
        ),
      ],
    );
  }
}

TextStyle get _soft => AppText.body.copyWith(
  fontSize: 16,
  height: 26 / 16,
  color: AppColors.textSoft,
);

class _Header extends ConsumerWidget {
  const _Header({
    required this.i,
    required this.r,
    required this.h,
    required this.rank,
    required this.findings,
  });
  final Investigation i;
  final int rank;
  final Report? r;
  final Habitat h;
  final List<String> findings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.only(bottom: 24),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 24,
      runSpacing: 24,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Text.rich(
                TextSpan(
                  text: '#${rank.toString().padLeft(2, '0')}   ',
                  style: AppText.mono.copyWith(fontSize: 13),
                  children: [
                    TextSpan(
                      text: (r?.platform ?? i.platform).toUpperCase(),
                      style: AppText.label,
                    ),
                  ],
                ),
              ),
              Text(
                i.code,
                style: AppText.display.copyWith(
                  fontSize: 40,
                  height: 48 / 40,
                  letterSpacing: 5.6,
                ),
              ),
              const LiverySweep(),
              Text(
                i.title,
                style: AppText.body.copyWith(color: AppColors.textMuted),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppTag(
                    tr(
                      '${i.fuelLabel} fuel',
                      'Combustible ${i.fuelLabel.toLowerCase()}',
                    ),
                    leading: FuelMarker(i.fuel),
                  ),
                  for (final d in i.domains) AppTag(d),
                  if (i.sources.isNotEmpty)
                    AppTag(i.sources.first.ref, mono: true),
                ],
              ),
            ],
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 28,
          runSpacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 4,
              children: [
                Text(
                  '${tr('RELEVANCE', 'RELEVANCIA')} · ${h.name.toUpperCase()}',
                  style: AppText.label,
                ),
                Text(
                  '${i.score}',
                  style: AppText.dataXL.copyWith(fontSize: 48, height: 52 / 48),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      i.sources
                          .map((s) => s.description)
                          .firstWhere(
                            (u) => u.startsWith('http'),
                            orElse: () => 'https://psi.nasa.gov',
                          ),
                    ),
                  ),
                  child: Text(tr('OPEN IN PSI', 'ABRIR EN PSI')),
                ),
                OutlinedButton.icon(
                  onPressed: () => Printing.layoutPdf(
                    name:
                        'HabitatFireAtlas_${i.code}_${h.id}_${lang.value.name}.pdf',
                    onLayout: (format) => buildReportPdf(
                      i: i,
                      r: r,
                      h: h,
                      rank: rank,
                      findings: findings,
                      format: format,
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: Text(tr('EXPORT PDF', 'EXPORTAR PDF')),
                ),
                FilledButton(
                  onPressed: () {
                    ref
                        .read(copilotProvider)
                        .ask(
                          tr(
                            'Summarize ${i.code} findings for ${h.name}.',
                            'Resume los hallazgos de ${i.code} para ${h.name}.',
                          ),
                        );
                    context.go('/copilot');
                  },
                  child: Text(tr('ASK COPILOT', 'PREGUNTAR AL COPILOTO')),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.label,
    required this.child,
    this.padding = 26,
    this.gap = 12,
  });
  final String label;
  final Widget child;
  final double padding, gap;

  @override
  Widget build(BuildContext context) => ChamferCard(
    padding: EdgeInsets.all(padding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        Text(label.toUpperCase(), style: AppText.label),
        child,
      ],
    ),
  );
}

/// Series lightness, fastest flow first (encoded by lightness, never hue).
const _seriesColors = [AppColors.text, Color(0xFFAEB0B5), Color(0xFF6E7176)];

class _ChartPanel extends StatelessWidget {
  const _ChartPanel(this.r, this.h);
  final Report r;
  final Habitat h;

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, {bool dashed = false}) => SizedBox(
      width: 14,
      height: 2,
      child: dashed
          ? const CustomPaint(painter: _DashPainter())
          : ColoredBox(color: c),
    );
    Widget legend(Widget s, String l) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        s,
        Text(l, style: AppText.caption.copyWith(color: AppColors.textMuted)),
      ],
    );

    return ChamferCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    tr(
                      'FLAME SPREAD RATE VS OXYGEN',
                      'VELOCIDAD DE PROPAGACIÓN VS OXÍGENO',
                    ),
                    style: AppText.label.copyWith(color: AppColors.textMuted),
                  ),
                  Text(
                    tr(
                      'Thin solid fuel, opposed flow · by flow velocity',
                      'Combustible sólido delgado, flujo opuesto · por velocidad de flujo',
                    ),
                    style: AppText.caption.copyWith(fontSize: 13),
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final (n, s) in r.series.indexed)
                    legend(swatch(_seriesColors[n]), s.label),
                  legend(
                    swatch(AppColors.secondary, dashed: true),
                    tr('Extrapolated', 'Extrapolado'),
                  ),
                ],
              ),
            ],
          ),
          AspectRatio(
            aspectRatio: 760 / 330,
            child: Semantics(
              label: tr(
                'Flame spread rate versus oxygen. Measured up to '
                    '${fmtO2(_maxMeasured(r))} % O₂; ${h.name} sits at ${fmtO2(h.o2)} %.',
                'Velocidad de propagación frente a oxígeno. Medida hasta '
                    '${fmtO2(_maxMeasured(r))} % O₂; ${h.name} está a ${fmtO2(h.o2)} %.',
              ),
              child: CustomPaint(painter: _SpreadPainter(r, h)),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                tr(
                  'X · O₂ (% VOL)    Y · SPREAD RATE (MM/S)',
                  'X · O₂ (% VOL)    Y · VEL. DE PROPAGACIÓN (MM/S)',
                ),
                style: AppText.label,
              ),
              Text(
                tr(
                  'Sample values · bind to PSI dataset [ID]',
                  'Valores de muestra · vincular al dataset PSI [ID]',
                ),
                style: AppText.mono.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

double _maxMeasured(Report r) => r.series
    .expand((s) => s.points)
    .map((p) => p.$1)
    .reduce((a, b) => a > b ? a : b);

class _DashPainter extends CustomPainter {
  const _DashPainter();
  @override
  void paint(Canvas canvas, Size size) => drawDashed(
    canvas,
    Path()
      ..moveTo(0, 1)
      ..lineTo(size.width, 1),
    Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 1.6,
  );
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// SVG viewBox 760×330 from the mockup: plot x 60–740 (O₂ 15–40 %), y 20–290 (0–8 mm/s).
class _SpreadPainter extends CustomPainter {
  _SpreadPainter(this.r, this.h);
  final Report r;
  final Habitat h;

  static const _x0 = 60.0, _x1 = 740.0, _yTop = 20.0, _yBot = 290.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 760);
    double x(double o2) => _x0 + (o2.clamp(15, 40) - 15) / 25 * (_x1 - _x0);
    double y(double v) => _yBot - v / 8 * (_yBot - _yTop);
    Offset at((double, double) p) => Offset(x(p.$1), y(p.$2));
    TextPainter text(
      String s,
      Color c, {
      double size = 11,
      FontWeight? weight,
    }) => TextPainter(
      text: TextSpan(
        text: s,
        style: AppText.mono.copyWith(
          fontSize: size,
          color: c,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // No-data zone beyond the last measured O₂.
    final noData = Rect.fromLTRB(x(_maxMeasured(r)), _yTop, _x1, _yBot);
    canvas
      ..save()
      ..clipRect(noData);
    paintHatch(canvas, noData);
    canvas.restore();
    text(
      tr('NO MEASURED DATA', 'SIN DATOS MEDIDOS'),
      AppColors.secondary,
      size: 10,
    ).paint(canvas, Offset(noData.center.dx - 60, _yTop + 14));

    // Grid, axes, ticks.
    final grid = Paint()..color = AppColors.grid;
    final axis = Paint()..color = AppColors.lineStrong;
    for (var v = 2.0; v <= 8; v += 2) {
      canvas.drawLine(Offset(_x0, y(v)), Offset(_x1, y(v)), grid);
    }
    canvas
      ..drawLine(const Offset(_x0, _yBot), const Offset(_x1, _yBot), axis)
      ..drawLine(const Offset(_x0, _yTop), const Offset(_x0, _yBot), axis);
    for (var v = 0; v <= 8; v += 2) {
      final t = text('$v', AppColors.secondary);
      t.paint(canvas, Offset(50 - t.width, y(v.toDouble()) - t.height / 2));
    }
    for (var o2 = 15; o2 <= 40; o2 += 5) {
      final t = text('$o2', AppColors.secondary);
      t.paint(canvas, Offset(x(o2.toDouble()) - t.width / 2, 303));
    }

    // Habitat O₂ marker (red: the risk line).
    final hx = x(h.o2);
    drawDashed(
      canvas,
      Path()
        ..moveTo(hx, _yTop)
        ..lineTo(hx, _yBot),
      Paint()
        ..color = AppColors.red
        ..strokeWidth = 1.5,
      gap: 4,
    );
    final tag = text(
      '${h.name.toUpperCase()} · ${fmtO2(h.o2)} %',
      Colors.white,
      weight: FontWeight.w600,
    );
    final tagW = tag.width + 16;
    final tagX = hx + 8 + tagW > _x1 ? hx - 8 - tagW : hx + 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX, 62, tagW, 22),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.red,
    );
    tag.paint(canvas, Offset(tagX + 8, 73 - tag.height / 2));

    // Extrapolation from the fastest series' last point.
    drawDashed(
      canvas,
      Path()
        ..moveTo(
          at(r.series.first.points.last).dx,
          at(r.series.first.points.last).dy,
        )
        ..lineTo(at(r.extrapolateTo).dx, at(r.extrapolateTo).dy),
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 1.5,
      dash: 5,
      gap: 5,
    );

    // Measured series, slowest first so the brightest sits on top.
    for (final (n, s) in r.series.indexed.toList().reversed) {
      final stroke = Paint()
        ..color = _seriesColors[n]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(
        Path()..addPolygon(s.points.map(at).toList(), false),
        stroke,
      );
      for (final p in s.points) {
        canvas
          ..drawCircle(at(p), 3.5, Paint()..color = AppColors.ground)
          ..drawCircle(at(p), 3.5, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpreadPainter old) => old.r != r || old.h != h;
}

class _Aside extends StatelessWidget {
  const _Aside(this.i, this.r);
  final Investigation i;
  final Report? r; // mockup sheet extras (geometry, sensors) where we have one

  @override
  Widget build(BuildContext context) {
    final r = this.r;
    final conditions = [
      (tr('Oxygen', 'Oxígeno'), '${i.o2Range} %'),
      (tr('Pressure', 'Presión'), '${i.pressureRange} psi'),
      if (i.flowRange.isNotEmpty)
        (tr('Flow velocity', 'Velocidad de flujo'), '${i.flowRange} cm/s'),
      (tr('Gravity', 'Gravedad'), i.gravity),
      if (i.materials.isNotEmpty)
        (tr('Materials', 'Materiales'), i.materials.join(' · ')),
    ];
    const rowLine = Border(bottom: BorderSide(color: AppColors.grid));
    final key = AppText.caption.copyWith(
      fontSize: 13,
      color: AppColors.textSoft,
    );
    final value = AppText.mono.copyWith(fontSize: 13, color: AppColors.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        _Panel(
          label: 'Hardware',
          padding: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                i.hardware.isEmpty ? (r?.hardware ?? '–') : i.hardware,
                style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (r != null)
                Text(
                  r.hardwareNote,
                  style: AppText.caption.copyWith(
                    fontSize: 13,
                    height: 20 / 13,
                  ),
                ),
            ],
          ),
        ),
        if (r != null)
          _Panel(
            label: tr('Fuel sample geometry', 'Geometría de la muestra'),
            padding: 24,
            gap: 16,
            child: Row(
              spacing: 12,
              children: [
                for (final g in r.geometries)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        spacing: 10,
                        children: [
                          CustomPaint(
                            size: const Size(56, 44),
                            painter: _GeometryPainter(g),
                          ),
                          Text(
                            g.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        _Panel(
          label: tr('Test conditions', 'Condiciones de ensayo'),
          padding: 24,
          gap: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('PARAMETER', 'PARÁMETRO'),
                        style: AppText.label.copyWith(fontSize: 10),
                      ),
                    ),
                    Text(
                      tr('RANGE', 'RANGO'),
                      style: AppText.label.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              for (final (k, v) in conditions)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: const BoxDecoration(border: rowLine),
                  child: Row(
                    spacing: 12,
                    children: [
                      Text(k, style: key),
                      Expanded(
                        child: Text(
                          v,
                          style: value,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                tr(
                  'Verify each value against PSI metadata.',
                  'Verifica cada valor con los metadatos PSI.',
                ),
                style: AppText.mono.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        if (r != null)
          _Panel(
            label: tr('Sensors', 'Sensores'),
            padding: 24,
            child: Column(
              children: [
                for (final (n, (name, unit)) in r.sensors.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: n == r.sensors.length - 1 ? null : rowLine,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppText.body.copyWith(fontSize: 14),
                          ),
                        ),
                        Text(unit, style: AppText.mono),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Outline sketch of the sample shape (mockup SVGs, 56×44).
class _GeometryPainter extends CustomPainter {
  const _GeometryPainter(this.g);
  final Geometry g;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    switch (g) {
      case Geometry.sheet:
        canvas.drawPath(
          Path()..addPolygon(const [
            Offset(8, 34),
            Offset(20, 10),
            Offset(48, 10),
            Offset(36, 34),
          ], true),
          p,
        );
      case Geometry.rod:
        canvas
          ..drawOval(
            Rect.fromCenter(center: const Offset(12, 22), width: 8, height: 16),
            p,
          )
          ..drawLine(const Offset(12, 14), const Offset(46, 14), p)
          ..drawLine(const Offset(12, 30), const Offset(46, 30), p)
          ..drawArc(
            Rect.fromCenter(center: const Offset(46, 22), width: 8, height: 16),
            -1.5708,
            3.1416,
            false,
            p,
          );
      case Geometry.sphere:
        canvas
          ..drawCircle(const Offset(28, 22), 15, p)
          ..drawOval(
            Rect.fromCenter(
              center: const Offset(28, 22),
              width: 30,
              height: 10,
            ),
            p..color = AppColors.text.withValues(alpha: .5),
          );
    }
  }

  @override
  bool shouldRepaint(covariant _GeometryPainter old) => old.g != g;
}
