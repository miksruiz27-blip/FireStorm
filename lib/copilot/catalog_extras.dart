part of 'catalog.dart';

// ───────────────────────── MetricTiles (backend metrics) ─────────────────────────

final _metricTiles = CatalogItem(
  name: 'MetricTiles',
  dataSchema: S.object(
    description:
        'Key numbers of the physics forecast as tiles. Red only for critical.',
    properties: {
      'items': S.list(
        items: S.object(
          properties: {
            'label': S.string(),
            'value': S.string(),
            'unit': S.string(),
            'level': S.string(enumValues: ['info', 'warning', 'critical']),
          },
          required: ['label', 'value', 'unit'],
        ),
      ),
    },
    required: ['items'],
  ),
  widgetBuilder: (c) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final i in _list<_Json>(_data(c)['items']))
        Container(
          constraints: const BoxConstraints(minWidth: 118),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.chip,
            border: Border.all(
              color: i['level'] == 'critical' ? AppColors.red : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(AppLayout.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text((i['label'] as String).toUpperCase(), style: AppText.label),
              DataValue(
                i['value'] as String,
                i['unit'] as String,
                size: 22,
                unitSize: 11,
              ),
            ],
          ),
        ),
    ],
  ),
);

// ───────────────────────── ComparisonTable (backend table) ─────────────────────────

final _comparisonTable = CatalogItem(
  name: 'ComparisonTable',
  dataSchema: S.object(
    description: 'Rule-built comparison, e.g. fire risk per ambient. One highlighted row.',
    properties: {
      'title': S.string(),
      'columns': S.list(items: S.string()),
      'rows': S.list(items: S.list(items: S.string())),
      'highlight': S.integer(
        description: 'Row index to highlight (current ambient).',
      ),
    },
    required: ['title', 'columns', 'rows'],
  ),
  widgetBuilder: (c) {
    final d = _data(c);
    final hl = (d['highlight'] as num?)?.toInt();
    final cell = AppText.mono.copyWith(fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text((d['title'] as String).toUpperCase(), style: AppText.label),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            columnSpacing: 20,
            horizontalMargin: 12,
            border: const TableBorder(
              horizontalInside: BorderSide(color: AppColors.line),
              top: BorderSide(color: AppColors.line),
              bottom: BorderSide(color: AppColors.line),
            ),
            columns: [
              for (final col in _list<String>(d['columns']))
                DataColumn(
                  label: Text(col.toUpperCase(), style: AppText.label),
                ),
            ],
            rows: [
              for (final (i, r) in _list<List>(d['rows']).indexed)
                DataRow(
                  color: WidgetStatePropertyAll(
                    i == hl ? AppColors.redDeep : null,
                  ),
                  cells: [for (final v in r) DataCell(Text('$v', style: cell))],
                ),
            ],
          ),
        ),
      ],
    );
  },
);

// ───────────────────────── NextTests (backend next_tests) ─────────────────────────

final _nextTests = CatalogItem(
  name: 'NextTests',
  dataSchema: S.object(
    description: 'Suggested next experiments: priority = data gap × closeness × model uncertainty.',
    properties: {
      'items': S.list(
        items: S.object(
          properties: {
            'title': S.string(),
            'priority': S.number(),
            'body': S.string(),
          },
          required: ['title', 'priority', 'body'],
        ),
      ),
    },
    required: ['items'],
  ),
  widgetBuilder: (c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Text(
        tr('SUGGESTED NEXT EXPERIMENTS', 'PRÓXIMOS EXPERIMENTOS SUGERIDOS'),
        style: AppText.label,
      ),
      for (final (n, i) in _list<_Json>(_data(c)['items']).indexed)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppLayout.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 10,
                children: [
                  Text(
                    '${n + 1}',
                    style: AppText.data.copyWith(color: AppColors.red),
                  ),
                  Expanded(
                    child: Text(i['title'] as String, style: AppText.data),
                  ),
                  Text(
                    'P ${(i['priority'] as num).toDouble().toStringAsFixed(2)}',
                    style: AppText.mono.copyWith(fontSize: 11),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (i['priority'] as num).toDouble().clamp(0, 1),
                  minHeight: 3,
                  color: AppColors.red,
                  backgroundColor: AppColors.line,
                ),
              ),
              Text(
                i['body'] as String,
                style: AppText.body.copyWith(
                  fontSize: 13,
                  height: 19 / 13,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
    ],
  ),
);

// ───────────────────────── FollowUps (backend follow_ups) ─────────────────────────

final _followUps = CatalogItem(
  name: 'FollowUps',
  dataSchema: S.object(
    description: 'Follow-up questions; tapping one asks the copilot.',
    properties: {'questions': S.list(items: S.string())},
    required: ['questions'],
  ),
  widgetBuilder: (c) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final q in _list<String>(_data(c)['questions']))
        ActionChip(
          avatar: const Icon(
            Icons.subdirectory_arrow_right,
            size: 16,
            color: AppColors.red,
          ),
          label: Text(
            q,
            style: AppText.caption.copyWith(color: AppColors.text),
          ),
          backgroundColor: AppColors.chip,
          side: const BorderSide(color: AppColors.line),
          onPressed: () => ProviderScope.containerOf(
            c.buildContext,
            listen: false,
          ).read(copilotProvider).ask(q),
        ),
    ],
  ),
);
