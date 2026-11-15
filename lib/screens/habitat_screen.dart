import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/page.dart';
import '../app/theme.dart';
import '../data/gap_map.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';

/// Step 01 · Mission context: pick the habitat every other screen calibrates to.
class HabitatScreen extends ConsumerWidget {
  const HabitatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedHabitatProvider);

    return PageBody(
      children: [
        PageIntro(
          step: 'STEP 01 · MISSION CONTEXT',
          title: 'SELECT HABITAT',
          description: const TextSpan(
            text:
                'Pick the pressurized environment. Every ranking, data gap and copilot answer '
                'recalibrates to its atmosphere.',
          ),
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/ranking'),
                child: const Text('VIEW RANKING'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/gaps'),
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('ANALYZE HABITAT'),
              ),
            ],
          ),
        ),
        _Grid(
          minWidth: 260,
          maxCols: 4,
          children: [
            for (final h in habitats)
              _HabitatCard(
                h,
                selected: h == selected,
                onTap: () =>
                    ref.read(selectedHabitatProvider.notifier).select(h),
              ),
          ],
        ),
        Builder(
          builder: (context) {
            // From the API (snapshot offline): ranking, test coverage at this condition.
            final ranked = ref.watch(experimentsProvider).value;
            final marks = ref.watch(testMarksProvider).value;
            final series = marks == null
                ? null
                : seriesAtCondition(marks, selected);
            final top = ranked?.firstOrNull;
            final big = AppText.h2.copyWith(
              fontSize: 18,
              letterSpacing: 2.52,
              height: 34 / 18,
            );
            return _Grid(
              minWidth: 280,
              maxCols: 3,
              children: [
                _Stat(
                  'RELEVANT INVESTIGATIONS',
                  Text(
                    ranked == null
                        ? '–'
                        : '${ranked.where((i) => i.score >= 50).length} / ${ranked.length}',
                    style: AppText.data.copyWith(fontSize: 28),
                  ),
                  'Relevance ≥ 50 for this atmosphere',
                ),
                _Stat(
                  'DATA COVERAGE AT CONDITION',
                  Text(switch (series) {
                    null => '–',
                    0 => 'EMPTY',
                    < 3 => 'SPARSE',
                    _ => 'DENSE',
                  }, style: big),
                  series == null
                      ? 'See Data Gap Map for empty zones'
                      : '$series series within ±${gapWindow.round()} % O₂ ${selected.band.phrase}',
                ),
                _Stat(
                  'TOP-RANKED EVIDENCE',
                  Text(top?.code ?? '–', style: big),
                  top == null
                      ? 'From the PSI ranking'
                      : '${top.fuelLabel} fuel · ${top.domain} · relevance ${top.score}',
                ),
              ],
            );
          },
        ),
        const _Footer(),
      ],
    );
  }
}

class _HabitatCard extends StatelessWidget {
  const _HabitatCard(this.h, {required this.selected, required this.onTap});
  final Habitat h;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 18);
    return Tappable(
      selected: selected,
      label: h.name,
      onTap: onTap,
      child: SizedBox(
        height: 392,
        child: ChamferCard(
          selected: selected,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(h.code, style: AppText.mono),
                  const SizedBox(width: 10),
                  Expanded(child: Text(h.zone, style: AppText.label)),
                  AppTag(h.riskLabel, mono: true, level: h.risk),
                ],
              ),
              gap,
              Text(
                h.name.toUpperCase(),
                style: AppText.h2,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                h.blurb,
                style: AppText.caption.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              gap,
              const Divider(),
              gap,
              Text('OXYGEN', style: AppText.label),
              const SizedBox(height: 2),
              DataValue(h.o2Label, '% O₂', size: 40, unitSize: 16),
              gap,
              Row(
                children: [
                  Expanded(child: _Metric('PRESSURE', h.pressureLabel, 'psi')),
                  const SizedBox(width: 16),
                  Expanded(child: _Metric('GRAVITY', h.gravityLabel, 'g')),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('O₂ ENVELOPE', style: AppText.label),
                  Text('0 — 100 %', style: AppText.mono.copyWith(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              _EnvelopeBar(h.o2 / 100),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.unit);
  final String label, value, unit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.label),
      const SizedBox(height: 2),
      DataValue(value, unit, size: 20),
    ],
  );
}

/// 0–100 % track with curb-striped ends and a white tick at the habitat's O₂.
class _EnvelopeBar extends StatelessWidget {
  const _EnvelopeBar(this.fraction);
  final double fraction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SizedBox(
      height: 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.line)),
          const Positioned(left: 0, child: CurbStripe.cap),
          const Positioned(right: 0, child: CurbStripe.cap),
          Positioned(
            left: (box.maxWidth - 2) * fraction.clamp(0.0, 1.0),
            top: -6,
            child: const SizedBox(
              width: 2,
              height: 16,
              child: ColoredBox(color: AppColors.text),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.caption);
  final String label, caption;
  final Widget value;

  @override
  Widget build(BuildContext context) => ChamferCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 8),
        value,
        const SizedBox(height: 8),
        Text(caption, style: AppText.caption.copyWith(fontSize: 13)),
      ],
    ),
  );
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 8),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(
          'SOURCE · NASA PHYSICAL SCIENCE INFORMATICS (PSI)',
          style: AppText.label,
        ),
        Text(
          'Atmospheres: design values · verify before mission use',
          style: AppText.mono.copyWith(fontSize: 11),
        ),
      ],
    ),
  );
}

/// Equal-width columns that drop to fewer as the screen narrows (CSS grid → Wrap).
class _Grid extends StatelessWidget {
  const _Grid({
    required this.minWidth,
    required this.maxCols,
    required this.children,
  });
  final double minWidth;
  final int maxCols;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = AppLayout.gutter;
      final cols = ((box.maxWidth + gap) ~/ (minWidth + gap)).clamp(1, maxCols);
      final w = ((box.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}
