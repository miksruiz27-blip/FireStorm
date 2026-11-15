import 'package:firestorm/app/theme.dart';
import 'package:firestorm/copilot/offline.dart';
import 'package:firestorm/copilot/session.dart';
import 'package:firestorm/data/habitats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lunar = Habitat(
    id: 'lunar',
    code: '02',
    zone: ('', ''),
    name: 'Lunar Base',
    blurb: ('', ''),
    o2: 34,
    pressure: 8.2,
    g: .166,
    risk: TagLevel.critical,
    source: '',
  );

  test('offline copilot answers a materials what-if with grounded, resolvable citations', () async {
    final r = await offlineCopilot('Which materials stay safe at 30% oxygen at Mars gravity?', lunar);
    final body = r.body;
    final widgets = (body['widgets'] as List).cast<Map>();
    final titles = [for (final w in widgets) if (w['type'] != 'coverage') '${w['title'] ?? w['kind'] ?? w['type']}'];

    expect(r.source, anyOf('onnx', 'rules'));
    expect(titles.first, contains('30 % O₂'));
    expect(titles.first, contains('0.38 g'));
    expect(titles.any((t) => t.startsWith('SAFE at 30 % O₂')), isTrue);
    expect(titles.any((t) => t.startsWith('BURNS at 30 % O₂')), isTrue);
    expect(widgets.where((w) => w['type'] == 'chart').length, greaterThanOrEqualTo(2)); // MOC + gravity
    final cites = (body['citations'] as List).cast<Map>();
    expect(cites, isNotEmpty);
    for (final c in cites) {
      expect(c['url'], matches(RegExp(r'^https?://')));
    }
    expect(body['answer'], contains('30 % O₂'));

    // Extra widgets: lunar base has no partial-g tests → coverage first; metrics after the forecast;
    // follow-ups last and never repeating the question's own topic (materials).
    final types = [for (final w in widgets) w['type']];
    expect(types.first, 'coverage');
    expect(types[2], 'metrics');
    expect(types.last, 'follow_ups');
    final follow = (widgets.last['questions'] as List).cast<String>();
    expect(follow, hasLength(3));
    expect(follow.any((q) => q.contains('materials')), isFalse);

    // Maps onto the GenUI catalog without dropping widgets.
    final a2ui = genuiToA2ui(body, r.source);
    final shown = [for (final m in a2ui) m['component']];
    expect(shown, containsAll(['AnswerCard', 'AnswerText', 'DataChart', 'SourceList', 'FollowUps']));
    expect(shown, isNot(contains('RiskCard'))); // materials → the MOC chart answers, no card stack
  });

  test('conditions parse fans-off and pressure what-ifs', () async {
    final r = await offlineCopilot('What happens at 5 psi with fans off?', lunar);
    final title = (r.body['widgets'] as List).cast<Map>().firstWhere((w) => w['type'] == 'answer_card')['title'] as String;
    expect(title, contains('34.5 kPa'));
    expect(title, contains('ventilation off'));
  });

  test('compare + validate questions add the habitat table and next experiments', () async {
    habitats = [lunar];
    final r = await offlineCopilot('Compare habitats: which experiment is missing to validate this?', lunar);
    final types = [for (final w in (r.body['widgets'] as List).cast<Map>()) w['type']];
    expect(types, containsAll(['table', 'next_tests', 'metrics', 'follow_ups']));
  });
}
