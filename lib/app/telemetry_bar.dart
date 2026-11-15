import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/api.dart';
import '../data/habitats.dart';
import '../data/investigations.dart';
import 'i18n.dart';
import 'theme.dart';

/// 64px top bar shared by every screen: brand, live readouts of the selected habitat, sync status.
class TelemetryBar extends ConsumerWidget {
  const TelemetryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(selectedHabitatProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    const divider = Border(left: BorderSide(color: AppColors.line));

    return Container(
      height: AppLayout.telemetryBar,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.slate, Color(0xFF151B24), AppColors.ground],
          stops: [0, .4, .78],
        ),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 10, 24, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIRESTORM',
                    style: AppText.h2.copyWith(
                      fontSize: 13,
                      letterSpacing: 1.82,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'NASA PSI · MICROGRAVITY COMBUSTION',
                      'NASA PSI · COMBUSTIÓN EN MICROGRAVEDAD',
                    ),
                    style: AppText.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const _Slash(),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Readout(
                    tr('AMBIENT', 'HÁBITAT'),
                    Text(
                      h.name.toUpperCase(),
                      style: AppText.h2.copyWith(
                        fontSize: 12,
                        letterSpacing: 1.68,
                      ),
                    ),
                  ),
                  _Readout('O₂', DataValue(h.o2.toStringAsFixed(1), '%')),
                  _Readout(
                    tr('PRESSURE', 'PRESIÓN'),
                    DataValue(h.pressure.toStringAsFixed(1), 'psi'),
                  ),
                  _Readout(
                    tr('GRAVITY', 'GRAVEDAD'),
                    DataValue(h.gravityLabel, 'g'),
                  ),
                  _Readout(
                    tr('FLAMMABILITY', 'INFLAMABILIDAD'),
                    AppTag(h.riskLabel, mono: true, level: h.risk),
                  ),
                ],
              ),
            ),
          ),
          if (wide)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: const BoxDecoration(border: divider),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.text,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.text.withValues(alpha: .6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder(
                    valueListenable: apiLive,
                    builder: (_, live, _) => Text(switch (live) {
                      true => tr('API LIVE', 'API EN VIVO'),
                      false => tr('SNAPSHOT', 'SIN CONEXIÓN'),
                      null => tr('SYNCING', 'SINCRONIZANDO'),
                    }, style: AppText.label),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${ref.watch(experimentsProvider).value?.length ?? '–'} INV',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 3),
        value,
      ],
    ),
  );
}

/// Red slanted divider after the brand block.
class _Slash extends StatelessWidget {
  const _Slash();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 72,
    child: ClipPath(
      clipper: _SlashClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.red, AppColors.redDeep],
          ),
        ),
      ),
    ),
  );
}

class _SlashClipper extends CustomClipper<Path> {
  const _SlashClipper();
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * .72, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width * .28, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}
