import 'dart:convert';

import 'package:flutter/services.dart';

import '../app/i18n.dart';
import '../data/api.dart';
import '../data/flame.dart';
import '../data/habitats.dart';
import 'classifier.dart';

/// Offline copilot: Dart port of backend/src/genui/copilot.js + rules.js over the bundled
/// snapshot, with retrieval routed by the on-device ONNX experiment classifier. Emits the
/// same GenUI body `{answer, widgets, citations}` as POST /copilot, so the UI is unchanged.
/// Like the backend, widgets come from rules + real data only; nothing is generated.
typedef Json = Map<String, Object?>;

const _psiToKpa = 6.89476;
const _maxSources = 8;

class _Data {
  _Data(this.flame, this.experiments, this.points, this.mocs, this.ml, this.recs);
  final FlameModel flame;
  final Map<String, List<Json>> experiments, recs; // by habitat id (scored / GET /recommendations)
  final List<Json> points, mocs;
  final Json ml; // model.json extended_capabilities.experiment_classifier
}

Future<_Data>? _data;

Future<Object?> _asset(String path) async =>
    jsonDecode(await rootBundle.loadString(path));

Future<_Data> _load() async {
  final [flame, exps, points, mocs, model, recs] = await Future.wait([
    _asset('assets/snapshot/flame.json'),
    _asset('assets/snapshot/experiments.json'),
    _asset('assets/snapshot/test_points.json'),
    _asset('backend/data/material_moc.json'),
    _asset('assets/snapshot/model.json'),
    _asset('assets/snapshot/recommendations.json'),
  ]);
  List<Json> rows(Object? l) => (l as List).cast<Map>().map((m) => m.cast<String, Object?>()).toList();
  Map<String, List<Json>> byHabitat(Object? m) => {for (final e in (m as Map).entries) e.key as String: rows(e.value)};
  return _Data(
    FlameModel(flame as Map),
    byHabitat(exps),
    rows(points),
    rows(mocs),
    (((model as Map)['extended_capabilities'] as Map)['experiment_classifier'] as Map).cast(),
    byHabitat(recs),
  );
}

/// Habitat conditions, overridden by any what-if in the question (rules.js conditionsFrom).
typedef Cond = ({double o2, double kpa, double g, double flow, String material, List<String> changed});

Cond conditionsFrom(String question, Habitat h, FlameModel m) {
  var o2 = h.o2, kpa = h.pressure * _psiToKpa, g = h.g, flow = cabinFlow;
  var material = m.defaultMaterial;
  final changed = <String>[];
  double? num(String re) =>
      double.tryParse(RegExp(re, caseSensitive: false).firstMatch(question)?.group(1) ?? '');

  final qo2 = num(r'(\d+(?:\.\d+)?)\s*%');
  if (qo2 != null && qo2 <= 100 && qo2 != o2) {
    o2 = qo2;
    changed.add('${_f(qo2)} % O₂');
  }
  final qg = num(r'(\d*\.?\d+)\s*g\b');
  final grav = qg != null && qg <= 1 ? qg : _gravityWords.where((w) => w.re.hasMatch(question)).firstOrNull?.g;
  if (grav != null && (grav - g).abs() > .01) {
    g = grav;
    changed.add('${_f(grav, 3)} g');
  }
  final qkpa = num(r'(\d+(?:\.\d+)?)\s*kpa'), qpsi = num(r'(\d+(?:\.\d+)?)\s*psi');
  final p = (qkpa ?? 0) > 0 ? qkpa : (qpsi ?? 0) > 0 ? qpsi! * _psiToKpa : null;
  if (p != null) {
    kpa = p;
    changed.add('${_f(p)} kPa');
  }
  final qflow = num(r'(\d+(?:\.\d+)?)\s*cm\s*/\s*s');
  if (qflow != null) {
    flow = qflow;
    changed.add(tr('${_f(qflow)} cm/s flow', 'flujo ${_f(qflow)} cm/s'));
  } else if (RegExp(r'fans? off|ventilation off|no (ventilation|flow)|quiescent|sin ventila|apagad', caseSensitive: false)
      .hasMatch(question)) {
    flow = 0;
    changed.add(tr('ventilation off', 'ventilación apagada'));
  }
  final mat = m.materials.keys.where((k) => question.toLowerCase().contains(k)).firstOrNull;
  if (mat != null) {
    material = mat;
    changed.add(trd(m.materials[mat]!.name));
  }
  return (o2: o2, kpa: kpa, g: g, flow: flow, material: material, changed: changed);
}

final _gravityWords = [
  (re: RegExp(r'micro|μg|orbit|\biss\b', caseSensitive: false), g: 0.0, en: 'μg', es: 'μg'),
  (re: RegExp(r'lunar|moon|\bluna', caseSensitive: false), g: 0.166, en: 'Moon', es: 'Luna'),
  (re: RegExp(r'mars|marte', caseSensitive: false), g: 0.38, en: 'Mars', es: 'Marte'),
  (re: RegExp(r'earth|tierra', caseSensitive: false), g: 1.0, en: 'Earth', es: 'Tierra'),
];

final _topics = {
  'materials': RegExp(r'material|safe|segur|moc|flammab|inflamab', caseSensitive: false),
  'experiments': RegExp(r'experiment|evidence|evidencia|tested|probad|cover|study|estudi', caseSensitive: false),
  'spread': RegExp(r'\bo2\b|o₂|oxygen|ox[ií]geno|flow|flujo|spread|propagaci|fast|rápid', caseSensitive: false),
  'gravity': RegExp(r'gravit|gravedad|lunar|moon|luna|mars|marte|earth|tierra|micro|μg', caseSensitive: false),
  'modifications': RegExp(
    r'modif|redesign|rediseñ|change|cambi|mitigat|mitig|recommend|recomend|lesson|lecci|requir|requer|should we|debemos',
    caseSensitive: false,
  ),
};

String _f(num v, [int d = 1]) {
  final s = v.toStringAsFixed(d);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _level(double p) => p >= .5 ? 'critical' : p >= .3 ? 'warning' : 'info';

bool _citable(Map? s) =>
    (s?['title'] as String?)?.isNotEmpty == true &&
    RegExp(r'^https?://\S+$').hasMatch(s?['url'] as String? ?? '');

String _refOf(Map s) {
  final ntrs = s['ntrs_id'] as String?;
  if (ntrs != null && ntrs.isNotEmpty) return 'NTRS $ntrs';
  final url = s['url'] as String;
  return RegExp(r'investigations/(PSI-\d+)').firstMatch(url)?.group(1) ??
      Uri.parse(url).host.replaceFirst('www.', '');
}

List<String> _strings(Object? l) => (l as List?)?.cast<String>() ?? const [];

/// Experiments sharing words with the question (stand-in for the backend's Postgres FTS).
List<Json> _keywordSearch(String question, List<Json> all) {
  final words = RegExp(r'[a-z0-9áéíóúñ]{4,}').allMatches(question.toLowerCase()).map((m) => m[0]!).toSet();
  if (words.isEmpty) return [];
  final hits = [
    for (final e in all)
      (e: e, n: words.where(('${e['name']} ${_strings(e['key_findings']).join(' ')} ${_strings(e['materials']).join(' ')}')
          .toLowerCase()
          .contains).length),
  ]..retainWhere((x) => x.n > 0);
  hits.sort((a, b) => b.n - a.n);
  return [for (final x in hits.take(5)) x.e];
}

/// Answers [question] for [h] from bundled data. source: 'onnx' when the on-device
/// classifier routed retrieval, else 'rules'.
Future<CopilotReply> offlineCopilot(String question, Habitat h) async {
  final d = await (_data ??= _load());
  final fm = d.flame;
  final all = (d.experiments[h.id] ?? d.experiments.values.first).where((e) => e['type'] != 'reference').toList();
  final byId = {for (final e in all) e['id'] as String: e};

  // a) retrieve: ONNX research group → its experiments; else keyword hits; else top-scored.
  final probs = await classifyText(question);
  final classes = _strings(d.ml['classes']);
  ({String group, double p})? top;
  var experiments = <Json>[];
  if (probs != null && probs.length == classes.length) {
    final i = List.generate(probs.length, (i) => i).reduce((a, b) => probs[a] >= probs[b] ? a : b);
    top = (group: classes[i], p: probs[i]);
    experiments = all.where((e) => e['research_group'] == top!.group).take(5).toList();
  }
  if (experiments.isEmpty) experiments = _keywordSearch(question, all);
  if (experiments.isEmpty) experiments = all.take(5).toList(); // snapshot is score-sorted

  final spreadPoints = d.points.where((t) => t['spread_rate_mm_s'] != null).toList();

  // Numbered sources (max 8): retrieved experiments first, then experiments behind measured spreads,
  // then MOC sources. Only titled http(s) sources get a number, so nothing else can be cited.
  final sources = <({int n, String key, String title, String url, String ref})>[];
  void addSource(String key, Map? src) {
    if (sources.length >= _maxSources || !_citable(src) || sources.any((s) => s.key == key)) return;
    sources.add((n: sources.length + 1, key: key, title: src!['title'] as String, url: src['url'] as String, ref: _refOf(src)));
  }

  for (final e in [...experiments, ...spreadPoints.map((t) => byId[t['experiment_id']])]) {
    if (e != null) addSource('exp:${e['id']}', (e['sources'] as List?)?.cast<Map>().where(_citable).firstOrNull);
  }
  for (final m in d.mocs) {
    addSource('moc:${m['source']}', {'title': m['source'], 'url': m['url'] ?? '', 'ntrs_id': m['ntrs_id'] ?? ''});
  }
  int? n(String key) => sources.where((s) => s.key == key).firstOrNull?.n;

  // b+c) physics forecast at the habitat (or the question's what-if) → widgets (rules.js buildWidgets).
  final c = conditionsFrom(question, h, fm);
  FlameForecast at({double? o2, double? g, double? flow, String? material}) => fm.predict(
    o2: o2 ?? c.o2,
    kpa: c.kpa,
    g: g ?? c.g,
    flow: flow ?? c.flow,
    material: material ?? c.material,
  );
  final f = at(), quiet = at(flow: 0);
  String regime(FlameForecast x) => x.regime.label.toLowerCase();
  final widgets = <Json>[];
  final cite = <int>{};

  widgets.add({
    'type': 'answer_card',
    'title': c.changed.isNotEmpty
        ? '${tr('What-if', 'Escenario')} · ${c.changed.join(' · ')}'
        : '${tr('Flame forecast', 'Pronóstico de llama')} · ${h.name}',
    'body': [
      '${regime(f)[0].toUpperCase()}${regime(f).substring(1)} ${tr('for', 'para sólidos tipo')} ${trd(f.name)}'
          '${tr('-class solids', '')}: ${tr('p(burn)', 'p(arder)')} ${f.pBurn.toStringAsFixed(2)}, '
          '${tr('spread', 'propagación')} ≈ ${_f(f.spread, 2)} mm/s.',
      '${tr('Flammability limit', 'Límite de inflamabilidad')} ${_f(f.loi, 2)} % O₂ → ${tr('margin', 'margen')} '
          '${f.margin > 0 ? '+' : ''}${_f(f.margin, 2)}.',
      c.g > .01
          ? tr(
              'Buoyancy at ${_f(c.g, 3)} g feeds the flame ≈ ${_f(f.uBuoy)} cm/s, so ventilation off does not starve it (${regime(quiet)}).',
              'La flotabilidad a ${_f(c.g, 3)} g alimenta la llama con ≈ ${_f(f.uBuoy)} cm/s, así que apagar la ventilación no la asfixia (${regime(quiet)}).',
            )
          : tr(
              'In microgravity only ventilation feeds it: fans off → limit ${_f(quiet.loi, 2)} % (${regime(quiet)}).',
              'En microgravedad solo la alimenta la ventilación: ventiladores apagados → límite ${_f(quiet.loi, 2)} % (${regime(quiet)}).',
            ),
      if (f.extrapolated.isNotEmpty)
        '${tr('Physics extrapolation, untested', 'Extrapolación física, sin ensayar')}: ${f.extrapolated.join('; ')}.',
    ].join(' '),
    // An untested condition the physics says burns is the worst case: no data to argue otherwise.
    'level': f.extrapolated.isNotEmpty && f.pBurn >= .3 ? 'critical' : _level(f.pBurn),
  });

  // What the on-device model decided, so the routing is visible and auditable.
  final group = top == null ? null : (d.ml['modifications_by_group'] as Map?)?[top.group] as Map?;
  if (top != null) {
    widgets.add({
      'type': 'answer_card',
      'title': '${tr('On-device ONNX classifier', 'Clasificador ONNX en el dispositivo')} · ${top.group.replaceAll('_', ' ')}',
      'body': tr(
        'Question routed to research group ${top.group.replaceAll('_', ' ')} (p ${top.p.toStringAsFixed(2)}'
            '${group?['categoria_principal'] != null ? '; ${group!['categoria_principal']}' : ''}). '
            'Retrieved ${experiments.length} experiment${experiments.length == 1 ? '' : 's'} from the bundled snapshot, no network.',
        'Pregunta asignada al grupo de investigación ${top.group.replaceAll('_', ' ')} (p ${top.p.toStringAsFixed(2)}'
            '${group?['categoria_principal'] != null ? '; ${trd(group!['categoria_principal'] as String)}' : ''}). '
            'Se recuperaron ${experiments.length} experimento${experiments.length == 1 ? '' : 's'} de la instantánea incluida, sin red.',
      ),
      'level': 'info',
    });
  }

  final hit = {for (final e in _topics.entries) e.key: e.value.hasMatch(question)};

  if (hit['materials']! && d.mocs.isNotEmpty) {
    // SAFE / BURNS from the MOC table at the active O₂; per material, the row closest in pressure.
    final best = <String, Json>{};
    for (final m in d.mocs) {
      final k = (m['material'] as String).toLowerCase();
      double dist(Json r) => ((r['pressure_kpa'] as num) - c.kpa).abs();
      if (best[k] == null || dist(m) < dist(best[k]!)) best[k] = m;
    }
    double moc(Json m) => (m['moc_pct'] as num).toDouble();
    final rows = best.values.toList()..sort((a, b) => moc(a).compareTo(moc(b)));
    final safe = rows.where((m) => moc(m) > c.o2), burns = rows.where((m) => moc(m) <= c.o2);
    String name(Json m) => trd(m['material'] as String);
    String atP(Json m) => 'MOC ${_f(moc(m))} % ${tr('at', 'a')} ${_f(m['pressure_kpa'] as num)} kPa';
    final o2 = _f(c.o2);
    widgets
      ..add({
        'type': 'chart',
        'kind': 'bar',
        'x': 'Material',
        'y': 'MOC % O₂',
        'points': [for (final m in rows) [name(m), moc(m)]],
        'threshold': c.o2,
      })
      ..add({
        'type': 'answer_card',
        'title': tr('SAFE at $o2 % O₂ · MOC above $o2 %', 'SEGUROS a $o2 % O₂ · MOC por encima de $o2 %'),
        'body': safe.isNotEmpty
            ? '${safe.map((m) => '${name(m)} (${atP(m)}, ${tr('margin', 'margen')} +${_f(moc(m) - c.o2)})').join('; ')}.'
            : tr(
                'None of the ${rows.length} materials in the MOC table stays below its limit at $o2 % O₂.',
                'Ninguno de los ${rows.length} materiales de la tabla MOC queda por debajo de su límite a $o2 % O₂.',
              ),
        'level': 'info',
      })
      ..add({
        'type': 'answer_card',
        'title': tr('BURNS at $o2 % O₂ · MOC at or below $o2 %', 'ARDEN a $o2 % O₂ · MOC igual o inferior a $o2 %'),
        'body': burns.isNotEmpty
            ? '${burns.map((m) {
                final s = _f(at(material: fm.match(m['material'] as String)).spread, 2);
                return tr(
                  '${name(m)} (${atP(m)}, ${_f(c.o2 - moc(m))} points over; predicted spread ≈ $s mm/s)',
                  '${name(m)} (${atP(m)}, ${_f(c.o2 - moc(m))} puntos por encima; propagación predicha ≈ $s mm/s)',
                );
              }).join('; ')}.'
            : tr('No material in the MOC table burns at $o2 % O₂.', 'Ningún material de la tabla MOC arde a $o2 % O₂.'),
        'level': burns.isNotEmpty ? 'critical' : 'info',
      });
    for (final m in rows) {
      if (n('moc:${m['source']}') case final k?) cite.add(k);
    }
  }
  if (hit['spread']!) {
    final cited = spreadPoints.where((t) => n('exp:${t['experiment_id']}') != null);
    widgets.add({
      'type': 'chart',
      'kind': 'line',
      'x': 'O2 %',
      'y': 'mm/s',
      'points': [
        for (var o2 = 10; o2 <= 40; o2 += 2) [o2, double.parse(at(o2: o2.toDouble()).spread.toStringAsFixed(2))],
      ],
      'measured': [for (final t in cited) [t['o2_pct'], t['spread_rate_mm_s']]],
    });
    for (final t in cited) {
      cite.add(n('exp:${t['experiment_id']}')!);
    }
  }
  if (hit['gravity']!) {
    widgets.add({
      'type': 'chart',
      'kind': 'bar',
      'x': tr('Gravity', 'Gravedad'),
      // Fans off: only buoyancy feeds the flame, so gravity alone sets the limit.
      'y': tr('Limit % O₂, fans off', 'Límite % O₂, ventiladores apagados'),
      'points': [
        for (final w in _gravityWords) [tr(w.en, w.es), double.parse(at(g: w.g, flow: 0).loi.toStringAsFixed(2))],
      ],
    });
  }
  if (hit['modifications']!) {
    // Required design changes from the retrieved experiments, else from the classified group (team catalog).
    final withMods = experiments.where((e) => _strings(e['modifications']).isNotEmpty).take(2).toList();
    for (final e in withMods) {
      widgets.add({
        'type': 'answer_card',
        'title': '${tr('Required modifications', 'Modificaciones requeridas')} · ${trd(e['name'] as String)}',
        'body': [for (final (i, m) in _strings(e['modifications']).take(3).indexed) '${i + 1}) ${trd(m)}'].join(' '),
        'level': 'warning',
      });
      if (n('exp:${e['id']}') case final k?) cite.add(k);
    }
    if (withMods.isEmpty && group != null) {
      for (final m in _strings(group['modificaciones_necesarias']).take(2)) {
        widgets.add({
          'type': 'answer_card',
          'title': '${tr('Required modifications', 'Modificaciones requeridas')} · ${top!.group.replaceAll('_', ' ')}',
          'body': trd(m),
          'level': 'warning',
        });
      }
    }
  }
  if ((hit['experiments']! || !hit.values.any((v) => v)) && experiments.isNotEmpty) {
    final ids = [for (final e in experiments.take(5)) e['id'] as String];
    widgets.add({'type': 'experiment_list', 'ids': ids});
    for (final id in ids) {
      if (n('exp:$id') case final k?) cite.add(k);
    }
  }
  if (cite.isEmpty && sources.isNotEmpty) cite.add(sources.first.n);
  final cites = cite.toList()..sort();

  // d/e) template answer (the LLM only runs on the backend).
  final risk = {'critical': tr('critical', 'crítico'), 'warning': tr('high', 'alto'), 'info': tr('low', 'bajo')}[_level(f.pBurn)];
  final k = cites.length, o2 = _f(c.o2);
  final answer = tr(
    'Based on $k NASA source${k == 1 ? '' : 's'} and the physics model: $risk risk at ${h.name} at $o2 % O₂ — '
        'limit ${_f(f.loi, 2)} %, spread ≈ ${_f(f.spread, 2)} mm/s'
        '${f.extrapolated.isNotEmpty ? '; extrapolated, untested at this condition.' : '.'}',
    'Según $k fuente${k == 1 ? '' : 's'} de la NASA y el modelo físico: riesgo $risk en ${h.name} a $o2 % O₂ — '
        'límite ${_f(f.loi, 2)} %, propagación ≈ ${_f(f.spread, 2)} mm/s'
        '${f.extrapolated.isNotEmpty ? '; extrapolado, sin ensayar en esta condición.' : '.'}',
  );

  return (
    body: <String, Object?>{
      'answer': answer,
      'widgets': _compose(widgets, _extras(question, h, c, f, d)),
      'citations': [
        for (final s in sources)
          if (cites.contains(s.n)) {'n': s.n, 'title': s.title, 'ref': s.ref, 'url': s.url},
      ],
    },
    source: top != null ? 'onnx' : 'rules',
  );
}

/// POST /copilot (with its cached demo answers); when both miss, the offline copilot.
Future<CopilotReply?> askCopilotOrOffline(String question, String habitatId) async {
  final live = await askCopilot(question, habitatId);
  if (live != null) return live;
  final h = habitats.where((h) => h.id == habitatId).firstOrNull;
  if (h == null) return null;
  try {
    return await offlineCopilot(question, h);
  } catch (_) {
    return null; // session falls back to coverage-only
  }
}

// ── Extra widgets: port of backend/src/genui/extras.js (rules + data, never the LLM) ──

final _habitatsTopic = RegExp(
  r'habitat|hábitat|compar|risky|riesg|atmospher|atmósfera|suit|traje|rover|\biss\b',
  caseSensitive: false,
);
final _nextTopic = RegExp(
  r'next|próxim|recommend|recomiend|recomend|gap|vac[ií]o|validat|valid|missing|falta|should we test|ensayar|untested|sin ensayar',
  caseSensitive: false,
);

typedef _Extras = ({Json? coverage, Json metrics, Json? table, Json? next, Json followUps});

_Extras _extras(String question, Habitat h, Cond c, FlameForecast f, _Data d) {
  String lvl(double p) => _level(p);

  // coverage: test points within ±2 % O₂ at the same gravity.
  num n(Json t, String k) => t[k] as num;
  final near = d.points.where((t) => (n(t, 'o2_pct') - c.o2).abs() <= 2 && (n(t, 'gravity_g') - c.g).abs() < .05);
  Json? coverage;
  if (near.isEmpty) {
    final tested = ({for (final t in d.points) n(t, 'gravity_g')}.toList()..sort()).map(_f).join(', ');
    final g = _f(c.g, 3);
    coverage = {
      'type': 'coverage',
      'text': tr(
        'Outside data coverage: no PSI test within ±2 % of ${_f(c.o2)} % O₂ at $g g (tests exist at $tested g). '
            'The forecast below is physics extrapolation, not a measurement.',
        'Fuera de la cobertura de datos: ningún ensayo PSI a ±2 % de ${_f(c.o2)} % O₂ a $g g (hay ensayos a $tested g). '
            'El pronóstico de abajo es extrapolación física, no una medición.',
      ),
    };
  }

  final metrics = {
    'type': 'metrics',
    'items': [
      {'label': tr('p(burn)', 'p(arder)'), 'value': '${(f.pBurn * 100).round()}', 'unit': '%', 'level': lvl(f.pBurn)},
      {'label': tr('Flammability limit', 'Límite de inflamabilidad'), 'value': _f(f.loi), 'unit': '% O₂'},
      {
        'label': tr('Margin', 'Margen'),
        'value': '${f.margin > 0 ? '+' : ''}${_f(f.margin)}',
        'unit': '% O₂',
        'level': f.margin > 0 ? 'critical' : 'info',
      },
      {'label': tr('Spread', 'Propagación'), 'value': _f(f.spread, 2), 'unit': 'mm/s'},
      {'label': tr('Flow at flame', 'Flujo en la llama'), 'value': _f(f.uEff), 'unit': 'cm/s'},
    ],
  };

  Json? table;
  if (_habitatsTopic.hasMatch(question) && habitats.isNotEmpty) {
    final rows = [
      for (final x in habitats)
        (x: x, fc: d.flame.predict(o2: x.o2, kpa: x.pressure * _psiToKpa, g: x.g, flow: cabinFlow, material: c.material)),
    ]..sort((a, b) => b.fc.margin.compareTo(a.fc.margin));
    table = {
      'type': 'table',
      'title': tr('Fire risk by habitat · ${f.name}, ventilated', 'Riesgo de incendio por hábitat · ${trd(f.name)}, ventilado'),
      'columns': [tr('Habitat', 'Hábitat'), 'O₂ %', 'kPa', 'g', tr('Limit %', 'Límite %'), tr('p(burn)', 'p(arder)'), tr('Regime', 'Régimen')],
      'rows': [
        for (final r in rows)
          [
            r.x.name,
            _f(r.x.o2),
            _f(r.x.pressure * _psiToKpa),
            '${r.x.g}',
            _f(r.fc.loi),
            r.fc.pBurn.toStringAsFixed(2),
            r.fc.regime.label.toLowerCase(),
          ],
      ],
      'highlight': rows.indexWhere((r) => r.x.id == h.id),
    };
  }

  Json? next;
  if (_nextTopic.hasMatch(question)) {
    // Same picks as GET /recommendations for this habitat (bundled snapshot).
    next = {
      'type': 'next_tests',
      'items': [
        for (final r in (d.recs[h.id] ?? const <Json>[]).take(3))
          () {
            final cell = r['cell'] as Map;
            final fc = d.flame.predict(
              o2: (cell['o2_pct'] as num).toDouble(),
              kpa: h.pressure * _psiToKpa,
              g: (cell['gravity_g'] as num).toDouble(),
              flow: cabinFlow,
            );
            final k = (r['sources'] as List?)?.length ?? 0;
            return {
              'title': '${cell['o2_pct']} % O₂ · ${cell['gravity_g']} g',
              'priority': r['priority'],
              'body': tr(
                '${k > 0 ? 'Tests nearby' : 'No tests nearby'}; physics: ${fc.regime.label.toLowerCase()}, limit ${_f(fc.loi, 2)} %'
                    '${fc.extrapolated.isNotEmpty ? '; extrapolated, a test here would confirm it.' : '.'}',
                '${k > 0 ? 'Hay ensayos cerca' : 'Sin ensayos cerca'}; física: ${fc.regime.label.toLowerCase()}, límite ${_f(fc.loi, 2)} %'
                    '${fc.extrapolated.isNotEmpty ? '; extrapolado, un ensayo aquí lo confirmaría.' : '.'}',
              ),
            };
          }(),
      ],
    };
  }

  // Follow-ups: the angles this question did not cover. Each phrasing triggers its rule widgets.
  final q = question.toLowerCase();
  final options = [
    (RegExp(r'material|segur|safe'), tr('Which materials stay safe here?', '¿Qué materiales siguen siendo seguros aquí?')),
    (RegExp(r'fan|ventila|flow|flujo'), tr('What if we turn the fans off?', '¿Qué pasa con la ventilación apagada?')),
    (RegExp(r'mars|marte|gravit|gravedad'), tr('Does it change at Mars gravity?', '¿Cambia a gravedad de Marte?')),
    (_nextTopic, tr('Which experiment is missing to validate this?', '¿Qué experimento falta para validar esto?')),
    (_habitatsTopic, tr('Compare fire risk across habitats', 'Compara el riesgo de incendio entre hábitats')),
  ];
  final followUps = {
    'type': 'follow_ups',
    'questions': [for (final (re, s) in options) if (!re.hasMatch(q)) s].take(3).toList(),
  };
  return (coverage: coverage, metrics: metrics, table: table, next: next, followUps: followUps);
}

/// Widget order (backend compose): coverage, forecast card, metrics, rule widgets, table, next tests, follow-ups.
List<Json> _compose(List<Json> widgets, _Extras x) => [
  ?x.coverage,
  widgets.first,
  x.metrics,
  ...widgets.skip(1),
  ?x.table,
  ?x.next,
  x.followUps,
];
