import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';

import '../app/theme.dart';
import '../data/api.dart';
import '../data/gap_map.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';
import 'catalog.dart';

typedef Turn = ({String question, String surfaceId});
typedef Json = Map<String, Object?>;

/// One copilot conversation: GenUI [Conversation] + the turns shown on screen + answer scope.
/// Lives in a provider so it survives navigating between screens.
class CopilotSession extends ChangeNotifier {
  CopilotSession({
    required this.habitat,
    required this.marks,
    required this.experiments,
    this.backend = askCopilot,
    this.tick = const Duration(milliseconds: 350),
  }) {
    _seed();
  }

  /// Current habitat (read at ask time, so answers follow the selection).
  final Habitat Function() habitat;
  final Future<List<TestMark>> Function() marks;
  final Future<List<Investigation>> Function() experiments;

  /// POST /copilot with snapshot fallback; injectable for tests.
  final Future<CopilotReply?> Function(String question, String habitatId)
  backend;

  /// Delay between chunks of the offline coverage-only answer.
  final Duration tick;

  final controller = SurfaceController(catalogs: [copilotCatalog]);
  late final _transport = A2uiTransportAdapter(onSend: _onSend);
  late final conversation = Conversation(
    controller: controller,
    transport: _transport,
  );

  final turns = <Turn>[];

  /// Investigations the copilot may cite; null = default (solid fuels).
  Set<String>? _scope;
  bool inScope(Investigation i) =>
      _scope?.contains(i.id) ?? i.fuel == Fuel.solid;

  void toggleScope(Investigation i, List<Investigation> all) {
    final s = _scope ??= {
      for (final x in all)
        if (x.fuel == Fuel.solid) x.id,
    };
    s.contains(i.id) ? s.remove(i.id) : s.add(i.id);
    notifyListeners();
  }

  bool get busy => conversation.state.value.isWaiting;

  /// Questions run one at a time, in order (the answer is written to the latest turn).
  Future<void> ask(String question) =>
      _queue = _queue.then((_) => _ask(question));
  Future<void> _queue = Future.value();

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || _disposed) return;
    turns.add((question: q, surfaceId: 'turn-${turns.length + 1}'));
    notifyListeners();
    await conversation.sendRequest(ChatMessage.user(q));
    if (!_disposed) notifyListeners();
  }

  Future<void> _onSend(ChatMessage _) async {
    final turn = turns.last;
    final id = turn.surfaceId;
    final h = habitat();
    _emit(_create(id));
    _emit(
      _components(id, [_card('Copilot · searching PSI records', .3, const [])]),
    );

    final reply = await backend(turn.question, h.id);
    if (_disposed) return;
    if (reply != null) {
      return _emit(_components(id, genuiToA2ui(reply.body, reply.source)));
    }

    // Offline and not in the cached demo script: coverage only, never invented findings.
    for (final m in await _offline(id, h)) {
      await Future<void>.delayed(tick);
      if (_disposed) return;
      _emit(m);
    }
  }

  void _emit(Json m) => _transport.addChunk(jsonEncode(m));

  /// Opening state of the mockup: one answered question, one follow-up.
  Future<void> _seed() async {
    await ask('Which materials stay safe at 34% oxygen?');
    await ask('Does that still hold at lunar gravity?');
  }

  Future<List<Json>> _offline(String id, Habitat h) async {
    final all = await marks();
    final scoped = (await experiments()).where(inScope).length;
    final covered = seriesAt(all, h.o2, h.band) > 0;
    final from = bandsWithEvidenceAt(
      all,
      h.o2,
      h.band,
    ).map((b) => b.short).join(' and ');
    final lead = covered ? <String>[] : ['warning'];
    final searching = 'Copilot · searching $scoped investigations';
    return [
      _components(id, [
        _card(searching, .6, lead),
        if (!covered)
          {
            'id': 'warning',
            'component': 'CoverageWarning',
            'text':
                'Outside data coverage: no PSI test matches ${fmtO2(h.o2)} % O₂ at ${h.band.short}. '
                'The answer will extrapolate from ${from.isEmpty ? 'the nearest' : from} tests '
                'and be flagged as such.',
          },
      ]),
      _components(id, [
        {
          ..._card('Copilot · answer', null, [...lead, 'text']),
          'tags': ['Offline'],
        },
        {
          'id': 'text',
          'component': 'AnswerText',
          'text':
              'The copilot backend is unreachable and this question is not in the cached demo '
              'script. Coverage above is computed from the bundled gap-map snapshot.',
        },
      ]),
    ];
  }

  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    conversation.dispose();
    _transport.dispose();
    controller.dispose();
    super.dispose();
  }
}

Json _create(String id) => {
  'version': 'v0.9',
  'createSurface': {'surfaceId': id, 'catalogId': copilotCatalogId},
};

Json _components(String id, List<Json> components) => {
  'version': 'v0.9',
  'updateComponents': {'surfaceId': id, 'components': components},
};

Json _card(String title, double? progress, List<String> children) => {
  'id': 'root',
  'component': 'AnswerCard',
  'title': title,
  'progress': ?progress,
  'children': children,
};

/// Backend GenUI `{answer, widgets, citations}` → copilot catalog components.
/// Citations are renumbered 1..n so AnswerText marks match SourceList rows.
@visibleForTesting
List<Json> genuiToA2ui(Map<String, Object?> body, String source) {
  final cites = (body['citations'] as List).cast<Map>();
  final widgets = <Json>[];
  for (final (i, w) in (body['widgets'] as List).cast<Map>().indexed) {
    final id = 'w$i';
    final c = switch (w['type']) {
      'answer_card' => {
        'component': 'RiskCard',
        'title': w['title'],
        'body': w['body'],
        'level': w['level'],
      },
      'chart' => {
        'component': 'DataChart',
        'kind': w['kind'],
        'x': w['x'],
        'y': w['y'],
        'points': w['points'],
        'measured': ?w['measured'],
      },
      'experiment_list' => {
        'component': 'ActionBar',
        'actions': [
          for (final e in (w['ids'] as List).cast<String>())
            {
              'label': 'Open ${e.toUpperCase()}',
              'action': 'report',
              'investigation': e,
            },
        ],
      },
      _ => null,
    };
    if (c != null) widgets.add({'id': id, ...c});
  }
  return [
    {
      ..._card('Copilot · answer', null, [
        'text',
        for (final w in widgets) w['id'] as String,
        'sources',
      ]),
      'tags': [
        '${cites.length} source${cites.length == 1 ? '' : 's'}',
        switch (source) {
          'llm' => 'AI · grounded',
          'ollama' => 'AI · local',
          'snapshot' => 'Offline cache',
          _ => 'Rule-based',
        },
      ],
    },
    {
      'id': 'text',
      'component': 'AnswerText',
      'text': body['answer'],
      'citations': [for (var n = 1; n <= cites.length; n++) n],
    },
    ...widgets,
    {
      'id': 'sources',
      'component': 'SourceList',
      'sources': [
        for (final c in cites)
          {
            'title': c['title'],
            'ref':
                Uri.tryParse(c['url'] as String? ?? '')?.host
                    .replaceFirst('www.', '') ??
                '',
          },
      ],
    },
  ];
}

final copilotProvider = Provider<CopilotSession>((ref) {
  final session = CopilotSession(
    habitat: () => ref.read(selectedHabitatProvider),
    marks: () => ref.read(testMarksProvider.future),
    experiments: () => ref.read(experimentsProvider.future),
  );
  ref.onDispose(session.dispose);
  return session;
});
