import 'dart:math' as math;

/// ============================================================================
/// 1. MOTOR FÍSICO Y MODELO IA (PESOS EXACTOS DE model.json + DATOS NASA PSI)
/// ============================================================================
class FlamePhysicsResult {
  final double burnProb;
  final bool isCoolFlame;
  final double tempK;
  final double sootLevel; // 0.0 - 1.0
  final double spreadRateMmS;
  final double aspectRatio;
  final String regimeName;
  final String modificationRequired;

  const FlamePhysicsResult({
    required this.burnProb,
    required this.isCoolFlame,
    required this.tempK,
    required this.sootLevel,
    required this.spreadRateMmS,
    required this.aspectRatio,
    required this.regimeName,
    required this.modificationRequired,
  });
}

class FirestormPhysicsEngine {
  // Pesos entrenados exportados en model.json v2.2-Firestorm-Enhanced-NonLinear-UCurve-and-26PSI
  // Modelo Lineal Base (n=347 BASS + 1066 registros unificados)
  static const List<double> mean = [20.30893371, 99.16023153, 7.47752162];
  static const List<double> std  = [7.98718034,  24.22627942, 9.25891496];
  static const List<double> coef = [6.91185045,  1.41759789, -0.54146713];
  static const double intercept  = 1.39760423;

  // Modelo Polinomial Cuadrático (Curva-U en microgravedad, ROC-AUC = 0.9947)
  static const List<double> polyMean = [20.30893371, 99.16023153, 7.47752162, 476.24783822, 2000.68189145, 151.93789586, 10419.66405687, 723.94724217, 141.64083571];
  static const List<double> polyStd  = [7.98718034,  24.22627942, 9.25891496, 782.96771931,  981.21111424, 175.85272843,  7040.62138853, 902.81745398, 301.98203107];
  static const List<double> polyCoef = [3.99038434,  0.50505549,  2.09220338,   1.23499072,    3.43201947,   3.41061616,     0.35504466,   2.20769477, -10.21895599];
  static const double polyIntercept  = 1.30763960;

  static FlamePhysicsResult evaluate({
    required double o2Pct,
    required double pressureKpa,
    required double flowCmS,
    required double gravityG,
    required int fuelIdx, // 0: Esfera PMMA, 1: Placa PMMA, 2: Gota Heptano, 3: Cinta SIBAL
    required bool forceCoolFlame,
  }) {
    final polyFeatures = [
      o2Pct, pressureKpa, flowCmS,
      o2Pct * o2Pct, o2Pct * pressureKpa, o2Pct * flowCmS,
      pressureKpa * pressureKpa, pressureKpa * flowCmS, flowCmS * flowCmS,
    ];
    double logit = polyIntercept;
    for (int i = 0; i < 9; i++) {
      logit += ((polyFeatures[i] - polyMean[i]) / polyStd[i]) * polyCoef[i];
    }

    double prob = 1.0 / (1.0 + math.exp(-logit));

    // Reglas físicas de frontera NASA BASS / FLEX / SAFFIRE:
    // 1) Quenching radiativo a flujo casi nulo en microgravedad (0g)
    final effectiveVel = math.sqrt(flowCmS * flowCmS + math.pow(gravityG * 22.0, 2));
    if (effectiveVel < 0.6 && o2Pct < 18.5) {
      final quench = math.max(0.05, (effectiveVel / 0.6) * ((o2Pct - 14.5) / 4.0));
      prob *= math.min(1.0, quench);
    }
    // 2) Límite MOC (Minimum Oxygen Concentration)
    if (o2Pct < 15.6) {
      prob *= (math.max(0.0, (o2Pct - 13.8) / 1.8) * 0.35);
    }
    // 3) Blowoff aerodinámico (> 30-35 cm/s)
    final blowoffLimit = 30.0 + (o2Pct - 18.0) * 1.1;
    if (flowCmS > blowoffLimit - 4.0) {
      final blowoff = math.max(0.0, 1.0 - (flowCmS - (blowoffLimit - 4.0)) / 8.0);
      prob *= blowoff;
    }

    final isCool = forceCoolFlame ||
        (fuelIdx == 2 && prob < 0.48 && o2Pct >= 14.5 && flowCmS < 12.0);

    double tempK;
    if (isCool) {
      tempK = 580.0 + (o2Pct - 14.0) * 11.0 + math.min(flowCmS, 6.0) * 8.0;
    } else if (prob < 0.22) {
      tempK = 520.0 + o2Pct * 9.0;
    } else {
      final flowBoost = math.sin(math.min(flowCmS, 18.0) / 18.0 * math.pi * 0.5) * 190.0;
      final pressBoost = (pressureKpa - 101.3) * 1.4;
      tempK = (990.0 + (o2Pct - 15.5) * 44.0 + flowBoost + pressBoost).clamp(980.0, 1895.0);
    }

    double soot = 0.0;
    if (!isCool && prob >= 0.22) {
      final fuelMult = fuelIdx == 3 ? 0.65 : (fuelIdx == 2 ? 0.9 : 1.0);
      final o2Soot = math.max(0.0, (o2Pct - 17.2) / 12.0);
      final flowSoot = math.min(1.0, (effectiveVel + 0.5) / 8.0) *
          math.max(0.2, 1.0 - math.max(0.0, flowCmS - 18.0) / 22.0);
      final pressSoot = math.pow(pressureKpa / 101.3, 1.3).toDouble();
      soot = (o2Soot * flowSoot * pressSoot * fuelMult * 1.35).clamp(0.0, 1.0);
    }

    double spreadRate = 0.0;
    if (prob >= 0.22 || isCool) {
      final baseRate = fuelIdx == 3 ? 1.45 : (fuelIdx == 2 ? 0.78 : 0.38);
      spreadRate = baseRate *
          (0.4 + 0.6 * prob) *
          (1.0 + math.min(flowCmS, 25.0) * 0.035) *
          (o2Pct / 20.9);
      if (isCool) spreadRate *= 0.42;
    }

    final stretchFlow = 1.0 + (flowCmS / 14.0) * 1.35;
    final stretchGrav = 1.0 + gravityG * 2.15;
    final aspect = math.sqrt(stretchFlow * stretchFlow + stretchGrav * stretchGrav - 1.0);

    String regime;
    String mod;
    if (isCool) {
      regime = 'Sustained_NTC_CoolFlame (FLEX-2 / CFI)';
      mod = 'Activar sensores IR y CO/formaldehído; mantener ventilación cerrada para evitar reignición.';
    } else if (prob < 0.22 && flowCmS > 26.0) {
      regime = 'Convective_Strain_Blowoff (BASS-II)';
      mod = 'Extinción por estiramiento aerodinámico (>30 cm/s). Cortar ventilación HVAC a 0 cm/s es el protocolo seguro.';
    } else if (prob < 0.22) {
      regime = 'Radiative_Oxygen_Limit_Quench (PSI-25)';
      mod = 'Extinción radiativa por agotamiento de capa límite de O2 en microgravedad.';
    } else if (gravityG < 0.05 && flowCmS < 2.0) {
      regime = 'Dim_Blue_Hemispherical_Spread (0g Pure Diffusion)';
      mod = 'Llama esférica azul casi invisible: calibrar fotodiodos UV/IR de alta ganancia.';
    } else if (o2Pct >= 26.0) {
      regime = 'Exploration_Atmosphere_Burn (Artemis / SoFIE)';
      mod = 'Peligro por atmósfera enriquecida (>30% O2): reemplazar PMMA expuesto por Ultem o Nomex HT90-40.';
    } else {
      regime = 'Concurrent_BoundaryLayer_Spread (BASS / SAFFIRE)';
      mod = 'Flujo HVAC (${flowCmS.toStringAsFixed(1)} cm/s) alimenta O2 a la zona de pirólisis; apagar ventiladores ante humo.';
    }

    return FlamePhysicsResult(
      burnProb: prob,
      isCoolFlame: isCool,
      tempK: tempK,
      sootLevel: soot,
      spreadRateMmS: spreadRate,
      aspectRatio: aspect,
      regimeName: regime,
      modificationRequired: mod,
    );
  }
}

