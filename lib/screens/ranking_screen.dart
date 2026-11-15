import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/i18n.dart';
import '../app/page.dart';
import '../app/theme.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';

/// Step 03 · Evidence: PSI investigations ranked for the selected habitat, plus why the selected one ranks.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  Fuel? _fuel; // null = all
  String? _selected; // investigation id; null = top of the visible list

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(selectedHabitatProvider);
    final all = ref.watch(experimentsProvider).value;
    final visible = [
      for (final i in all ?? const <Investigation>[])
        if (_fuel == null || i.fuel == _fuel) i,
    ];
    final selected =
        visible.where((i) => i.id == _selected).firstOrNull ??
        visible.firstOrNull;

    return PageBody(
      gap: 28,
      children: [
        PageIntro(
          step: tr('STEP 03 · EVIDENCE', 'PASO 03 · EVIDENCIA'),
          title: tr('INVESTIGATION RANKING', 'RANKING DE INVESTIGACIONES'),
          description: TextSpan(
            text: tr(
              'PSI investigations ordered by how well their test conditions, fuels and safety '
                  'domain transfer to ',
              'Investigaciones PSI ordenadas según cuánto se transfieren sus condiciones de ensayo, '
                  'combustibles y dominio de seguridad a ',
            ),
            children: [
              TextSpan(
                text:
                    '${h.name} · ${h.o2.toStringAsFixed(0)} % O₂ · ${h.pressure} psi · '
                    '${h.gravityLabel} g',
                style: const TextStyle(color: AppColors.text),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          trailing: _FuelFilter(
            value: _fuel,
            onChanged: (f) => setState(() => _fuel = f),
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            if (all == null) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.text),
                ),
              );
            }
            final table = _Table(
              rows: visible,
              all: all,
              selected: selected,
              onSelect: (i) => setState(() => _selected = i.id),
            );
            final why = selected == null
                ? const SizedBox.shrink()
                : _WhyPanel(selected, rank: _rank(all, selected));
            return box.maxWidth >= 1000
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 24,
                    children: [
                      Expanded(child: table),
                      SizedBox(width: 360, child: why),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [table, why],
                  );
          },
        ),
      ],
    );
  }
}

String _rank(List<Investigation> all, Investigation i) =>
    (all.indexOf(i) + 1).toString().padLeft(2, '0');

class _FuelFilter extends StatelessWidget {
  const _FuelFilter({required this.value, required this.onChanged});
  final Fuel? value;
  final ValueChanged<Fuel?> onChanged;

  static List<(String, Fuel?)> get _options => [
    (tr('All', 'Todos'), null),
    (tr('Solid', 'Sólido'), Fuel.solid),
    (tr('Liquid', 'Líquido'), Fuel.liquid),
    ('Gas', Fuel.gas),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    spacing: 10,
    children: [
      Text(tr('FUEL TYPE', 'TIPO DE COMBUSTIBLE'), style: AppText.label),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (label, fuel) in _options)
            ToggleChip(
              label,
              selected: value == fuel,
              accent: true,
              semanticLabel: tr('$label fuel', 'Combustible $label'),
              onTap: () => onChanged(fuel),
            ),
        ],
      ),
    ],
  );
}

class _Table extends StatelessWidget {
  const _Table({
    required this.rows,
    required this.all,
    required this.selected,
    required this.onSelect,
  });
  final List<Investigation> rows, all;
  final Investigation? selected;
  final ValueChanged<Investigation> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 640;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _Cells(
              compact: compact,
              rank: Text(tr('RANK', 'PUESTO'), style: AppText.label),
              investigation: Text(
                tr('INVESTIGATION', 'INVESTIGACIÓN'),
                style: AppText.label,
              ),
              fuel: Text(
                tr('FUEL · DOMAIN', 'COMBUSTIBLE · DOMINIO'),
                style: AppText.label,
              ),
              conditions: Text(
                tr('TEST CONDITIONS', 'CONDICIONES DE ENSAYO'),
                style: AppText.label,
              ),
              relevance: Text(
                tr('RELEVANCE', 'RELEVANCIA'),
                style: AppText.label,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          for (final i in rows)
            _Row(
              i,
              rank: _rank(all, i),
              compact: compact,
              selected: i == selected,
              onTap: () => onSelect(i),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Text(
              tr(
                'Condition ranges from the FireStorm API · verify against PSI metadata.',
                'Rangos de condiciones de la API de FireStorm · verificar con los metadatos PSI.',
              ),
              style: AppText.mono.copyWith(fontSize: 11),
            ),
          ),
        ],
      );
    },
  );
}

/// Column layout shared by header and rows (CSS grid → Row). Compact drops fuel and conditions.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.compact,
    required this.rank,
    required this.investigation,
    required this.fuel,
    required this.conditions,
    required this.relevance,
  });
  final bool compact;
  final Widget rank, investigation, fuel, conditions, relevance;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 20,
    children: [
      SizedBox(width: compact ? 44 : 56, child: rank),
      Expanded(flex: 5, child: investigation),
      if (!compact) ...[
        Expanded(flex: 4, child: fuel),
        Expanded(flex: 3, child: conditions),
      ],
      SizedBox(width: compact ? 90 : 150, child: relevance),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row(
    this.i, {
    required this.rank,
    required this.compact,
    required this.selected,
    required this.onTap,
  });
  final Investigation i;
  final String rank;
  final bool compact, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mono12 = AppText.mono.copyWith(color: AppColors.textMuted);
    return Tappable(
      selected: selected,
      label: tr(
        '${i.code}, relevance ${i.score}',
        '${i.code}, relevancia ${i.score}',
      ),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              decoration: BoxDecoration(
                color: selected ? AppColors.card : AppColors.chip,
                border: Border.all(
                  color: selected ? AppColors.lineSelected : AppColors.line,
                ),
                borderRadius: BorderRadius.circular(AppLayout.radius),
              ),
              child: _Cells(
                compact: compact,
                rank: Text(rank, style: AppText.data.copyWith(fontSize: 26)),
                investigation: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      i.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h2.copyWith(
                        fontSize: 15,
                        letterSpacing: 2.1,
                      ),
                    ),
                    Text(
                      i.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
                fuel: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppTag(i.fuelLabel, leading: FuelMarker(i.fuel)),
                    AppTag(i.domain),
                  ],
                ),
                conditions: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      'O₂ ${i.o2Range} %',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mono12,
                    ),
                    Text(
                      '${i.pressureRange} psi · ${i.gravity}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono,
                    ),
                  ],
                ),
                relevance: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 7,
                  children: [
                    Text(
                      '${i.score}',
                      textAlign: TextAlign.right,
                      style: AppText.data.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    MeterBar(i.score / 100, height: 4, color: AppColors.text),
                  ],
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.red, AppColors.redDeep],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhyPanel extends StatelessWidget {
  const _WhyPanel(this.i, {required this.rank});
  final Investigation i;
  final String rank;

  @override
  Widget build(BuildContext context) {
    final soft = AppText.body.copyWith(
      fontSize: 14,
      height: 23 / 14,
      color: AppColors.textSoft,
    );
    return ChamferCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  tr('WHY THIS RANKS HERE', 'POR QUÉ ESTÁ AQUÍ'),
                  style: AppText.label,
                ),
              ),
              AppTag(tr('DATA · GROUNDED', 'BASADO EN DATOS'), mono: true),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 16,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text('#$rank', style: AppText.mono),
                    Text(
                      i.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.h2.copyWith(
                        fontSize: 22,
                        letterSpacing: 3.08,
                        height: 30 / 22,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${i.score}',
                style: AppText.dataXL.copyWith(fontSize: 44, height: 48 / 44),
              ),
            ],
          ),
          const LiverySweep(width: 140),
          if (i.rationale == null)
            Text(
              tr(
                'Rationale not generated yet. It is built only from linked PSI records.',
                'Justificación aún no generada. Se construye solo a partir de registros PSI vinculados.',
              ),
              style: soft.copyWith(color: AppColors.secondary),
            )
          else
            Text.rich(
              TextSpan(
                text: '${i.rationale} ',
                style: soft,
                children: [
                  for (var n = 1; n <= i.sources.length; n++)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: CitationMark(n),
                      ),
                    ),
                ],
              ),
            ),
          if (i.factors.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Text(
                  tr('SCORE FACTORS', 'FACTORES DE PUNTUACIÓN'),
                  style: AppText.label,
                ),
                for (final f in i.factors)
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          f.label,
                          style: AppText.caption.copyWith(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: MeterBar(
                          f.value,
                          height: 3,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          f.value.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: AppText.mono.copyWith(color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          const Divider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(tr('SOURCES', 'FUENTES'), style: AppText.label),
              for (final (n, s) in i.sources.indexed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '[${n + 1}]',
                        style: AppText.mono.copyWith(fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: s.title,
                          children: [
                            TextSpan(
                              text: s.description.isEmpty
                                  ? ' '
                                  : ' — ${s.description} ',
                            ),
                            TextSpan(
                              text: s.ref,
                              style: AppText.mono.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                        style: AppText.caption.copyWith(
                          fontSize: 13,
                          height: 19 / 13,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          OutlinedButton(
            onPressed: () => context.go('/report/${i.code}'),
            child: Text(tr('OPEN REPORT', 'ABRIR REPORTE')),
          ),
          Text(
            tr(
              'Rationale is generated only from linked PSI records. Check sources before design '
                  'decisions.',
              'La justificación se genera solo a partir de registros PSI vinculados. Revisa las fuentes '
                  'antes de tomar decisiones de diseño.',
            ),
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
