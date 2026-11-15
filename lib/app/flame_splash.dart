import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'theme.dart';

/// Native splash color (pubspec flutter_native_splash): the hand-off is seamless.
const splashBackground = Color(0xFF0A111F);

/// Boot: shows [FlameSplash] while [load] runs (at least [minimum], so the flame is seen),
/// completes the reticle, then cross-fades into [app].
class FlameBoot extends StatefulWidget {
  const FlameBoot({
    super.key,
    required this.load,
    required this.app,
    this.minimum = const Duration(milliseconds: 2400),
  });
  final Future<void> load;
  final Widget app;
  final Duration minimum;

  @override
  State<FlameBoot> createState() => _FlameBootState();
}

class _FlameBootState extends State<FlameBoot> {
  var _loaded = false, _ready = false;

  @override
  void initState() {
    super.initState();
    // A failed load still opens the app: every screen falls back to the bundled snapshot.
    Future.wait([
      widget.load.catchError((_) {}),
      Future<void>.delayed(widget.minimum),
    ]).then((_) async {
      if (!mounted) return;
      setState(() => _loaded = true);
      await Future<void>.delayed(
        const Duration(milliseconds: 450),
      ); // reticle closes
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 650),
    switchInCurve: Curves.easeOut,
    child: _ready
        ? widget.app
        : Directionality(
            textDirection: TextDirection.ltr,
            child: FlameSplash(loaded: _loaded, expected: widget.minimum),
          ),
  );
}

/// Loading screen: a live microgravity flame (spherical, blue CH* sheath, orange soot shell,
/// white-hot core) with drifting embers, inside the FireStorm reticle that closes as it loads.
class FlameSplash extends StatefulWidget {
  const FlameSplash({super.key, this.loaded = false, required this.expected});
  final bool loaded;
  final Duration expected;

  @override
  State<FlameSplash> createState() => _FlameSplashState();
}

class _FlameSplashState extends State<FlameSplash>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _t = ValueNotifier(0.0);
  var _doneAt = -1.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  /// Eases toward 92 % over the expected load time; closes to 100 % once loaded.
  double _progress(double t) {
    final p =
        .92 *
        (1 - math.exp(-2.2 * t / (widget.expected.inMilliseconds / 1000)));
    if (!widget.loaded) return p;
    if (_doneAt < 0) _doneAt = t;
    return p +
        (1 - p) * Curves.easeOut.transform(((t - _doneAt) / .4).clamp(0, 1));
  }

  static String _status(double p) => p < .3
      ? 'IGNITING PHYSICS MODEL'
      : p < .6
      ? 'LOADING NASA PSI RECORDS'
      : p < .95
      ? 'CALIBRATING AMBIENTS'
      : 'READY';

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ColoredBox(
      color: splashBackground,
      child: ValueListenableBuilder<double>(
        valueListenable: _t,
        builder: (context, t, _) {
          final time = still ? 1.2 : t;
          final p = _progress(t);
          return LayoutBuilder(
            builder: (context, box) {
              final r = (box.biggest.shortestSide * .135).clamp(40.0, 80.0);
              final below = box.maxHeight / 2 + r * 2.35;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FlamePainter(time, p, r, animate: !still),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: below,
                    child: Column(
                      spacing: 10,
                      children: [
                        Text(
                          'FIRESTORM',
                          textAlign: TextAlign.center,
                          style: AppText.display.copyWith(
                            fontSize: 26,
                            letterSpacing: 9,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'NASA PSI · MICROGRAVITY COMBUSTION',
                          textAlign: TextAlign.center,
                          style: AppText.label.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _status(p),
                          style: AppText.mono.copyWith(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: AppColors.secondary,
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          height: 2,
                          child: LinearProgressIndicator(
                            value: p,
                            color: AppColors.red,
                            backgroundColor: const Color(0xFF1C2638),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.t, this.progress, this.r, {required this.animate});
  final double t, progress, r;
  final bool animate;

  // Forecast flame palette: CH* blue sheath, soot shell, hot core.
  static const _sheathDeep = Color(0xFF1D3B8F), _sheath = Color(0xFF4F8DF7);
  static const _sheathEdge = Color(0xFFBFDBFE), _body = Color(0xFF0B1430);
  static const _soot = Color(0xFFD97724), _sootHot = Color(0xFFF59E0B);
  static const _reticle = Color(0xFFFF3B2F);

  /// Organic flame boundary: a circle wobbled by a few incommensurate travelling modes.
  Path _shell(Offset c, double base, double amp, double phase) {
    final path = Path();
    const n = 120;
    for (var k = 0; k <= n; k++) {
      final a = 2 * math.pi * k / n;
      final w =
          math.sin(3 * a + 1.3 * t + phase) * .45 +
          math.sin(5 * a - 2.1 * t + 1 + phase) * .30 +
          math.sin(7 * a + 3.3 * t + 2 + phase) * .15 +
          math.sin(2 * a + .7 * t + phase) * .35;
      final rr = base * (1 + amp * w);
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Paint _radial(
    Offset c,
    double radius,
    List<Color> colors,
    List<double> stops,
  ) => Paint()
    ..shader = RadialGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromCircle(center: c, radius: radius));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final breath = 1 + .035 * math.sin(1.6 * t) + .015 * math.sin(4.3 * t);
    final flicker = .9 + .1 * math.sin(11 * t) * math.sin(7.3 * t + 1);

    // 1. Halo: the blue glow of the sheath bleeding into the dark.
    canvas.drawCircle(
      c,
      r * 2.4,
      _radial(
        c,
        r * 2.4,
        [
          _sheath.withValues(alpha: .22 * flicker),
          _sheath.withValues(alpha: .06),
          Colors.transparent,
        ],
        [0, .45, 1],
      ),
    );

    // 2. CH* sheath: additive, soft-edged, slowly breathing.
    final sheathR = r * 1.12 * breath;
    canvas.drawPath(
      _shell(c, sheathR, .05, 0),
      _radial(
          c,
          sheathR * 1.08,
          [
            Colors.transparent,
            _sheathDeep.withValues(alpha: .55),
            _sheath.withValues(alpha: .85),
            _sheathEdge.withValues(alpha: .9),
            Colors.transparent,
          ],
          [.55, .72, .86, .95, 1],
        )
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .06),
    );

    // 3. Flame body: dark blue interior (fuel-rich, little light).
    canvas.drawPath(
      _shell(c, r * .74 * breath, .05, 1.7),
      _radial(c, r * .8, [_sheathDeep, _body], [0, 1])
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .04),
    );

    // 4. Soot shell: three turbulent layers, out of phase, read as licking flame tongues.
    for (final (base, amp, phase, width, alpha, blur, color) in [
      (.70, .10, 3.1, .26, .45, .14, _soot),
      (.64, .08, 5.2, .16, .70, .08, _soot),
      (.66, .06, 1.1, .06, .95, .03, _sootHot),
    ]) {
      canvas.drawPath(
        _shell(c, r * base * breath, amp, phase),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * width
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: alpha * flicker)
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * blur),
      );
    }

    // 5. Embers: soot particles shed from the shell, drifting out with a slight curl.
    if (animate) {
      for (var i = 0; i < 46; i++) {
        final h = math.sin(i * 12.9898) * 43758.5453;
        final seed = h - h.floorToDouble();
        final life = 1.6 + seed * 1.8;
        final age = ((t + seed * 7) / life) % 1;
        final a0 = 2 * math.pi * ((i * .618034) % 1);
        final a = a0 + .5 * age * math.sin(i + t * .4);
        final dist = r * (.7 + age * (1.1 + seed * .9));
        final fade = math.sin(math.pi * age) * (1 - age * .4);
        final color = Color.lerp(_sootHot, _reticle, age)!;
        canvas.drawCircle(
          c + Offset(math.cos(a) * dist, math.sin(a) * dist),
          r * (.035 + .03 * (1 - age)) * (.6 + seed * .8),
          Paint()
            ..color = color.withValues(alpha: (.85 * fade).clamp(0, 1))
            ..blendMode = BlendMode.plus
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .02),
        );
      }
    }

    // 6. Hot core: white → amber, flickering.
    final coreR = r * .24 * (.95 + .08 * flicker);
    canvas.drawCircle(
      c,
      coreR * 1.8,
      _radial(
        c,
        coreR * 1.8,
        [
          Colors.white,
          const Color(0xFFFFE7B0),
          _sootHot.withValues(alpha: .7),
          Colors.transparent,
        ],
        [0, .3, .6, 1],
      )..blendMode = BlendMode.plus,
    );

    // 7. Reticle: the ring draws in with progress; each tick lands as its quarter completes.
    final ringR = r * 1.95;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, r * .075)
      ..strokeCap = StrokeCap.round
      ..color = _reticle;
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth
        ..color = _reticle.withValues(alpha: .12),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: ringR),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      stroke,
    );
    for (var q = 0; q < 4; q++) {
      final shown = ((progress * 4 - q) * 3).clamp(0.0, 1.0);
      if (shown == 0) continue;
      final a = -math.pi / 2 + q * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (ringR - r * .3),
        c + dir * (ringR + r * .3),
        stroke..color = _reticle.withValues(alpha: shown),
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.t != t || old.progress != progress || old.r != r;
}
