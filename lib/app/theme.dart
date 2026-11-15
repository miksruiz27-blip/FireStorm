// Habitat Fire Atlas · Design system v0.1
// Red is semantic: fire, danger, the one action that matters. If everything is red, nothing is.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const ground = Color(0xFF0E0E10); // carbon black
  static const rail = Color(0xFF0B0B0D); // nav rail, a step darker than ground
  static const card = Color(0xFF1C1D21); // graphite
  static const line = Color(0xFF2A2B2E); // graphite 2
  static const lineSelected = Color(
    0xFF4A4B50,
  ); // border of the selected row / filter
  static const lineStrong = Color(0xFF3A3B3F); // outlines, chart axes
  static const grid = Color(0xFF26272B); // chart grid
  static const chip = Color(0xFF16171A);
  static const slate = Color(0xFF1E2A38); // slate dusk, depth
  static const text = Color(0xFFF4F4F2); // livery white
  static const textMuted = Color(0xFFC9CBCF);
  static const textSoft = Color(0xFFD9DADC); // long-form reading text
  static const secondary = Color(0xFF8A8D93); // cool gray
  static const red = Color(0xFFD5001C); // racing red, risk only
  static const redDeep = Color(0xFF5A000C);

  static const depthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [slate, ground],
  );
}

abstract final class AppLayout {
  static const gutter = 24.0; // 12 col grid
  static const navRail = 72.0;
  static const telemetryBar = 64.0;
  static const radius = 6.0;
  static const hairline = 1.0;
  static const touchTarget = 44.0;
}

/// Michroma headings: call `.toUpperCase()` on the string (Flutter has no text-transform).
abstract final class AppText {
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle get display => GoogleFonts.michroma(
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: 4.48,
    color: AppColors.text,
  );
  static TextStyle get h2 => GoogleFonts.michroma(
    fontSize: 19,
    height: 26.4 / 19,
    letterSpacing: 2.66,
    color: AppColors.text,
  );
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.54,
    color: AppColors.secondary,
  );
  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 15, height: 24 / 15, color: AppColors.text);
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12,
    height: 18 / 12,
    color: AppColors.secondary,
  );
  static TextStyle get dataXL => GoogleFonts.jetBrainsMono(
    fontSize: 40,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.text,
  );
  static TextStyle get data => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.text,
  );
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontFeatures: _tabular,
    color: AppColors.secondary,
  );
}

ThemeData buildAppTheme() {
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppLayout.radius)),
  );
  const minSize = Size(0, AppLayout.touchTarget);
  final buttonText = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.68,
  );
  final disabledFg = AppColors.text.withValues(alpha: 0.45);

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.ground,
    canvasColor: AppColors.ground,
    dividerColor: AppColors.line,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.red,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.red,
      outline: AppColors.lineStrong,
      outlineVariant: AppColors.line,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    // Primary: the one red action per screen.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.red.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
        minimumSize: minSize,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: shape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        disabledForegroundColor: disabledFg,
        side: const BorderSide(
          color: AppColors.lineStrong,
          width: AppLayout.hairline,
        ),
        minimumSize: minSize,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: shape,
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        disabledForegroundColor: disabledFg,
        minimumSize: minSize,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: shape,
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.rail,
      minWidth: AppLayout.navRail,
      indicatorColor: AppColors.line,
      selectedIconTheme: IconThemeData(color: AppColors.text),
      unselectedIconTheme: IconThemeData(color: AppColors.secondary),
      labelType: NavigationRailLabelType.all,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.ground,
      indicatorColor: AppColors.line,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        AppText.label.copyWith(fontSize: 10),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.secondary,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.secondary),
      border: _inputBorder(AppColors.line),
      enabledBorder: _inputBorder(AppColors.line),
      focusedBorder: _inputBorder(AppColors.textMuted),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.red
            : Colors.transparent,
      ),
      side: const BorderSide(color: AppColors.lineStrong),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: AppText.mono.copyWith(color: AppColors.text),
    ),
  );
}

OutlineInputBorder _inputBorder(Color c) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppLayout.radius),
  borderSide: BorderSide(color: c),
);

// ───────────────────────── Signature elements ─────────────────────────

/// Two slanted bars, red + white: the app mark (nav rail, copilot answers).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _BrandMarkPainter());
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32);
    Path bar(double x) => Path()
      ..moveTo(x + 3, 26)
      ..lineTo(x + 13, 6)
      ..lineTo(x + 19, 6)
      ..lineTo(x + 9, 26)
      ..close();
    canvas
      ..drawPath(bar(0), Paint()..color = AppColors.red)
      ..drawPath(bar(9), Paint()..color = AppColors.text);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Card with the ~10° chamfer on the top-right corner (the mockups' `panel`).
/// [selected] adds the lifted gradient, red hairline and livery sweep.
class ChamferCard extends StatelessWidget {
  const ChamferCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.selected = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool selected;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _ChamferClipper(),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? null : AppColors.card,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF24272D), AppColors.card],
                stops: [0, .65],
              )
            : null,
        // ponytail: mockup also has an inset red glow; Flutter has no inset shadow, the red hairline stands in.
        border: Border.all(
          color: selected
              ? AppColors.red.withValues(alpha: .38)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: selected
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                Positioned(
                  top: -padding.top,
                  left: -padding.left,
                  child: const LiverySweep(width: 210),
                ),
              ],
            )
          : child,
    ),
  );
}

class _ChamferClipper extends CustomClipper<Path> {
  const _ChamferClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width - 64, 0)
    ..lineTo(s.width, 11)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Skewed red→transparent bar under headers and on selection.
class LiverySweep extends StatelessWidget {
  const LiverySweep({super.key, this.width = 220});
  final double width;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.centerLeft,
    transform: Matrix4.skewX(math.atan(-0.7)),
    child: Container(
      width: width,
      height: 3,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.red,
            AppColors.red,
            AppColors.redDeep,
            Color(0x000E0E10),
          ],
          stops: [0, .30, .58, 1],
        ),
      ),
    ),
  );
}

/// Progress bar with red/white curb-striped ends. [value] in 0..1.
class CurbStripe extends StatelessWidget {
  const CurbStripe({super.key, required this.value});
  final double value;

  static const cap = SizedBox(
    width: 10,
    height: 4,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.red,
            AppColors.red,
            AppColors.text,
            AppColors.text,
          ],
          stops: [0, .5, .5, 1],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 4,
    child: ColoredBox(
      color: AppColors.line,
      child: Row(
        children: [
          cap,
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: AppColors.text),
            ),
          ),
          cap,
        ],
      ),
    ),
  );
}

/// Selectable surface (card, row, filter): click cursor, keyboard focus, screen-reader state.
/// No ripple; the selected styling is the feedback.
class Tappable extends StatelessWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.selected = false,
    this.label,
  });
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: AppColors.text.withValues(alpha: .08),
        child: child,
      ),
    ),
  );
}

/// Inline citation mark `1` that points into a Sources list.
class CitationMark extends StatelessWidget {
  const CitationMark(this.n, {super.key});
  final int n;

  @override
  // No `alignment`: inside a WidgetSpan an aligned Container fills the line, which drew each
  // citation as an empty full-width bar.
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.lineStrong),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      '$n',
      style: AppText.mono.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    ),
  );
}

/// Filter / layer toggle (32px). [accent] adds the red underline used by single-choice filters.
class ToggleChip extends StatelessWidget {
  const ToggleChip(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
    this.leading,
    this.accent = false,
    this.semanticLabel,
  });
  final String label;
  final bool selected, accent;
  final VoidCallback onTap;
  final Widget? leading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Tappable(
    selected: selected,
    label: semanticLabel,
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: leading == null ? 14 : 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.card : null,
          border: Border.all(
            color: selected ? AppColors.lineSelected : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        foregroundDecoration: selected && accent
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.red, width: 2),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            ?leading,
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Thin horizontal meter: [fraction] of the track filled.
class MeterBar extends StatelessWidget {
  const MeterBar(
    this.fraction, {
    super.key,
    this.height = 4,
    this.color = AppColors.text,
  });
  final double fraction, height;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ColoredBox(
      color: AppColors.line,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0.0, 1.0),
        child: ColoredBox(color: color),
      ),
    ),
  );
}

/// Mono number + smaller gray unit: `34.0 %`, `8.2 psi`.
class DataValue extends StatelessWidget {
  const DataValue(
    this.value,
    this.unit, {
    super.key,
    this.size = 18,
    this.unitSize = 12,
  });
  final String value;
  final String unit;
  final double size;
  final double unitSize;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: value,
      style: AppText.data.copyWith(fontSize: size),
      children: [
        TextSpan(
          text: ' $unit',
          style: AppText.mono.copyWith(fontSize: unitSize),
        ),
      ],
    ),
  );
}

/// Fuel phase is encoded by shape + lightness, never hue.
enum Fuel { solid, liquid, gas }

class FuelMarker extends StatelessWidget {
  const FuelMarker(this.fuel, {super.key, this.size = 8});
  final Fuel fuel;
  final double size;

  @override
  Widget build(BuildContext context) => switch (fuel) {
    Fuel.solid => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.text,
        shape: BoxShape.circle,
      ),
    ),
    Fuel.liquid => Container(
      width: size,
      height: size,
      color: AppColors.secondary,
    ),
    Fuel.gas => Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size - 1,
        height: size - 1,
        decoration: BoxDecoration(border: Border.all(color: AppColors.text)),
      ),
    ),
  };
}

enum TagLevel { neutral, high, critical }

/// Small chip. [mono] for status/data tags (NOMINAL, CRITICAL, [1]); Inter otherwise.
class AppTag extends StatelessWidget {
  const AppTag(
    this.label, {
    super.key,
    this.leading,
    this.mono = false,
    this.level = TagLevel.neutral,
  });
  final String label;
  final Widget? leading;
  final bool mono;
  final TagLevel level;

  @override
  Widget build(BuildContext context) {
    final critical = level == TagLevel.critical;
    final style = mono
        ? AppText.mono.copyWith(fontSize: 11, letterSpacing: 1.1)
        : GoogleFonts.inter(fontSize: 12);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: critical ? AppColors.red : AppColors.chip,
        border: Border.all(
          color: switch (level) {
            TagLevel.neutral => mono ? AppColors.lineStrong : AppColors.line,
            _ => AppColors.red,
          },
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: switch (level) {
                  TagLevel.neutral => AppColors.textMuted,
                  TagLevel.high => AppColors.text,
                  TagLevel.critical => Colors.white,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
