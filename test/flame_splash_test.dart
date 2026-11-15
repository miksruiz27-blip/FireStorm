import 'package:firestorm/app/flame_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets('flame splash animates while loading, then hands off to the app', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      FlameBoot(
        load: Future<void>.delayed(const Duration(milliseconds: 500)),
        app: const Directionality(textDirection: TextDirection.ltr, child: Text('APP')),
        minimum: const Duration(milliseconds: 1200),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FIRESTORM'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget); // load status bar
    expect(find.text('APP'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1000)); // load + minimum done
    await tester.pump(const Duration(milliseconds: 500)); // reticle closes
    await tester.pump(const Duration(milliseconds: 700)); // cross-fade
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('FIRESTORM'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
