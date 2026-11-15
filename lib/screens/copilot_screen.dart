import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';

import '../app/i18n.dart';
import '../app/page.dart';
import '../app/theme.dart';
import '../copilot/session.dart';
import '../data/gap_map.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';

/// Step 04 · Ask: grounded copilot. Answers are GenUI surfaces composed from the copilot catalog.
class CopilotScreen extends ConsumerWidget {
  const CopilotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(copilotProvider);
    final h = ref.watch(selectedHabitatProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([session, session.conversation.state]),
      builder: (context, _) {
        final chat = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: [
            PageIntro(
              step: tr('STEP 05 · ASK', 'PASO 05 · PREGUNTAR'),
              title: tr('AI COPILOT', 'COPILOTO IA'),
            ),
            for (final t in session.turns) ...[
              _UserBubble(t.question),
              Surface(
                surfaceContext: session.controller.contextFor(t.surfaceId),
              ),
            ],
            _Composer(session),
          ],
        );
        final aside = _Aside(
          session: session,
          habitat: h,
          all: ref.watch(experimentsProvider).value ?? const [],
        );

        return PageBody(
          children: [
            LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 1000
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 24,
                      children: [
                        Expanded(child: chat),
                        SizedBox(
                          width: 300,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 110),
                            child: aside,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 24,
                      children: [chat, aside],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(2),
        ),
      ),
      child: Text(text, style: AppText.body.copyWith(height: 22 / 15)),
    ),
  );
}

class _Composer extends StatefulWidget {
  const _Composer(this.session);
  final CopilotSession session;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _input = TextEditingController();

  static List<String> get _suggestions => [
    tr(
      'Best suppressant for this habitat?',
      '¿Mejor supresor para este hábitat?',
    ),
    tr(
      'Where would smoke detectors fail?',
      '¿Dónde fallarían los detectores de humo?',
    ),
    tr('Compare BASS vs SAFFIRE', 'Compara BASS vs SAFFIRE'),
  ];

  void _send([String? text]) {
    final q = text ?? _input.text;
    if (q.trim().isEmpty || widget.session.busy) return;
    _input.clear();
    widget.session.ask(q);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.session.busy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: busy ? null : () => _send(s),
                  backgroundColor: AppColors.chip,
                  side: const BorderSide(color: AppColors.line),
                  shape: const StadiumBorder(),
                  labelStyle: AppText.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: _send,
                  textInputAction: TextInputAction.send,
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: tr(
                      'Ask about materials, oxygen limits, suppression…',
                      'Pregunta por materiales, límites de oxígeno, supresión…',
                    ),
                    semanticCounterText: tr(
                      'Ask the copilot',
                      'Pregunta al copiloto',
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: busy ? null : _send,
                child: Text(tr('ASK', 'PREGUNTAR')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({
    required this.session,
    required this.habitat,
    required this.all,
  });
  final CopilotSession session;
  final Habitat habitat;
  final List<Investigation> all;

  @override
  Widget build(BuildContext context) {
    Widget readout(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(
          label,
          style: AppText.label.copyWith(fontSize: 10, letterSpacing: 1.4),
        ),
        Text(value, style: AppText.data.copyWith(fontWeight: FontWeight.w400)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        ChamferCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Text(
                tr('ANSWER CONTEXT', 'CONTEXTO DE RESPUESTA'),
                style: AppText.label,
              ),
              Row(
                children: [
                  Expanded(child: readout('O₂', habitat.o2.toStringAsFixed(1))),
                  Expanded(
                    child: readout('PSI', habitat.pressure.toStringAsFixed(1)),
                  ),
                  Expanded(
                    child: readout(
                      'G',
                      habitat.band.short.replaceAll(' g', ''),
                    ),
                  ),
                ],
              ),
              Text(
                tr(
                  'Answers use ${habitat.name} conditions (${fmtO2(habitat.o2)} % O₂).',
                  'Las respuestas usan las condiciones de ${habitat.name} (${fmtO2(habitat.o2)} % O₂).',
                ),
                style: AppText.caption,
              ),
            ],
          ),
        ),
        ChamferCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(
                tr('SOURCES IN SCOPE', 'FUENTES EN ALCANCE'),
                style: AppText.label,
              ),
              for (final i in all)
                Tappable(
                  selected: session.inScope(i),
                  label: tr(
                    '${i.code}, ${i.docs} documents',
                    '${i.code}, ${i.docs} documentos',
                  ),
                  onTap: () => session.toggleScope(i, all),
                  child: SizedBox(
                    height: 28,
                    child: Row(
                      spacing: 10,
                      children: [
                        ExcludeSemantics(
                          child: Checkbox(
                            value: session.inScope(i),
                            onChanged: (_) => session.toggleScope(i, all),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            i.code,
                            style: AppText.mono.copyWith(
                              fontSize: 13,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ),
                        Text(
                          '${i.docs} doc${i.docs == 1 ? '' : 's'}',
                          style: AppText.mono.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        ChamferCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(tr('GUARDRAILS', 'SALVAGUARDAS'), style: AppText.label),
              Text(
                tr(
                  'Every claim cites a PSI record. Outside coverage, the copilot says so before '
                      'answering.',
                  'Cada afirmación cita un registro PSI. Fuera de cobertura, el copiloto lo advierte '
                      'antes de responder.',
                ),
                style: AppText.caption.copyWith(
                  fontSize: 13,
                  height: 20 / 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
