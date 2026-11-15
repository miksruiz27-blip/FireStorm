import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Lang { en, es }

/// App language. The shell remounts on change, so every [tr] call re-runs.
final lang = ValueNotifier(Lang.en);

bool get isEs => lang.value == Lang.es;

/// UI string in the current language.
String tr(String en, String es) => isEs ? es : en;

/// Mirrors [lang] for providers whose data is translated when fetched.
final langProvider = Provider<Lang>((ref) {
  void changed() => ref.invalidateSelf();
  lang.addListener(changed);
  ref.onDispose(() => lang.removeListener(changed));
  return lang.value;
});

/// English → Spanish for data strings (catalog, findings, modifications…): the inverse of
/// backend/data/translations_en.json (Spanish originals) plus assets/i18n/es_extra.json
/// (strings that were English at the source).
final _es = <String, String>{};

Future<void> loadDataTranslations() async {
  Future<Map> load(String path) async =>
      jsonDecode(await rootBundle.loadString(path)) as Map;
  try {
    for (final MapEntry(:key, :value) in (await load(
      'backend/data/translations_en.json',
    )).entries) {
      _es.putIfAbsent(value as String, () => key as String);
    }
    _es.addAll((await load('assets/i18n/es_extra.json')).cast());
  } catch (_) {} // missing dictionary → data stays in English
}

const _simulated = ' — simulated values (team dataset)';

/// Data string in the current language; unknown strings pass through unchanged.
String trd(String s) {
  if (!isEs || s.isEmpty) return s;
  if (_es[s] case final t?) return t;
  if (s.endsWith(_simulated)) {
    final head = s.substring(0, s.length - _simulated.length);
    return '${_es[head] ?? head} — valores simulados (dataset del equipo)';
  }
  return s;
}
