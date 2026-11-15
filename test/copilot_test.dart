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
    // Chat view shows only the interface for the question: the chart. The forecast card (w0)
    // and the experiment links (w2) are left out when something more specific answers.
    expect(byId['root']!['children'], ['text', 'w1', 'sources']);
    expect(byId['root']!['tags'], ['AI grounded']);
    expect(byId['text']!['citations'], [1, 2]);
    expect(byId['w1']!['component'], 'DataChart');
    expect(byId.containsKey('w0'), isFalse);
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

  test('pickInterface: asked-for view > chart > cards > tiles; coverage and follow-ups stay', () {
    List<String?> pick(List<Map<String, Object?>> w) =>
        [for (final x in pickInterface(w)) x['type'] as String?];
    final forecast = {'type': 'answer_card', 'title': 'Flame forecast'};
    const cov = {'type': 'coverage'}, tiles = {'type': 'metrics'}, fu = {'type': 'follow_ups'};
    const chart = {'type': 'chart'}, table = {'type': 'table'}, exps = {'type': 'experiment_list'};
    expect(pick([cov, forecast, tiles, chart, table, fu]), ['coverage', 'table', 'follow_ups']);
    expect(pick([forecast, tiles, chart, exps, fu]), ['chart', 'follow_ups']);
    expect(pick([forecast, tiles, {'type': 'answer_card', 'title': 'Required modifications'}, fu]),
        ['answer_card', 'follow_ups']);
    expect(pick([forecast, tiles, exps, fu]), ['metrics', 'experiment_list', 'follow_ups']);
  });
}
