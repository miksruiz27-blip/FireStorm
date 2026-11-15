import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app/i18n.dart';
import '../data/gap_map.dart' show fmtO2;
import '../data/habitats.dart';
import '../data/investigations.dart';
import '../data/reports.dart';

// Print palette: the app's livery on white paper. Red stays semantic (risk, the habitat line).
const _ink = PdfColor.fromInt(0xFF0E0E10);
const _muted = PdfColor.fromInt(0xFF5C5F66);
const _rule = PdfColor.fromInt(0xFFD9DADC);
const _panel = PdfColor.fromInt(0xFFF4F4F2);
const _red = PdfColor.fromInt(0xFFD5001C);
const _slate = PdfColor.fromInt(0xFF1E2A38);
const _series = [
  _ink,
  PdfColor.fromInt(0xFF6E7176),
  PdfColor.fromInt(0xFFAEB0B5),
];

Future<pw.Font> _font(String file) async =>
    pw.Font.ttf(await rootBundle.load('assets/fonts/$file'));

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// The investigation report as a print-ready PDF (A4 by default) in the current language.
Future<Uint8List> buildReportPdf({
  required Investigation i,
  required Report? r,
  required Habitat h,
  required int rank,
  required List<String> findings,
  PdfPageFormat format = PdfPageFormat.a4,
  DateTime? now,
}) async {
  final [regular, bold, mono, display, fallback] = await Future.wait([
    _font('Inter-Regular.ttf'),
    _font('Inter-SemiBold.ttf'),
    _font('JetBrainsMono-Regular.ttf'),
    _font('Michroma-Regular.ttf'),
    _font('DejaVuSans.ttf'), // ₂, μ, ≥, ≈: glyphs the brand fonts lack
  ]);
  final generated = _stamp(now ?? DateTime.now());

  pw.TextStyle st(
    double size, {
    pw.Font? font,
    PdfColor color = _ink,
    double? spacing,
  }) => pw.TextStyle(
    font: font ?? regular,
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    lineSpacing: size * .35,
    fontFallback: [fallback],
  );
  final label = st(7.5, font: bold, color: _muted, spacing: 1.2);
  final body = st(10);
  final small = st(8, color: _muted);
  final monoS = st(8.5, font: mono);

  /// Section heading kept on the same page as its first item; later items may flow onto the next.
  List<pw.Widget> section(String title, List<pw.Widget> items) => [
    pw.Inseparable(
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 4),
              margin: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _rule, width: .8),
                ),
              ),
              child: pw.Text(title.toUpperCase(), style: label),
            ),
            ?items.firstOrNull,
          ],
        ),
      ),
    ),
    ...items.skip(1),
  ];

  pw.Widget tag(String text, {PdfColor color = _ink}) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color, width: .7),
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: pw.Text(
      text.toUpperCase(),
      style: st(7, font: bold, color: color, spacing: .8),
    ),
  );

  pw.Widget kv(List<(String, String)> rows) => pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: .5),
      bottom: pw.BorderSide(color: _rule, width: .5),
    ),
    children: [
      for (final (k, v) in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(k, style: small),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(v, style: monoS, textAlign: pw.TextAlign.right),
            ),
          ],
        ),
    ],
  );

  List<pw.Widget> numbered(List<String> items, {bool bullets = false}) => [
    for (final (n, s) in items.indexed)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 7),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 22,
              child: bullets
                  ? pw.Align(
                      alignment: pw.Alignment.topLeft,
                      child: pw.Container(
                        margin: const pw.EdgeInsets.only(top: 4.5),
                        width: 4,
                        height: 4,
                        color: _red,
                      ),
                    )
                  : pw.Text(
                      '${n + 1}'.padLeft(2, '0'),
                      style: st(9, font: mono, color: _muted),
                    ),
            ),
            pw.Expanded(child: pw.Text(s, style: body)),
          ],
        ),
      ),
  ];

  final conditions = [
    (tr('Oxygen', 'Oxígeno'), '${i.o2Range} %'),
    (tr('Pressure', 'Presión'), '${i.pressureRange} psi'),
    if (i.flowRange.isNotEmpty)
      (tr('Flow velocity', 'Velocidad de flujo'), '${i.flowRange} cm/s'),
    (tr('Gravity', 'Gravedad'), i.gravity),
    if (i.materials.isNotEmpty)
      (tr('Materials', 'Materiales'), i.materials.join(' · ')),
  ];

  final doc = pw.Document(
    title:
        '${i.code} · ${tr('Investigation report', 'Reporte de investigación')}',
    author: 'FireStorm',
    creator: 'FireStorm',
    subject: '${i.title} · ${h.name}',
    keywords: 'NASA PSI, ${i.code}, ${h.name}',
  );

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40),
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
          fontFallback: [fallback],
        ),
      ),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 18),
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _red, width: 1.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FIRESTORM',
                  style: st(9, font: display, spacing: 1.6),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  tr(
                    'NASA PSI · MICROGRAVITY COMBUSTION',
                    'NASA PSI · COMBUSTIÓN EN MICROGRAVEDAD',
                  ),
                  style: st(6.5, font: bold, color: _muted, spacing: 1),
                ),
              ],
            ),
            pw.Text(
              '${tr('INVESTIGATION REPORT', 'REPORTE DE INVESTIGACIÓN')} · ${i.code}',
              style: st(7.5, font: bold, color: _muted, spacing: 1),
            ),
          ],
        ),
      ),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _rule, width: .5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${tr('Generated', 'Generado')} $generated · '
              '${tr('Source: NASA Physical Science Informatics (PSI)', 'Fuente: NASA Physical Science Informatics (PSI)')}',
              style: st(7, color: _muted),
            ),
            pw.Text(
              tr(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              ),
              style: st(7, font: mono, color: _muted),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        // ── Title block + relevance
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '#${rank.toString().padLeft(2, '0')}   ${(r?.platform ?? i.platform).toUpperCase()}',
                    style: st(8, font: bold, color: _muted, spacing: 1),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(i.code, style: st(26, font: display, spacing: 3)),
                  pw.SizedBox(height: 6),
                  pw.Container(width: 120, height: 2.5, color: _red),
                  pw.SizedBox(height: 8),
                  pw.Text(i.title, style: st(11, color: _muted)),
                  pw.SizedBox(height: 8),
                  pw.Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      tag(
                        tr(
                          '${i.fuelLabel} fuel',
                          'Combustible ${i.fuelLabel.toLowerCase()}',
                        ),
                      ),
                      for (final d in i.domains) tag(d),
                      if (i.sources.isNotEmpty)
                        tag(i.sources.first.ref, color: _muted),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Container(
              width: 150,
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: _slate),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    tr('RELEVANCE', 'RELEVANCIA'),
                    style: st(
                      7,
                      font: bold,
                      color: PdfColors.grey300,
                      spacing: 1.2,
                    ),
                  ),
                  pw.Text(
                    '${i.score}',
                    style: st(30, font: mono, color: PdfColors.white),
                  ),
                  pw.Text(
                    '/ 100 · ${h.name}',
                    style: st(7.5, color: PdfColors.grey300),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(height: .5, color: PdfColors.grey600),
                  pw.SizedBox(height: 6),
                  for (final (k, v) in [
                    ('O₂', '${fmtO2(h.o2)} %'),
                    (tr('Pressure', 'Presión'), '${h.pressureLabel} psi'),
                    (tr('Gravity', 'Gravedad'), '${h.gravityLabel} g'),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(k, style: st(7.5, color: PdfColors.grey300)),
                          pw.Text(
                            v,
                            style: st(7.5, font: mono, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${tr('FLAMMABILITY', 'INFLAMABILIDAD')} · ${h.riskLabel}',
                    style: st(
                      7,
                      font: bold,
                      color: h.risk.index > 0
                          ? const PdfColor.fromInt(0xFFFF6B7A)
                          : PdfColors.white,
                      spacing: .8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (r != null)
          ...section(tr('Objective', 'Objetivo'), [
            pw.Text(r.objective, style: body),
          ]),
        if (r != null)
          ...section(
            tr(
              'Flame spread rate vs oxygen',
              'Velocidad de propagación vs oxígeno',
            ),
            [_chart(r, h, st, small)],
          ),

        ...section(
          tr('Key findings', 'Hallazgos clave'),
          findings.isEmpty
              ? [
                  pw.Text(
                    tr(
                      'Report not generated yet. It is built only from linked PSI records.',
                      'Reporte aún no generado. Se construye solo a partir de registros PSI vinculados.',
                    ),
                    style: body,
                  ),
                ]
              : numbered(findings),
        ),
        if (i.modifications.isNotEmpty)
          ...section(
            tr('Required modifications', 'Modificaciones requeridas'),
            numbered(i.modifications, bullets: true),
          ),

        if (i.rationale != null)
          ...section(tr('Why this ranks here', 'Por qué está en este puesto'), [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: _panel,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(i.rationale!, style: body),
                  if (i.factors.isNotEmpty) pw.SizedBox(height: 8),
                  for (final f in i.factors)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(
                            width: 130,
                            child: pw.Text(f.label, style: small),
                          ),
                          pw.Container(
                            width: 160,
                            height: 4,
                            color: _rule,
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Container(
                              width: 160 * f.value.clamp(0.0, 1.0),
                              color: _ink,
                            ),
                          ),
                          pw.Spacer(),
                          pw.SizedBox(
                            width: 34,
                            child: pw.Text(
                              f.value.toStringAsFixed(2),
                              style: monoS,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ]),

        // ── Test sheet: conditions + hardware side by side
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: section(
                  tr('Test conditions', 'Condiciones de ensayo'),
                  [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        kv(conditions),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          tr(
                            'Verify each value against PSI metadata.',
                            'Verifica cada valor con los metadatos PSI.',
                          ),
                          style: st(7, font: mono, color: _muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: section('Hardware', [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        i.hardware.isEmpty ? (r?.hardware ?? '–') : i.hardware,
                        style: st(10, font: bold),
                      ),
                      if (r != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(r.hardwareNote, style: small),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${tr('Fuel sample geometry', 'Geometría de la muestra')}: '
                          '${r.geometries.map((g) => g.label).join(' · ')}',
                          style: small,
                        ),
                      ],
                      if (i.researchGroup.isNotEmpty) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          '${tr('Research group', 'Grupo de investigación')}: ${i.researchGroup}',
                          style: small,
                        ),
                      ],
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
        if (r != null) ...section(tr('Sensors', 'Sensores'), [kv(r.sensors)]),

        if (i.sources.isNotEmpty)
          ...section(tr('Sources', 'Fuentes'), [
            for (final (n, s) in i.sources.indexed)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 22,
                      child: pw.Text(
                        '[${n + 1}]',
                        style: st(8.5, font: mono, color: _muted),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${s.title}  ·  ${s.ref}', style: st(9)),
                          if (s.description.startsWith('http'))
                            pw.UrlLink(
                              destination: s.description,
                              child: pw.Text(
                                s.description,
                                style: st(7.5, font: mono, color: _red)
                                    .copyWith(
                                      decoration: pw.TextDecoration.underline,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),

        pw.SizedBox(height: 18),
        pw.Text(
          tr(
            'Content is generated only from linked NASA PSI records and the FireStorm '
                'physics model. Check sources before design decisions.',
            'El contenido se genera solo a partir de registros NASA PSI vinculados y del modelo físico '
                'de FireStorm. Revisa las fuentes antes de tomar decisiones de diseño.',
          ),
          style: st(7.5, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Same plot as the screen: measured series per flow, dashed extrapolation, red habitat O₂ line.
pw.Widget _chart(
  Report r,
  Habitat h,
  pw.TextStyle Function(
    double, {
    pw.Font? font,
    PdfColor color,
    double? spacing,
  })
  st,
  pw.TextStyle small,
) {
  final axis = st(7.5, color: _muted);
  final last = r.series.first.points.last;
  final ho2 = h.o2.clamp(15.0, 40.0);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        tr(
          'Thin solid fuel, opposed flow · by flow velocity',
          'Combustible sólido delgado, flujo opuesto · por velocidad de flujo',
        ),
        style: small,
      ),
      pw.SizedBox(height: 8),
      pw.SizedBox(
        height: 190,
        child: pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis(
              [15, 20, 25, 30, 35, 40],
              textStyle: axis,
              divisions: true,
              divisionsColor: _rule,
            ),
            yAxis: pw.FixedAxis(
              [0, 2, 4, 6, 8],
              textStyle: axis,
              divisions: true,
              divisionsColor: _rule,
            ),
          ),
          datasets: [
            pw.LineDataSet(
              legend: tr('Extrapolated', 'Extrapolado'),
              drawPoints: false,
              color: _rule,
              lineWidth: 1.5,
              data: [
                pw.PointChartValue(last.$1, last.$2),
                pw.PointChartValue(r.extrapolateTo.$1, r.extrapolateTo.$2),
              ],
            ),
            for (final (n, s) in r.series.indexed)
              pw.LineDataSet(
                legend: s.label,
                color: _series[n % _series.length],
                lineWidth: 1.6,
                pointSize: 2.5,
                data: [for (final (x, y) in s.points) pw.PointChartValue(x, y)],
              ),
            pw.LineDataSet(
              legend: '${h.name} · ${fmtO2(h.o2)} % O₂',
              drawPoints: false,
              color: _red,
              lineWidth: 1.2,
              data: [pw.PointChartValue(ho2, 0), pw.PointChartValue(ho2, 8)],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Wrap(
            spacing: 12,
            children: [
              for (final (n, s) in r.series.indexed)
                _key(_series[n % _series.length], s.label, small),
              _key(_rule, tr('Extrapolated', 'Extrapolado'), small),
              _key(_red, h.name, small),
            ],
          ),
          pw.Text(
            tr(
              'X · O₂ (% vol)   Y · spread (mm/s)',
              'X · O₂ (% vol)   Y · propagación (mm/s)',
            ),
            style: axis,
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        tr(
          'Sample values · bind to PSI dataset [ID]',
          'Valores de muestra · vincular al dataset PSI [ID]',
        ),
        style: st(7, color: _muted),
      ),
    ],
  );
}

pw.Widget _key(PdfColor c, String label, pw.TextStyle style) => pw.Row(
  mainAxisSize: pw.MainAxisSize.min,
  children: [
    pw.Container(width: 10, height: 2, color: c),
    pw.SizedBox(width: 4),
    pw.Text(label, style: style),
  ],
);
