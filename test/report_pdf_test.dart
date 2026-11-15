import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firestorm/app/i18n.dart';
import 'package:firestorm/data/habitats.dart';
import 'package:firestorm/data/investigations.dart';
import 'package:firestorm/data/reports.dart';
import 'package:firestorm/screens/report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => (loadHabitats(), loadDataTranslations()).wait);
  tearDown(() => lang.value = Lang.en);

  Future<Investigation> bass() async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/snapshot/experiments.json'),
    );
    return Investigation.fromJson(
      ((j['lunar'] as List).cast<Map>().firstWhere((e) => e['id'] == 'bass-ii'))
          .cast(),
    );
  }

  for (final l in Lang.values) {
    test(
      'BASS-II report PDF builds (${l.name}): chart, findings, sources',
      () async {
        lang.value = l;
        final i = await bass();
        final h = habitats.firstWhere((h) => h.id == 'lunar');
        final bytes = await buildReportPdf(
          i: i,
          r: reports['BASS-II'],
          h: h,
          rank: 7,
          findings: i.keyFindings,
          now: DateTime(2026, 11, 14, 9, 5),
        );
        expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(20000)); // embedded fonts + content
      },
    );
  }

  test('report without a mockup sheet or findings still builds', () async {
    final i = await bass();
    final bytes = await buildReportPdf(
      i: i,
      r: null,
      h: habitats.first,
      rank: 1,
      findings: const [],
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}
