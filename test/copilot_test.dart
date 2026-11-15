import 'package:firestorm/copilot/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend GenUI maps onto the catalog with renumbered citations', () {
    final out = genuiToA2ui({
      'answer': 'Grounded.',
      'widgets': [
        {
          'type': 'answer_card',
          'title': 'Risk',
          'body': 'p 0.7',
          'level': 'critical',
        },
        {
          'type': 'chart',
          'kind': 'bar',
          'x': 'Material',
          'y': 'MOC %',
          'points': [
            ['PMMA', 15.5],
          ],
        },
        {
          'type': 'experiment_list',
          'ids': ['bass-ii'],
        },
        {'type': 'unknown'},
      ],
      'citations': [
        {'n': 2, 'title': 'BASS-II', 'url': 'https://psi.nasa.gov'},
        {'n': 5, 'title': 'MOC', 'url': ''},
      ],
    }, 'llm');

    final byId = {for (final c in out) c['id']: c};
    expect(byId['root']!['children'], ['text', 'w0', 'w1', 'w2', 'sources']);
    expect(byId['root']!['tags'], ['2 sources · AI grounded']);
    expect(byId['text']!['citations'], [1, 2]);
    expect(byId['w0']!['component'], 'RiskCard');
    expect(byId['w1']!['component'], 'DataChart');
    expect((byId['w2']!['actions'] as List).single, {
      'label': 'Open BASS-II',
      'action': 'report',
      'investigation': 'bass-ii',
    });
    expect((byId['sources']!['sources'] as List).first['ref'], 'psi.nasa.gov');
  });

  test('no resolvable citations → no "AI grounded" badge', () {
    final out = genuiToA2ui({
      'answer': 'x',
      'widgets': [
        {'type': 'answer_card', 'title': 't', 'body': 'b', 'level': 'info'},
      ],
      'citations': [],
    }, 'llm');
    final root = out.firstWhere((m) => m['id'] == 'root');
    expect(root['tags'], ['No sources']);
  });
}
