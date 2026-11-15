import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';

import '../app/page.dart';
import '../copilot/session.dart';
import '../app/theme.dart';
import '../data/gap_map.dart';
import '../data/gap_map.dart' as gm show marksIn;
import '../data/flame.dart';
import '../data/habitats.dart';

/// Step 03 · Coverage: where tests exist on O₂ × gravity, where nobody has burned anything,
/// and how far the selected habitat sits from evidence.
class GapMapScreen extends ConsumerStatefulWidget {
  const GapMapScreen({super.key});

  @override
  ConsumerState<GapMapScreen> createState() => _GapMapScreenState();
}

class _GapMapScreenState extends ConsumerState<GapMapScreen> {
  final _layers = {...Fuel.values};

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(selectedHabitatProvider);
    final all = ref.watch(testMarksProvider).value ?? const <TestMark>[];
    final recs =
        ref.watch(recommendationsProvider).value ?? const <Recommendation>[];
    final model = ref.watch(modelProvider).value;
    final marks = [
      for (final m in all)
        if (_layers.contains(m.fuel)) m,
    ];

    return PageBody(
      gap: 28,
      children: [
        PageIntro(
          step: 'STEP 04 · COVERAGE',
          title: 'DATA GAP MAP',
          description: const TextSpan(
            text:
                'Where NASA has burned things — and where nobody has. Each mark is a test '
                'condition from a PSI investigation; hatched zones have no data.',
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Text('FUEL LAYERS', style: AppText.label),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in Fuel.values)
                    ToggleChip(
                      _fuelName(f),
                      leading: FuelMarker(f),
                      selected: _layers.contains(f),
                      semanticLabel: '${_fuelName(f)} layer',
                      onTap: () => setState(
                        () => _layers.contains(f)
                            ? _layers.remove(f)
                            : _layers.add(f),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final chart = _ChartCard(
              habitat: h,
              marks: marks,
              zones: gapZonesFor(all),
              recs: recs.take(3).toList(),
              trained: model?.o2Range,
            );
            final aside = _Aside(h, all, recs: recs, model: model);
            return box.maxWidth >= 1040
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 24,
                    children: [
                      Expanded(child: chart),
                      SizedBox(width: 320, child: aside),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [chart, aside],
                  );
          },
        ),
      ],
    );
  }
}

String _fuelName(Fuel f) => switch (f) {
  Fuel.solid => 'Solid',
  Fuel.liquid => 'Liquid',
  Fuel.gas => 'Gas',
};

// ───────────────────────── Chart ─────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.habitat,
    required this.marks,
    required this.zones,
    required this.recs,
    required this.trained,
  });
  final Habitat habitat;
  final List<TestMark> marks;
  final List<GapZone> zones;
  final List<Recommendation> recs;
  final (double, double)? trained;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final legend = AppText.caption.copyWith(color: AppColors.textMuted);
    Widget item(_Swatch s, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        CustomPaint(
          size: Size(s == _Swatch.noData || s == _Swatch.model ? 16 : 10, 12),
          painter: _SwatchPainter(s),
        ),
        Text(label, style: legend),
      ],
    );

    return ChamferCard(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 18,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 10,
            children: [
              Text(
                'OXYGEN CONCENTRATION × GRAVITY LEVEL',
                style: AppText.label.copyWith(color: AppColors.textMuted),
              ),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  item(_Swatch.solid, 'Solid'),
                  item(_Swatch.liquid, 'Liquid'),
                  item(_Swatch.gas, 'Gas'),
                  item(_Swatch.partial, 'Partial-g (sparse)'),
                  item(_Swatch.noData, 'No data'),
                  item(_Swatch.habitat, 'Your habitat'),
                  item(_Swatch.suggested, 'Suggested test'),
                  if (trained != null) item(_Swatch.model, 'Model trained'),
                ],
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              SizedBox(
                width: narrow ? 64 : 104,
                child: Column(
                  children: [
                    for (final b in GravityBand.values)
                      SizedBox(
                        height: _GapMapPainter.bandH,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              b.label.toUpperCase(),
                              style: AppText.h2.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.54,
                              ),
                            ),
                            Text(
                              b.axis,
                              style: AppText.mono.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Semantics(
                  label:
                      'Map of ${marks.length} tested conditions by oxygen and gravity. '
                      '${habitat.name} is at ${fmtO2(habitat.o2)} % O₂, ${habitat.band.short}.',
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GapMapPainter(
                        marks: marks,
                        habitat: habitat,
                        zones: zones,
                        recs: recs,
                        trained: trained,
                      ),
                      child: const SizedBox(
                        height: _GapMapPainter.plotH + _GapMapPainter.axisH,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('O₂ CONCENTRATION (% BY VOLUME)', style: AppText.label),
              Text(
                'Test points from the Habitat Fire Atlas API · PSI records',
                style: AppText.mono.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// O₂ (x) × gravity band (y). 10–45 % is linear over 86 % of the width; past a dashed
/// axis break, everything above 45 % sits in a single pure-oxygen slot at 94 %.
class _GapMapPainter extends CustomPainter {
  _GapMapPainter({
    required this.marks,
    required this.habitat,
    required this.zones,
    required this.recs,
    required this.trained,
  });
  final List<TestMark> marks;
  final Habitat habitat;
  final List<GapZone> zones;
  final List<Recommendation> recs;
  final (double, double)? trained;

  static const bandH = 130.0, plotH = bandH * 4, axisH = 28.0;
  static const _breakX = .88, _pureSlot = .94;

  static double xFrac(double o2) => o2 <= 45
      ? (math.max(o2, gapMapO2Min) - gapMapO2Min) / (45 - gapMapO2Min) * .86
      : _pureSlot;
  static double bandTop(GravityBand b) => b.index * bandH;
  static double bandMid(GravityBand b) => bandTop(b) + bandH / 2;
  static double fuelOffset(Fuel f) => switch (f) {
    Fuel.solid => -25,
    Fuel.liquid => 0,
    Fuel.gas => 25,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double x(double o2) => xFrac(o2) * w;

    // Grid
    final vGrid = Paint()..color = const Color(0xFF222327);
    for (var o2 = gapMapO2Min; o2 <= 45; o2 += 5) {
      canvas.drawLine(Offset(x(o2), 0), Offset(x(o2), plotH), vGrid);
    }
    final hGrid = Paint()..color = AppColors.grid;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, i * bandH), Offset(w, i * bandH), hGrid);
    }
    final axis = Paint()..color = AppColors.lineStrong;
    drawDashed(
      canvas,
      Path()
        ..moveTo(_breakX * w, 0)
        ..lineTo(_breakX * w, plotH),
      axis,
    );
    canvas
      ..drawLine(Offset.zero, const Offset(0, plotH), axis)
      ..drawLine(const Offset(0, plotH), Offset(w, plotH), axis);

    // Gap zones
    for (final z in zones) {
      final left = z.o2From > 45 ? (_breakX + .01) * w : x(z.o2From);
      final right = z.o2To > 45 ? (_pureSlot + .05) * w : x(z.o2To);
      final rect = RRect.fromLTRBR(
        left,
        bandTop(z.from) + 8,
        right,
        bandTop(z.to) + bandH - 8,
        const Radius.circular(4),
      );
      canvas.save();
      canvas.clipRRect(rect);
      paintHatch(canvas, rect.outerRect);
      final label = _layout(
        z.label,
        AppText.mono.copyWith(
          fontSize: 10,
          letterSpacing: 1.4,
          color: AppColors.secondary,
        ),
      );
      final chip = Rect.fromCenter(
        center: rect.center,
        width: label.width + 12,
        height: label.height + 6,
      );
      if (z.label.isNotEmpty) {
        canvas.drawRect(chip, Paint()..color = AppColors.card);
        label.paint(canvas, chip.topLeft + const Offset(6, 3));
      }
      canvas.restore();
      drawDashed(
        canvas,
        Path()..addRRect(rect),
        Paint()
          ..color = AppColors.lineStrong
          ..style = PaintingStyle.stroke,
      );
    }

    // Model training envelope: ISS (μg) band, trained O₂ range.
    if (trained case (final lo, final hi)) {
      final r = Rect.fromLTRB(
        x(lo.clamp(gapMapO2Min, 45)),
        bandTop(GravityBand.micro) + 4,
        x(hi.clamp(gapMapO2Min, 45)),
        bandTop(GravityBand.micro) + bandH - 4,
      );
      drawDashed(
        canvas,
        Path()..addRect(r),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 1.2,
        dash: 6,
        gap: 4,
      );
      _layout(
        'MODEL TRAINED',
        AppText.mono.copyWith(
          fontSize: 9,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      ).paint(canvas, r.topLeft + const Offset(6, 4));
    }

    // Suggested next tests (backend priority ranking): numbered outline squares.
    for (final (i, rec) in recs.indexed) {
      final c = Offset(x(rec.o2), bandMid(rec.band));
      final sq = Rect.fromCenter(center: c, width: 18, height: 18);
      canvas
        ..drawRect(sq, Paint()..color = AppColors.ground)
        ..drawRect(
          sq,
          Paint()
            ..color = AppColors.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      final n = _layout(
        '${i + 1}',
        AppText.mono.copyWith(fontSize: 10, color: AppColors.text),
      );
      n.paint(canvas, c - Offset(n.width / 2, n.height / 2));
    }

    // Test marks
    for (final m in marks) {
      final c = Offset(x(m.o2), bandMid(m.band) + fuelOffset(m.fuel));
      paintMark(canvas, c, m.fuel, partial: m.partialG);
      if (m.callout) {
        final label = _layout(
          '${m.series} · ${fmtO2(m.o2)} %',
          AppText.mono.copyWith(
            fontSize: 10,
            letterSpacing: .8,
            color: AppColors.textMuted,
          ),
        );
        // Right of the mark, or left of it when it would run past the plot edge.
        final dx = c.dx + 10 + label.width > w ? -10 - label.width : 10.0;
        label.paint(canvas, c + Offset(dx, -12));
      }
    }

    // Habitat target: the only red mark
    final t = Offset(x(habitat.o2), bandMid(habitat.band));
    final cross = Paint()..color = AppColors.red.withValues(alpha: .7);
    drawDashed(
      canvas,
      Path()
        ..moveTo(t.dx, 0)
        ..lineTo(t.dx, plotH),
      cross,
    );
    drawDashed(
      canvas,
      Path()
        ..moveTo(0, t.dy)
        ..lineTo(w, t.dy),
      cross,
    );
    paintTarget(canvas, t, ring: 17);
    final tag = _layout(
      '${habitat.name.toUpperCase()} · ${fmtO2(habitat.o2)} % O₂ · ${habitat.band.short}',
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: .66,
        color: Colors.white,
      ),
    );
    final tagW = tag.width + 20;
    final tagLeft = (t.dx + 24 + tagW > w) ? t.dx - 24 - tagW : t.dx + 24;
    final tagRect = Rect.fromLTWH(
      tagLeft.clamp(0.0, math.max(0.0, w - tagW)),
      t.dy -
          62, // above the solid-fuel row (mid − 25), so it never hides a mark
      tagW,
      24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
      Paint()..color = AppColors.red,
    );
    tag.paint(
      canvas,
      Offset(tagRect.left + 10, tagRect.center.dy - tag.height / 2),
    );

    // X tick labels
    final tick = AppText.mono.copyWith(fontSize: 11);
    for (final o2 in const [
      10.0,
      15.0,
      20.0,
      25.0,
      30.0,
      35.0,
      40.0,
      45.0,
      100.0,
    ]) {
      final p = _layout(fmtO2(o2), tick);
      p.paint(
        canvas,
        Offset((x(o2) - p.width / 2).clamp(0, w - p.width), plotH + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_GapMapPainter old) =>
      old.recs != recs ||
      old.zones.length != zones.length ||
      old.trained != trained ||
      old.marks != marks ||
      old.habitat != habitat;
}

TextPainter _layout(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout();

/// Strokes [path] as dashes (lines, rects and small circles alike).
void drawDashed(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 4,
  double gap = 3,
}) {
  paint.style = PaintingStyle.stroke;
  // One draw call for all dashes: a drawPath per dash froze CanvasKit on the web.
  final dashes = Path();
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      dashes.addPath(metric.extractPath(d, d + dash), Offset.zero);
    }
  }
  canvas.drawPath(dashes, paint);
}

/// 135° hatch every 8px: the "no data" fill.
void paintHatch(Canvas canvas, Rect r) {
  final lines = Path();
  for (var d = -r.height; d < r.width; d += 8) {
    lines
      ..moveTo(r.left + d, r.bottom)
      ..lineTo(r.left + d + r.height, r.top);
  }
  canvas.drawPath(
    lines,
    Paint()
      ..color = AppColors.secondary.withValues(alpha: .26)
      ..style = PaintingStyle.stroke,
  );
}

/// Fuel phase by shape + lightness: solid ● white, liquid ■ gray, gas ◇ outline.
void paintMark(Canvas canvas, Offset c, Fuel fuel, {bool partial = false}) {
  switch (fuel) {
    case Fuel.solid when partial:
      drawDashed(
        canvas,
        Path()..addOval(Rect.fromCircle(center: c, radius: 4.5)),
        Paint()..color = AppColors.text,
        dash: 2,
        gap: 1.5,
      );
    case Fuel.solid:
      canvas.drawCircle(c, 5, Paint()..color = AppColors.text);
    case Fuel.liquid:
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 9, height: 9),
        Paint()..color = AppColors.secondary,
      );
    case Fuel.gas:
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 6)
          ..lineTo(c.dx + 6, c.dy)
          ..lineTo(c.dx, c.dy + 6)
          ..lineTo(c.dx - 6, c.dy)
          ..close(),
        Paint()
          ..color = AppColors.text
          ..style = PaintingStyle.stroke,
      );
  }
}

/// Red ring with glow + center dot.
void paintTarget(Canvas canvas, Offset c, {required double ring}) {
  canvas
    ..drawCircle(
      c,
      ring,
      Paint()
        ..color = AppColors.red.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    )
    ..drawCircle(
      c,
      ring,
      Paint()
        ..color = AppColors.red
        ..style = PaintingStyle.stroke,
    )
    ..drawCircle(c, ring > 10 ? 3 : 0, Paint()..color = AppColors.red);
}

enum _Swatch { solid, liquid, gas, partial, noData, habitat, suggested, model }

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.kind);
  final _Swatch kind;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    switch (kind) {
      case _Swatch.solid:
        paintMark(canvas, c, Fuel.solid);
      case _Swatch.liquid:
        paintMark(canvas, c, Fuel.liquid);
      case _Swatch.gas:
        paintMark(canvas, c, Fuel.gas);
      case _Swatch.partial:
        paintMark(canvas, c, Fuel.solid, partial: true);
      case _Swatch.noData:
        final r = RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(3),
        );
        canvas
          ..save()
          ..clipRRect(r);
        paintHatch(canvas, r.outerRect);
        canvas.restore();
        drawDashed(
          canvas,
          Path()..addRRect(r),
          Paint()..color = AppColors.lineStrong,
          dash: 2,
          gap: 2,
        );
      case _Swatch.habitat:
        canvas.drawCircle(
          c,
          4.5,
          Paint()
            ..color = AppColors.red
            ..style = PaintingStyle.stroke,
        );
      case _Swatch.suggested:
        canvas.drawRect(
          Rect.fromCenter(center: c, width: 9, height: 9),
          Paint()
            ..color = AppColors.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case _Swatch.model:
        drawDashed(
          canvas,
          Path()..addRect(Rect.fromCenter(center: c, width: 14, height: 10)),
          Paint()..color = AppColors.textMuted,
          dash: 3,
          gap: 2,
        );
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.kind != kind;
}

// ───────────────────────── Aside ─────────────────────────

class _Aside extends StatelessWidget {
  const _Aside(this.h, this.marks, {required this.recs, required this.model});
  final Habitat h;
  final List<TestMark> marks;
  final List<Recommendation> recs;
  final ModelInfo? model;

  @override
  Widget build(BuildContext context) {
    int marksIn(GravityBand b) => gm.marksIn(marks, b);
    final count = seriesAtCondition(marks, h);
    final maxMarks = GravityBand.values
        .map(marksIn)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);
    final mono = AppText.mono.copyWith(color: AppColors.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        ChamferCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Text('GAP AT YOUR CONDITION', style: AppText.label),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 12,
                children: [
                  Text(
                    '$count',
                    style: AppText.dataXL.copyWith(
                      fontSize: 56,
                      height: 60 / 56,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'investigations within ±${gapWindow.round()} % O₂ ${h.band.phrase}',
                      style: AppText.body.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (count == 0)
                AppTag(
                  'UNVALIDATED ZONE',
                  mono: true,
                  level: TagLevel.high,
                  leading: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                AppTag(
                  count < 3 ? 'SPARSE EVIDENCE' : 'EVIDENCE PRESENT',
                  mono: true,
                ),
              const Divider(),
              Text('NEAREST EVIDENCE', style: AppText.label),
              for (final (m, delta) in nearestEvidence(marks, h))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            m.series,
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${fmtO2(m.o2)} % O₂ · ${m.band.short}',
                            style: AppText.mono.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      delta,
                      style: mono.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (model != null) _ModelCard(model!, blind: model!.blindSpots(h)),
        ChamferCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Text('SUGGESTED NEXT EXPERIMENTS', style: AppText.label),
              if (recs.isEmpty)
                Text('Loading the priority ranking…', style: AppText.caption)
              else ...[
                for (final (i, r) in recs.take(3).indexed)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.text, width: 1.5),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: AppText.mono.copyWith(
                            fontSize: 10,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              'Burn tests at ${fmtO2(r.o2)} % O₂ · ${r.band.short}',
                              style: AppText.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              r.why,
                              style: AppText.caption.copyWith(height: 17 / 12),
                            ),
                          ],
                        ),
                      ),
                      Text(r.priority.toStringAsFixed(2), style: mono),
                    ],
                  ),
                Text(
                  'Priority = data gap × closeness to habitat × model uncertainty.',
                  style: AppText.mono.copyWith(fontSize: 10),
                ),
                FilledButton(
                  onPressed: () {
                    final r = recs.first;
                    ProviderScope.containerOf(context)
                        .read(copilotProvider)
                        .ask(
                          'What would it take to validate flame spread at '
                          '${fmtO2(r.o2)} % O₂ ${r.band.phrase}?',
                        );
                    context.go('/copilot');
                  },
                  child: const Text('ASK COPILOT ABOUT THIS GAP'),
                ),
              ],
            ],
          ),
        ),
        ChamferCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text('MARKS PER GRAVITY LEVEL', style: AppText.label),
              for (final b in GravityBand.values)
                Row(
                  spacing: 12,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        b.label,
                        style: mono.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: MeterBar(
                        marksIn(b) / maxMarks,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${marksIn(b)}',
                        textAlign: TextAlign.right,
                        style: mono,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the flammability model can and can't say for this habitat. Its blind spots are
/// exactly where the suggested experiments point.
class _ModelCard extends ConsumerWidget {
  const _ModelCard(this.m, {required this.blind});
  final ModelInfo m;
  final List<String> blind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final physics = ref.watch(flameModelProvider).value;
    return ChamferCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text('FLAMMABILITY MODEL', style: AppText.label),
          if (physics != null)
            Text(
              'Physics model · n ${physics.n} · accuracy ${(physics.accuracy * 100).round()} %',
              style: AppText.mono.copyWith(color: AppColors.text),
            ),
          // The team's in-sample fit is ~100 %: label it as such instead of headlining it.
          Text(
            'Data model (logistic) · n ${m.n} · in-sample fit, not cross-validated',
            style: AppText.mono.copyWith(fontSize: 11),
          ),
          Text(
            'The data model has no gravity input: it only speaks for ISS microgravity. '
            'Outside that envelope the physics model forecasts, and we recommend testing '
            'instead of guessing.',
            style: AppText.caption.copyWith(
              fontSize: 13,
              height: 19 / 13,
              color: AppColors.textMuted,
            ),
          ),
          if (blind.isEmpty)
            const AppTag('IN TRAINING RANGE', mono: true)
          else ...[
            const AppTag('MODEL BLIND HERE', mono: true, level: TagLevel.high),
            for (final b in blind)
              Text('· $b', style: AppText.mono.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
