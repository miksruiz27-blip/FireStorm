import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../app/i18n.dart';

/// Override with `--dart-define=API_BASE=http://10.0.2.2:3000` for a local backend.
const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api-production-34edefa4.up.railway.app',
);

/// null until the first call; true = last call served live, false = from the bundled snapshot.
final apiLive = ValueNotifier<bool?>(null);

Future<Object?> _snapshot(String file) async => jsonDecode(
  await rootBundle.loadString('assets/snapshot/$file', cache: false),
);

/// GET [path] with a 3 s budget; on any failure, `assets/snapshot/[snapshot]` (optionally `[key]`).
Future<Object?> getJson(
  String path, {
  required String snapshot,
  String? key,
}) async {
  try {
    final r = await http
        .get(Uri.parse('$apiBase$path'))
        .timeout(const Duration(seconds: 3));
    if (r.statusCode == 200) {
      apiLive.value = true;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
  } catch (_) {}
  apiLive.value = false;
  final j = await _snapshot(snapshot);
  return key == null ? j : (j as Map)[key];
}

/// POST [path] (live only: classifiers have no offline fallback). Throws with the API's error message.
Future<Map<String, Object?>> postJson(String path, Object body) async {
  final r = await http
      .post(
        Uri.parse('$apiBase$path'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 10));
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>;
  if (r.statusCode != 200) {
    throw Exception(j['error'] ?? 'HTTP ${r.statusCode}');
  }
  apiLive.value = true;
  return j;
}

typedef CopilotReply = ({Map<String, Object?> body, String source});

/// POST /copilot (the backend answers in < 15 s, LLM or template). Offline: the snapshot's
/// cached answers for the demo script (recorded for the Lunar Base). null if neither has it.
Future<CopilotReply?> askCopilot(String question, String habitatId) async {
  try {
    final r = await http
        .post(
          Uri.parse('$apiBase/copilot'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'question': question,
            'habitat': habitatId,
            'lang': lang
                .value
                .name, // answer language (backend ignores it if unknown)
          }),
        )
        .timeout(const Duration(seconds: 16));
    if (r.statusCode == 200) {
      apiLive.value = true;
      return (
        body: jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, Object?>,
        source: r.headers['x-copilot-source'] ?? 'llm',
      );
    }
  } catch (_) {}
  apiLive.value = false;
  if (habitatId != 'lunar') return null;
  final norm = question.trim().toLowerCase();
  for (final e in await _snapshot('copilot_cache.json') as List) {
    if ((e['q'] as String).trim().toLowerCase() == norm) {
      return (
        body: (e['response'] as Map).cast<String, Object?>(),
        source: 'snapshot',
      );
    }
  }
  return null;
}
