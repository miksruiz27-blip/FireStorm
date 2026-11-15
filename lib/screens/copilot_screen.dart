import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';

import '../app/i18n.dart';
import '../app/theme.dart';
import '../copilot/session.dart';
import '../data/gap_map.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';

/// Step 04 · Ask: a chat with the grounded copilot. Each answer is a GenUI surface: the answer
/// text plus only the interface that answers the question (chart, table, next tests, tiles).
class CopilotScreen extends ConsumerStatefulWidget {
  const CopilotScreen({super.key});

  @override
  ConsumerState<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends ConsumerState<CopilotScreen> {
  final _scroll = ScrollController();
  var _seen = 0;
  var _wasBusy = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Follow the conversation: jump to the newest message when a turn is added or answered.
  void _toBottom() {
    _scrollEnd();
    Future.delayed(const Duration(milliseconds: 450), _scrollEnd);
  }

  void _scrollEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(copilotProvider);
    final h = ref.watch(selectedHabitatProvider);
    final all = ref.watch(experimentsProvider).value ?? const <Investigation>[];
    final side = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 40.0;

    return ListenableBuilder(
      listenable: Listenable.merge([session, session.conversation.state]),
      builder: (context, _) {
        // New question, answer streaming in, or answer just finished: follow to the newest message.
        if (session.turns.length != _seen || session.busy || _wasBusy) {
          _seen = session.turns.length;
          _toBottom();
        }
        _wasBusy = session.busy;
        Widget column(Widget child) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: child,
          ),
        );
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(side, 20, side, 8),
              child: column(_Header(session: session, habitat: h, all: all)),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: [
                  for (final t in session.turns)
                    column(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            _UserBubble(t.question),
                            Surface(
                              surfaceContext: session.controller.contextFor(
                                t.surfaceId,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 8, side, 16),
              child: column(
                _Composer(session, showSuggestions: session.turns.length < 3),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One line of context: title, the habitat the answers use, and the source scope behind a button.
class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.habitat,
    required this.all,
  });
  final CopilotSession session;
  final Habitat habitat;
  final List<Investigation> all;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      const BrandMark(size: 20),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 2,
          children: [
            Text(tr('AI COPILOT', 'COPILOTO IA'), style: AppText.label),
            Text(
              '${habitat.name} · ${fmtO2(habitat.o2)} % O₂ · ${habitat.pressureLabel} psia · ${habitat.gravityLabel} g',
              style: AppText.mono.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.card,
          builder: (_) => ListenableBuilder(
            listenable: session,
            builder: (context, _) => SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .75,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _Aside(session: session, habitat: habitat, all: all),
                ),
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.tune, size: 16),
        label: Text(tr('Sources', 'Fuentes')),
      ),
    ],
  );
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
  const _Composer(this.session, {this.showSuggestions = true});
  final CopilotSession session;
  final bool showSuggestions;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _input = TextEditingController();

  static List<String> get _suggestions => [
    tr(
      'Best suppressant for this ambient?',
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
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141518),
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          // One swipeable row: the composer stays small and the chat keeps the screen.
          if (widget.showSuggestions)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
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
              IconButton.filled(
                onPressed: busy ? null : _send,
                tooltip: tr('Ask', 'Preguntar'),
                icon: const Icon(Icons.arrow_upward),
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
