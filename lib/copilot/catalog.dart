import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:go_router/go_router.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../app/theme.dart';

/// The copilot's visual vocabulary. The model may only compose answers from these
/// components, so every answer renders in the Habitat Fire Atlas design system.
const copilotCatalogId = 'firestorm.copilot';

final copilotCatalog = Catalog(
  [
    _answerCard,
    _answerText,
    _flameSpreadChart,
    _sourceList,
    _actionBar,
    _coverageWarning,
    _riskCard,
    _dataChart,
  ],
  catalogId: copilotCatalogId,
  systemPromptFragments: [
    'Wrap every answer in one AnswerCard. Every claim in AnswerText must cite a '
        'SourceList entry by number.',
    'If the question falls outside PSI test coverage, put a CoverageWarning first '
        'and say so before answering.',
    'Use FlameSpreadChart only for values taken from cited PSI datasets.',
  ],
);

typedef _Json = Map<String, Object?>;
_Json _data(CatalogItemContext c) => c.data as _Json;
List<T> _list<T>(Object? v) => (v as List?)?.cast<T>() ?? <T>[];

// ───────────────────────── AnswerCard ─────────────────────────

final _answerCard = CatalogItem(
  name: 'AnswerCard',
  dataSchema: S.object(
    description: 'Container for one copilot turn: header, optional progress, child blocks.',
    properties: {
      'title': S.string(description: 'Header, e.g. "Copilot · answer".'),
      'tags': S.list(
        items: S.string(),
        description: 'Header chips, e.g. "3 sources".',
      ),
      'progress': S.number(
        description: '0..1 while searching; omit when done.',
      ),
      'children': A2uiSchemas.componentArrayReference(),
    },
    required: ['title', 'children'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final progress = (d['progress'] as num?)?.toDouble();
    return ChamferCard(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: progress == null ? 20 : 16,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  const BrandMark(size: 18),
                  Text(
                    (d['title'] as String).toUpperCase(),
                    style: AppText.label.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in _list<String>(d['tags']))
                    AppTag(t.toUpperCase(), mono: true),
                ],
              ),
            ],
          ),
          if (progress != null) _StripeProgress(progress),
          for (final id in _list<String>(d['children'])) c.buildChild(id),
        ],
      ),
    );
  },
);

/// Curb-stripe progress (red/white 5px) on a 3px track; animates between updates.
class _StripeProgress extends StatelessWidget {
  const _StripeProgress(this.value);
  final double value;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0, 1)),
    duration: const Duration(milliseconds: 400),
    builder: (context, v, _) => Semantics(
      label: 'Searching',
      value: '${(v * 100).round()} %',
      child: SizedBox(
        height: 3,
        child: CustomPaint(painter: _StripePainter(v)),
      ),
    ),
  );
}

class _StripePainter extends CustomPainter {
  const _StripePainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.line);
    final end = size.width * value;
    final red = Paint()..color = AppColors.red,
        white = Paint()..color = AppColors.text;
    for (var x = 0.0; x < end; x += 10) {
      canvas
        ..drawRect(Rect.fromLTRB(x, 0, (x + 5).clamp(0, end), size.height), red)
        ..drawRect(
          Rect.fromLTRB(x + 5, 0, (x + 10).clamp(0, end), size.height),
          white,
        );
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.value != value;
}

// ───────────────────────── AnswerText ─────────────────────────

final _answerText = CatalogItem(
  name: 'AnswerText',
  dataSchema: S.object(
    description: 'Grounded answer paragraph with an optional bold takeaway and citations.',
    properties: {
      'text': S.string(),
      'emphasis': S.string(
        description: 'One-sentence takeaway, rendered bold.',
      ),
      'citations': S.list(
        items: S.integer(),
        description: 'SourceList numbers (1-based).',
      ),
    },
    required: ['text'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final emphasis = d['emphasis'] as String?;
    return Text.rich(
      TextSpan(
        text: d['text'] as String,
        children: [
          if (emphasis != null)
            TextSpan(
              text: ' $emphasis',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          const TextSpan(text: ' '),
          for (final n in _list<int>(d['citations']))
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: CitationMark(n),
              ),
            ),
        ],
      ),
      style: AppText.body.copyWith(fontSize: 16, height: 26 / 16),
    );
  },
);

// ───────────────────────── FlameSpreadChart ─────────────────────────

final _flameSpreadChart = CatalogItem(
  name: 'FlameSpreadChart',
  dataSchema: S.object(
    description:
        'Horizontal bars of relative flame spread per material. Red = sustained flame, '
        'gray = self-extinguished.',
    properties: {
      'title': S.string(),
      'rows': S.list(
        items: S.object(
          properties: {
            'label': S.string(),
            'value': S.number(description: 'Relative spread 0..1.'),
            'sustained': S.boolean(),
          },
          required: ['label', 'value', 'sustained'],
        ),
      ),
      'note': S.string(description: 'Provenance footnote.'),
    },
    required: ['title', 'rows'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final legend = AppText.caption.copyWith(
      fontSize: 11,
      color: AppColors.textMuted,
    );
    Widget key(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        SizedBox(width: 10, height: 4, child: ColoredBox(color: color)),
        Text(label, style: legend),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.chip,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final labelW = (box.maxWidth * .3).clamp(80.0, 200.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    (d['title'] as String).toUpperCase(),
                    style: AppText.label,
                  ),
                  Wrap(
                    spacing: 14,
                    children: [
                      key(AppColors.red, 'Sustained'),
                      key(AppColors.secondary, 'Self-extinguished'),
                    ],
                  ),
                ],
              ),
              for (final r in _list<_Json>(d['rows']))
                Row(
                  spacing: 14,
                  children: [
                    SizedBox(
                      width: labelW,
                      child: Text(
                        r['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          fontSize: 13,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: MeterBar(
                          (r['value'] as num).toDouble(),
                          height: 8,
                          color: r['sustained'] == true
                              ? AppColors.red
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        (r['value'] as num).toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: AppText.mono.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              if (d['note'] case final String note)
                Text(note, style: AppText.mono.copyWith(fontSize: 10)),
            ],
          );
        },
      ),
    );
  },
);

// ───────────────────────── SourceList ─────────────────────────

final _sourceList = CatalogItem(
  name: 'SourceList',
  dataSchema: S.object(
    description: 'Numbered PSI records the answer cites. Numbers match AnswerText citations.',
    properties: {
      'sources': S.list(
        items: S.object(
          properties: {
            'title': S.string(),
            'ref': S.string(description: 'PSI investigation or dataset ID.'),
          },
          required: ['title', 'ref'],
        ),
      ),
    },
    required: ['sources'],
  ),
  widgetBuilder: (c) {
    final mono = AppText.mono.copyWith(fontSize: 13);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final (i, s) in _list<_Json>(_data(c)['sources']).indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              SizedBox(width: 28, child: Text('[${i + 1}]', style: mono)),
              Expanded(
                child: Text(
                  s['title'] as String,
                  style: AppText.caption.copyWith(
                    fontSize: 13,
                    height: 19 / 13,
                    color: AppColors.textSoft,
                  ),
                ),
              ),
              Text(s['ref'] as String, style: mono),
            ],
          ),
      ],
    );
  },
);

// ───────────────────────── ActionBar ─────────────────────────

final _actionBar = CatalogItem(
  name: 'ActionBar',
  dataSchema: S.object(
    description: 'Follow-up actions under an answer.',
    properties: {
      'actions': S.list(
        items: S.object(
          properties: {
            'label': S.string(),
            'action': S.string(
              enumValues: ['gapMap', 'ranking', 'report', 'copy'],
            ),
            'investigation': S.string(
              description: 'Investigation code, for the report action.',
            ),
          },
          required: ['label', 'action'],
        ),
      ),
      'copyText': S.string(
        description: 'Answer text with citations, for the copy action.',
      ),
    },
    required: ['actions'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    void run(_Json a) {
      final ctx = c.buildContext;
      switch (a['action']) {
        case 'gapMap':
          ctx.go('/gaps');
        case 'ranking':
          ctx.go('/ranking');
        case 'report':
          ctx.go('/report/${a['investigation'] ?? ''}');
        case 'copy':
          Clipboard.setData(
            ClipboardData(text: d['copyText'] as String? ?? ''),
          );
          ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
            const SnackBar(content: Text('Copied with citations')),
          );
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in _list<_Json>(d['actions']))
          OutlinedButton(
            onPressed: () => run(a),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: AppColors.textMuted,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: AppText.caption.copyWith(fontWeight: FontWeight.w500),
            ),
            child: Text(a['label'] as String),
          ),
      ],
    );
  },
);

// ───────────────────────── CoverageWarning ─────────────────────────

final _coverageWarning = CatalogItem(
  name: 'CoverageWarning',
  dataSchema: S.object(
    description: 'Shown first when the question is outside PSI test coverage.',
    properties: {'text': S.string()},
    required: ['text'],
  ),
  widgetBuilder: (c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.red),
      borderRadius: BorderRadius.circular(AppLayout.radius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.red,
          ),
        ),
        Expanded(
          child: Text(
            _data(c)['text'] as String,
            style: AppText.body.copyWith(fontSize: 14, height: 21 / 14),
          ),
        ),
      ],
    ),
  ),
);

// ───────────────────────── RiskCard (backend answer_card) ─────────────────────────

final _riskCard = CatalogItem(
  name: 'RiskCard',
  dataSchema: S.object(
    description: 'Rule-built finding. Red only for critical.',
    properties: {
      'title': S.string(),
      'body': S.string(),
      'level': S.string(enumValues: ['info', 'warning', 'critical']),
    },
    required: ['title', 'body', 'level'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final level = d['level'] as String;
    final critical = level == 'critical';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.chip,
        border: Border.all(
          color: critical
              ? AppColors.red
              : level == 'warning'
              ? AppColors.lineSelected
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  (d['title'] as String).toUpperCase(),
                  style: AppText.label,
                ),
              ),
              AppTag(
                level.toUpperCase(),
                mono: true,
                level: switch (level) {
                  'critical' => TagLevel.critical,
                  'warning' => TagLevel.high,
                  _ => TagLevel.neutral,
                },
              ),
            ],
          ),
          Text(
            d['body'] as String,
            style: AppText.body.copyWith(fontSize: 14, height: 21 / 14),
          ),
        ],
      ),
    );
  },
);

// ───────────────────────── DataChart (backend chart, fl_chart) ─────────────────────────

final _dataChart = CatalogItem(
  name: 'DataChart',
  dataSchema: S.object(
    description: 'Bar (category, value), scatter (x, y), or line (model curve, with measured points overlaid).',
    properties: {
      'kind': S.string(enumValues: ['bar', 'scatter', 'line']),
      'x': S.string(description: 'X axis label.'),
      'y': S.string(description: 'Y axis label.'),
      'points': S.list(
        items: S.list(description: '[x, y]; x is a category for bars.'),
      ),
      'measured': S.list(
        description: 'line only: measured [x, y] points drawn over the curve.',
        items: S.list(),
      ),
    },
    required: ['kind', 'x', 'y', 'points'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final points = _list<List>(d['points']);
    final bar = d['kind'] == 'bar';
    final tick = AppText.mono.copyWith(fontSize: 10);
    final axisName = AppText.label.copyWith(fontSize: 10);
    String fmt(double v) =>
        v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final measured = _list<List>(d['measured']);
    FlSpot spot(List p) =>
        FlSpot((p[0] as num).toDouble(), (p[1] as num).toDouble());
    final ys = [
      for (final p in [...points, ...measured]) (p[1] as num).toDouble(),
    ];
    final maxY = ys.isEmpty
        ? 1.0
        : (ys.reduce((a, b) => a > b ? a : b) * 1.15).ceilToDouble();

    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        axisNameWidget: Text(d['y'] as String, style: axisName),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          getTitlesWidget: (v, meta) => SideTitleWidget(
            meta: meta,
            child: Text(fmt(v), style: tick),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: Text(d['x'] as String, style: axisName),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: bar ? 36 : 22,
          interval: bar ? 1 : null,
          getTitlesWidget: (v, meta) => SideTitleWidget(
            meta: meta,
            child: bar
                ? SizedBox(
                    width: 64,
                    child: Text(
                      '${points[v.toInt()][0]}',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: tick,
                    ),
                  )
                : Text(fmt(v), style: tick),
          ),
        ),
      ),
    );
    final grid = FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: AppColors.grid, strokeWidth: 1),
    );
    final border = FlBorderData(
      show: true,
      border: const Border(
        left: BorderSide(color: AppColors.lineStrong),
        bottom: BorderSide(color: AppColors.lineStrong),
      ),
    );

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 18, 18, 8),
      decoration: BoxDecoration(
        color: AppColors.chip,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: Semantics(
        label:
            '${d['kind']} chart of ${d['y']} by ${d['x']}, ${points.length} points',
        child: bar
            ? BarChart(
                BarChartData(
                  maxY: maxY,
                  titlesData: titles,
                  gridData: grid,
                  borderData: border,
                  barTouchData: BarTouchData(enabled: false),
                  barGroups: [
                    for (final (i, y) in ys.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: y,
                            width: 14,
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            : d['kind'] == 'line'
            ? LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  titlesData: titles,
                  gridData: grid,
                  borderData: border,
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (final p in points) spot(p)],
                      color: AppColors.text,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    if (measured.isNotEmpty)
                      LineChartBarData(
                        spots: [for (final p in measured) spot(p)]
                          ..sort((a, b) => a.x.compareTo(b.x)),
                        barWidth: 0,
                        color: Colors.transparent,
                        dotData: FlDotData(
                          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.ground,
                            strokeColor: AppColors.textMuted,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : ScatterChart(
                ScatterChartData(
                  minY: 0,
                  maxY: maxY,
                  titlesData: titles,
                  gridData: grid,
                  borderData: border,
                  scatterTouchData: ScatterTouchData(enabled: false),
                  scatterSpots: [
                    for (final p in points)
                      ScatterSpot(
                        (p[0] as num).toDouble(),
                        (p[1] as num).toDouble(),
                        dotPainter: FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.ground,
                          strokeColor: AppColors.text,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  },
);
