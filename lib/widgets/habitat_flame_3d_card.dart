import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../app/i18n.dart';
import '../data/flame_3d_physics.dart';

/// ============================================================================
/// WIDGET EMBEBIBLE DISEÑADO CON EL TEMA EXACTO DE "HABITAT FIRE ATLAS"
/// Integra el análisis completo de los 26 programas de combustión de NASA PSI:
/// - Propulsor 3D Aeroespacial Sólido Sombreado (Cabezal TVC, Colector, Garganta M=1,
///   Campana De Laval con canales regenerativos, aros rígidos y tuberías LOX/Fuel)
/// - Transición morfológica continua: Esfera de Difusión 0g (ACME s-Flame PSI-23) <->
///   Cono de Capa Límite / Chorro Supersónico (BASS / SAFFIRE / SPICE)
/// - Desprendimiento Tri-Braquial (Liftoff H_L en CLD PSI-21 / SLICE PSI-106) y Blowoff (Da < 1)
/// - Apertura Radiativa de Punta (Tip-Opening Soot Wings en SPICE PSI-107) y Humo SAME (CMD μm)
/// - Inestabilidad Pulsante Difusivo-Térmica por Número de Lewis (Le > 1 en Ar / PSI-23)
/// - Régimen de Llama Fría NTC de 2 Etapas (Formaldehído Excitado HCHO* 665K en FLEX-2 / CFI)
/// ============================================================================
class HabitatFlame3DCard extends StatefulWidget {
  final double o2Percent;
  final double pressurePsi;
  final double forcedFlowCmS;
  final double gravityG;
  final String materialName;
  final String diluentGas; // 'N2', 'CO2', 'He', 'Ar'

  const HabitatFlame3DCard({
    super.key,
    required this.o2Percent,
    required this.pressurePsi,
    required this.forcedFlowCmS,
    required this.gravityG,
    this.materialName = 'PMMA',
    this.diluentGas = 'N2',
  });

  @override
  State<HabitatFlame3DCard> createState() => _HabitatFlame3DCardState();
}

class _HabitatFlame3DCardState extends State<HabitatFlame3DCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  double _time = 0.0;
  double _camYaw = 0.24;
  double _camPitch = 0.16;
  final double _camDist = 2.20;
  bool _autoRotate = true;
  bool _coolFlameMode = false;

  double _rProb = 0.9;
  double _rO2 = 30.0;
  double _rFlow = 5.0;
  double _rGrav = 0.166;
  double _rSoot = 0.3;

  int get _fuelIdx {
    final m = widget.materialName.toLowerCase();
    if (m.contains('cotton') || m.contains('sibal')) return 3;
    if (m.contains('silicone')) return 1;
    if (m.contains('heptane') || m.contains('decane') || m.contains('droplet')) return 2;
    if (m.contains('ethylene') || m.contains('methane') || m.contains('jet')) return 4;
    if (m.contains('nomex') || m.contains('aramid')) return 5;
    return 0; // PMMA
  }

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _ticker = createTicker((elapsed) {
      final res = _evalCurrent();
      const k = 0.10;
      setState(() {
        _time = elapsed.inMilliseconds / 1000.0;
        _rProb += (res.burnProb - _rProb) * k;
        _rO2   += (widget.o2Percent - _rO2) * k;
        _rFlow += (widget.forcedFlowCmS - _rFlow) * k;
        _rGrav += (widget.gravityG - _rGrav) * k;
        _rSoot += (res.sootLevel - _rSoot) * k;
        if (_autoRotate) {
          _camYaw = 0.26 * math.sin(_time * 0.65);
          _camPitch = 0.16 + 0.07 * math.cos(_time * 0.50);
        }
      });
    });
    if (!isTest) {
      _ticker.start();
    }
  }

  FlamePhysicsResult _evalCurrent() {
    final pressureKpa = widget.pressurePsi * 6.89476;
    return FirestormPhysicsEngine.evaluate(
      o2Pct: widget.o2Percent,
      pressureKpa: pressureKpa,
      flowCmS: widget.forcedFlowCmS,
      gravityG: widget.gravityG,
      fuelIdx: _fuelIdx > 3 ? 0 : _fuelIdx,
      forceCoolFlame: _coolFlameMode,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = _evalCurrent();
    final pressKpa = widget.pressurePsi * 6.89476;
    final absGrav = widget.gravityG.abs();
    final uBuoyMag = 26.2 * math.sqrt(absGrav) * math.pow(pressKpa / 101.3, 0.35);
    final uBuoy = (widget.gravityG >= 0 ? 1.0 : -1.0) * uBuoyMag;
    final effVel = math.sqrt(widget.forcedFlowCmS * widget.forcedFlowCmS + uBuoyMag * uBuoyMag);

    // Propiedades del diluyente (N2, CO2, He, Ar)
    final alphaFactor = widget.diluentGas == 'He' ? 2.65 : (widget.diluentGas == 'CO2' ? 0.78 : 1.0);
    final leFactor = widget.diluentGas == 'He' ? 1.48 : (widget.diluentGas == 'Ar' ? 1.32 : (widget.diluentGas == 'CO2' ? 0.86 : 1.0));
    final lewisNumber = 1.08 * leFactor * (1.0 + math.max(0.0, 2.0 - effVel) * 0.06);

    final tauFlow = 14.5 / math.max(0.7, effVel * alphaFactor);
    final tauChem = 1.12 * math.pow(20.9 / math.max(10.0, widget.o2Percent), 2.1) * math.pow(101.3 / pressKpa, 0.75);
    final damkohler = tauFlow / tauChem;

    final strainRatio = widget.forcedFlowCmS / math.max(12.0, 22.0 + (widget.o2Percent - 18.0) * 1.15);
    final liftoffMm = math.max(0.0, (strainRatio - 0.52) * 26.0 + math.max(0.0, (18.5 - widget.o2Percent) * 0.85));
    final sootPpm = res.sootLevel * 3.40;
    final isTipOpen = !res.isCoolFlame && res.burnProb >= 0.25 && sootPpm > 1.35;
    final isPulsating = !res.isCoolFlame && res.burnProb >= 0.14 && ((res.burnProb < 0.42 && lewisNumber > 1.05) || widget.diluentGas == 'Ar');
    final smokeCmdUm = res.burnProb >= 0.20 ? (0.36 * (0.75 + 0.65 * res.sootLevel) * math.pow(pressKpa / 101.3, 0.4)) : 0.0;
    final expRatio = (101.3 / pressKpa) * (1.0 + (widget.forcedFlowCmS / 25.0) * 0.65 + (widget.o2Percent / 30.0) * 0.35);

    final isCritical = res.burnProb >= 0.70;
    final isExtinct = res.burnProb < 0.20 && !res.isCoolFlame;

    return Container(
      height: 440,
      decoration: BoxDecoration(
        color: const Color(0xFF16191E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2D333B), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        '3D REGENERATIVE DE LAVAL THRUSTER & MULTI-REGIME CONE · NASA PSI',
                        'PROPULSOR DE LAVAL REGENERATIVO 3D Y CONO MULTIRRÉGIMEN · NASA PSI',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      res.regimeName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExtinct
                        ? const Color(0xFF2E7D32)
                        : (res.isCoolFlame
                            ? const Color(0xFF6D28D9)
                            : (isCritical ? const Color(0xFFE51937) : const Color(0xFFD97706))),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExtinct
                        ? tr('QUENCHED', 'APAGADA')
                        : (res.isCoolFlame
                            ? tr('COOL FLAME NTC', 'LLAMA FRÍA NTC')
                            : (isPulsating
                                ? tr('LEWIS PULSATING', 'PULSANTE (LEWIS)')
                                : (liftoffMm > 4.0
                                    ? tr('LIFTED TRIPLE-FLAME', 'LLAMA TRIPLE DESPEGADA')
                                    : tr('SUSTAINED CONE BURN', 'COMBUSTIÓN EN CONO SOSTENIDA')))),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2D333B)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onPanStart: (_) => _autoRotate = false,
                    onPanUpdate: (d) {
                      setState(() {
                        _camYaw -= d.delta.dx * 0.01;
                        _camPitch = (_camPitch + d.delta.dy * 0.01).clamp(-1.3, 1.3);
                      });
                    },
                    child: CustomPaint(
                      painter: _RealisticThruster3DPainter(
                        time: _time,
                        camYaw: _camYaw,
                        camPitch: _camPitch,
                        camDist: _camDist,
                        burnProb: _rProb,
                        o2: _rO2,
                        flow: _rFlow,
                        gravity: _rGrav,
                        effVel: effVel,
                        uBuoy: uBuoy,
                        soot: _rSoot,
                        tempK: res.tempK,
                        expRatio: expRatio,
                        liftoffMm: liftoffMm,
                        isTipOpen: isTipOpen,
                        isPulsating: isPulsating,
                        isSilicone: _fuelIdx == 1,
                        coolFlame: _coolFlameMode ? 1.0 : 0.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 9,
                  left: 11,
                  right: 11,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E14).withValues(alpha: 0.88),
                      border: Border.all(color: const Color(0xFF2D333B)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'T_FLAME: ${res.tempK.round()} K  |  Da: ${damkohler.toStringAsFixed(2)}  |  Le: ${lewisNumber.toStringAsFixed(2)}\n'
                      '${tr('LIFTOFF', 'DESPEGUE')} H_L: ${liftoffMm.toStringAsFixed(1)} mm  |  ${tr('SOOT', 'HOLLÍN')} f_v: ${sootPpm.toStringAsFixed(2)} ppm (CMD ${smokeCmdUm.toStringAsFixed(2)}μm)',
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 11.5,
                        height: 1.45,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniBtn(tr('COOL FLAME NTC', 'LLAMA FRÍA NTC'), _coolFlameMode, () {
                        setState(() => _coolFlameMode = !_coolFlameMode);
                      }),
                      _miniBtn(tr('0g TOP', 'VISTA SUPERIOR 0g'), false, () {
                        setState(() {
                          _autoRotate = false;
                          _camYaw = 0.0;
                          _camPitch = 1.3;
                        });
                      }),
                      _miniBtn(tr('NOZZLE PROFILE', 'PERFIL DE TOBERA'), false, () {
                        setState(() {
                          _autoRotate = false;
                          _camYaw = 0.0;
                          _camPitch = 0.05;
                        });
                      }),
                      _miniBtn(tr('3D ORBIT', 'ÓRBITA 3D'), _autoRotate, () {
                        setState(() => _autoRotate = !_autoRotate);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE51937) : const Color(0xFF0D0F12).withValues(alpha: 0.85),
          border: Border.all(color: active ? const Color(0xFFE51937) : const Color(0xFF2D333B)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFB0BEC5),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _ThrusterDrawItem {
  final String type;
  final double z;
  final List<Offset>? pts;
  final Color? fill;
  final Color? stroke;
  final bool hasRing;
  final bool isHotExit;
  final Offset? proj;
  final double? rPx;
  final double? t;
  final double? shock;

  _ThrusterDrawItem({
    required this.type,
    required this.z,
    this.pts,
    this.fill,
    this.stroke,
    this.hasRing = false,
    this.isHotExit = false,
    this.proj,
    this.rPx,
    this.t,
    this.shock,
  });
}

class _RealisticThruster3DPainter extends CustomPainter {
  final double time, camYaw, camPitch, camDist, burnProb, o2, flow, gravity, effVel, uBuoy, soot, tempK, expRatio, liftoffMm, coolFlame;
  final bool isTipOpen, isPulsating, isSilicone;

  _RealisticThruster3DPainter({
    required this.time,
    required this.camYaw,
    required this.camPitch,
    required this.camDist,
    required this.burnProb,
    required this.o2,
    required this.flow,
    required this.gravity,
    required this.effVel,
    required this.uBuoy,
    required this.soot,
    required this.tempK,
    required this.expRatio,
    required this.liftoffMm,
    required this.isTipOpen,
    required this.isPulsating,
    required this.isSilicone,
    required this.coolFlame,
  });

  double _smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF080A0F));

    final cosY = math.cos(camYaw), sinY = math.sin(camYaw);
    final cosP = math.cos(camPitch), sinP = math.sin(camPitch);
    final fov = size.shortestSide * 0.96;

    ({Offset pt, double z, double scale}) proj(double wx, double wy, double wz) {
      final x1 = wx * cosY - wz * sinY;
      final z1 = wx * sinY + wz * cosY;
      final y2 = wy * cosP - z1 * sinP;
      final z2 = math.max(0.35, wy * sinP + z1 * cosP + camDist);
      final p = fov / z2;
      return (
        pt: Offset(size.width * 0.5 + x1 * p, size.height * 0.55 - y2 * p),
        z: z2,
        scale: p
      );
    }

    final buoyPitch = math.atan2(uBuoy * 0.18, math.max(2.5, flow + 3.0)) * 0.45;
    final dirX = math.cos(buoyPitch);
    final dirY = math.sin(buoyPitch);
    final upX = -dirY;
    final upY = dirX;

    final sphereBlend = math.max(0.0, 1.0 - _smoothstep(0.25, 2.8, effVel));
    final lewisPulse = isPulsating ? (0.72 + 0.28 * math.sin(time * 24.0)) : 1.0;

    final rawLen = 0.68 * sphereBlend +
        (1.0 - sphereBlend) * (1.22 + math.min(1.20, flow * 0.028) + (o2 - 15.0) * 0.024);
    final coneLen = rawLen * (0.40 + 0.60 * math.min(1.0, burnProb * 1.25)) * (0.88 + 0.12 * lewisPulse);
    final nozX = -dirX * 0.38;
    final nozY = -dirY * 0.38;

    final List<_ThrusterDrawItem> list = [];

    // Perfil 3D realista del propulsor De Laval
    final profile = [
      (ax: -0.76, r: 0.035, m: [75, 85, 102],   h: 0.00, ring: false),
      (ax: -0.66, r: 0.095, m: [95, 108, 128],  h: 0.00, ring: true),
      (ax: -0.56, r: 0.145, m: [120, 132, 150], h: 0.05, ring: true),
      (ax: -0.46, r: 0.142, m: [88, 98, 115],   h: 0.18, ring: false),
      (ax: -0.36, r: 0.118, m: [78, 88, 104],   h: 0.42, ring: true),
      (ax: -0.27, r: 0.076, m: [70, 78, 94],    h: 0.85, ring: true),
      (ax: -0.19, r: 0.108, m: [64, 72, 86],    h: 0.65, ring: false),
      (ax: -0.11, r: 0.142, m: [58, 65, 78],    h: 0.50, ring: true),
      (ax: -0.04, r: 0.168, m: [52, 58, 70],    h: 0.60, ring: false),
      (ax:  0.00, r: 0.182, m: [48, 54, 66],    h: 0.92, ring: true),
    ];

    final glowFactor = burnProb > 0.18 ? ((tempK - 720.0) / 1080.0).clamp(0.0, 1.0) : 0.0;
    const int nAz = 22;

    for (int i = 0; i < profile.length - 1; i++) {
      final s0 = profile[i];
      final s1 = profile[i + 1];
      final c0x = nozX + dirX * s0.ax, c0y = nozY + dirY * s0.ax;
      final c1x = nozX + dirX * s1.ax, c1y = nozY + dirY * s1.ax;

      for (int k = 0; k < nAz; k++) {
        final a0 = (k / nAz) * math.pi * 2;
        final a1 = ((k + 1) / nAz) * math.pi * 2;
        final aMid = (a0 + a1) * 0.5;

        final p00 = proj(c0x + upX * math.cos(a0) * s0.r, c0y + upY * math.cos(a0) * s0.r, math.sin(a0) * s0.r);
        final p01 = proj(c0x + upX * math.cos(a1) * s0.r, c0y + upY * math.cos(a1) * s0.r, math.sin(a1) * s0.r);
        final p11 = proj(c1x + upX * math.cos(a1) * s1.r, c1y + upY * math.cos(a1) * s1.r, math.sin(a1) * s1.r);
        final p10 = proj(c1x + upX * math.cos(a0) * s1.r, c1y + upY * math.cos(a0) * s1.r, math.sin(a0) * s1.r);

        final nx = upX * math.cos(aMid);
        final ny = upY * math.cos(aMid);
        final nz = math.sin(aMid);
        final ndotl = math.max(0.08, nx * -0.45 + ny * 0.72 + nz * 0.52);
        final spec = math.pow(math.max(0.0, ndotl), 9.0) * 0.65;
        final groove = (k % 2 == 0) ? 0.92 : 1.06;
        final avgH = ((s0.h + s1.h) * 0.5) * glowFactor;

        final rC = (s0.m[0] * ndotl * groove + spec * 180 + avgH * 220).round().clamp(0, 255);
        final gC = (s0.m[1] * ndotl * groove + spec * 195 + avgH * (75 + avgH * 90)).round().clamp(0, 255);
        final bC = (s0.m[2] * ndotl * groove + spec * 215 + avgH * 25).round().clamp(0, 255);

        list.add(_ThrusterDrawItem(
          type: 'quad',
          z: (p00.z + p01.z + p11.z + p10.z) * 0.25,
          pts: [p00.pt, p01.pt, p11.pt, p10.pt],
          fill: Color.fromARGB(255, rC, gC, bC),
          stroke: Color.fromARGB(90, (rC + 25).clamp(0, 255), (gC + 25).clamp(0, 255), (bC + 30).clamp(0, 255)),
          hasRing: s1.ring,
          isHotExit: i == profile.length - 2,
        ));
      }
    }

    if (burnProb > 0.03 || coolFlame > 0.2) {
      final liftoff3D = math.min(0.34, (liftoffMm / 25.0) * 0.26);
      final shockCycles = (4.0 + (flow / 10.0) - (expRatio - 1.0) * 0.7).clamp(2.5, 8.5);
      final underExp = math.pow(expRatio, 0.32).toDouble().clamp(0.88, 1.42);
      const int nSlices = 60;

      for (int i = 0; i < nSlices; i++) {
        final t = i / (nSlices - 1);
        final wave = (1.0 - sphereBlend * 0.85) *
            math.sin(time * (13.0 + flow * 0.44) - t * 12.0) *
            (0.002 + 0.02 * math.pow(t, 1.8));
        final dist = liftoff3D + t * coneLen;
        final wx = nozX + dirX * dist + upX * wave;
        final wy = nozY + dirY * dist + upY * wave;
        final p = proj(wx, wy, 0.0);

        final sphereProf = math.pow(math.max(0.02, math.sin(t * math.pi * 0.96)), 0.58).toDouble() * 1.32;
        final nozMatch = 0.78 + 0.22 * _smoothstep(0.0, 0.08, t) * underExp;
        final tipOpenFloor = isTipOpen ? 0.26 * math.pow(t, 1.4).toDouble() : 0.008;
        final coneProf = nozMatch * (math.pow(math.max(0.008, 1.0 - t), 0.76).toDouble() + tipOpenFloor);
        final combinedShape = sphereBlend * sphereProf + (1.0 - sphereBlend) * coneProf;

        final shock = (1.0 - sphereBlend * 0.9) *
            math.pow(math.max(0.0, math.cos((t * shockCycles - time * 3.6) * math.pi)), 5.0).toDouble() *
            (1.0 - t * 0.68);
        final r3D = 0.205 * (0.86 + 0.18 * (o2 / 25.0)) * lewisPulse * combinedShape * (1.0 + 0.15 * shock);

        list.add(_ThrusterDrawItem(
          type: 'cone',
          z: p.z - t * 0.002,
          proj: p.pt,
          rPx: math.max(2.0, r3D * p.scale),
          t: t,
          shock: shock,
        ));
      }
    }

    list.sort((a, b) => b.z.compareTo(a.z));

    for (final it in list) {
      if (it.type == 'quad') {
        final pts = it.pts!;
        final path = Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy)
          ..lineTo(pts[3].dx, pts[3].dy)
          ..close();
        canvas.drawPath(path, Paint()..color = it.fill!);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = it.stroke!,
        );
        if (it.hasRing) {
          canvas.drawLine(
            pts[3],
            pts[2],
            Paint()
              ..strokeWidth = it.isHotExit ? 2.4 : 1.6
              ..color = (it.isHotExit && burnProb > 0.2)
                  ? const Color(0xFFFB923C)
                  : const Color(0xA694A3B8),
          );
        }
      } else if (it.type == 'cone') {
        final c = it.proj!;
        final rPx = it.rPx!;
        final t = it.t!;
        final shock = it.shock!;
        final life = (burnProb * 1.35 + coolFlame * 0.85).clamp(0.0, 1.0);
        final sootBlend = (soot * 1.35).clamp(0.0, 1.0);

        final outerPaint = Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            c,
            rPx * 1.4,
            [
              (sootBlend > 0.25 ? const Color(0xFFFFC65F) : const Color(0xFF7DD3FC))
                  .withValues(alpha: 0.14 * (1.0 - t * 0.35) * life),
              Color.lerp(const Color(0xFF0EA5E9), const Color(0xFFE51937), (t * 1.05 * sootBlend).clamp(0.0, 1.0))!
                  .withValues(alpha: 0.12 * (1.0 - t * 0.45) * life),
              Colors.transparent,
            ],
            const [0.0, 0.58, 1.0],
          );
        canvas.drawCircle(c, rPx * 1.4, outerPaint);

        final tipQuench = (isTipOpen && t > 0.72) ? math.max(0.15, 1.0 - (t - 0.72) * 3.0) : 1.0;
        final coreR = rPx * (0.68 + 0.26 * shock);
        final coreAlpha = ((0.18 * (1.0 - t * 0.45) + shock * 0.30) * life * tipQuench).clamp(0.0, 0.85);
        final corePaint = Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            c,
            coreR,
            [
              Colors.white.withValues(alpha: (coreAlpha * 1.5).clamp(0.0, 0.85)),
              (sootBlend > 0.22 ? const Color(0xFFFEF08A) : const Color(0xFF38BDF8)).withValues(alpha: coreAlpha),
              Colors.transparent,
            ],
            const [0.0, 0.55, 1.0],
          );
        canvas.drawCircle(c, coreR, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticThruster3DPainter oldDelegate) => true;
}
