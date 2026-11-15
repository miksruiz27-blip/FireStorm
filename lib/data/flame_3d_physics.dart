import 'dart:math' as math;

class NasaPsiExperiment {
  final String id;
  final String study;
  final int mat;
  final String diluent;
  final double o2;
  final double pKpa;
  final double flow;
  final double g;
  final double rate;
  final double tempK;
  final String out;
  final String desc;

  const NasaPsiExperiment({
    required this.id,
    required this.study,
    required this.mat,
    required this.diluent,
    required this.o2,
    required this.pKpa,
    required this.flow,
    required this.g,
    required this.rate,
    required this.tempK,
    required this.out,
    required this.desc,
  });
}

const List<NasaPsiExperiment> nasaPsiExperiments = [
  NasaPsiExperiment(id: 'PSI23-01', study: 'ACME s-Flame 0g Spherical Blue', mat: 4, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 0.2, g: 0.0, rate: 0.45, tempK: 1210, out: 'burn', desc: 'Esfera de difusión pura 0g libre de hollín (CH* azul)'),
  NasaPsiExperiment(id: 'PSI23-03', study: 'ACME s-Flame Lewis Pulsating', mat: 4, diluent: 'Ar', o2: 17.5, pKpa: 101.3, flow: 0.4, g: 0.0, rate: 0.18, tempK: 1060, out: 'pulsate', desc: 'Inestabilidad pulsante difusivo-térmica (Le > 1) previo a extinción'),
  NasaPsiExperiment(id: 'PSI25-01', study: 'BASS-II Opposed Cotton-Glass', mat: 3, diluent: 'N2', o2: 18.5, pKpa: 101.3, flow: 3.5, g: 0.0, rate: 1.85, tempK: 1180, out: 'burn', desc: 'Frente semiesférico azul brillante en tejido SIBAL'),
  NasaPsiExperiment(id: 'PSI25-02', study: 'BASS-II Ultra-Low Flow Dome', mat: 3, diluent: 'N2', o2: 17.2, pKpa: 101.2, flow: 0.8, g: 0.0, rate: 0.62, tempK: 1040, out: 'burn', desc: 'Llama domo controlada por difusión de O2 sin hollín'),
  NasaPsiExperiment(id: 'PSI25-03', study: 'BASS-II Hypoxic MOC Quench', mat: 3, diluent: 'N2', o2: 15.4, pKpa: 100.8, flow: 1.0, g: 0.0, rate: 0.00, tempK: 690, out: 'extinct', desc: 'Extinción radiativa bajo el límite MOC en microgravedad'),
  NasaPsiExperiment(id: 'PSI25-04', study: 'BASS-II High-Flow Blowoff', mat: 3, diluent: 'N2', o2: 17.8, pKpa: 101.1, flow: 38.0, g: 0.0, rate: 0.00, tempK: 650, out: 'extinct', desc: 'Desprendimiento aerodinámico (Damköhler Da < 1.0)'),
  NasaPsiExperiment(id: 'PSI25-05', study: 'BASS-II PMMA Peak HVAC Flow', mat: 0, diluent: 'N2', o2: 19.4, pKpa: 101.3, flow: 8.5, g: 0.0, rate: 0.48, tempK: 1290, out: 'burn', desc: 'Cono luminoso amarillo con burbujeo superficial de monómero MMA'),
  NasaPsiExperiment(id: 'PSI25-07', study: 'BASS-II Radiative Loss Quench', mat: 0, diluent: 'N2', o2: 16.2, pKpa: 100.6, flow: 0.4, g: 0.0, rate: 0.00, tempK: 730, out: 'extinct', desc: 'Agotamiento de O2 en capa límite estacionaria y enfriamiento radiativo'),
  NasaPsiExperiment(id: 'PSI25-08', study: 'BASS-II Clear Acrylic Tail', mat: 0, diluent: 'N2', o2: 20.1, pKpa: 101.3, flow: 12.0, g: 0.0, rate: 0.34, tempK: 1320, out: 'burn', desc: 'Estiramiento de cola de pirólisis cónica con hollín moderado'),
  NasaPsiExperiment(id: 'PSI26-01', study: 'BASS-1 PMMA Sphere Baseline', mat: 0, diluent: 'N2', o2: 20.9, pKpa: 101.3, flow: 5.0, g: 0.0, rate: 0.31, tempK: 1300, out: 'burn', desc: 'Punto de estancamiento estabilizado y pluma cónica aguas abajo'),
  NasaPsiExperiment(id: 'PSI62-02', study: 'UFGM Peak Heat Feedback', mat: 0, diluent: 'N2', o2: 19.5, pKpa: 101.2, flow: 10.0, g: 0.0, rate: 0.68, tempK: 1390, out: 'burn', desc: 'Máxima transferencia térmica convectiva antes del régimen de estiramiento'),
  NasaPsiExperiment(id: 'PSI68-01', study: 'FLEX-2 n-Heptane Cool Flame NTC', mat: 2, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 0.0, g: 0.0, rate: 0.78, tempK: 665, out: 'cool', desc: 'Extinción radiativa de llama caliente -> Llama fría NTC (HCHO* 665K)'),
  NasaPsiExperiment(id: 'PSI68-02', study: 'FLEX-2 High-Pressure Soot Shell', mat: 2, diluent: 'N2', o2: 18.5, pKpa: 137.9, flow: 1.5, g: 0.0, rate: 0.89, tempK: 1620, out: 'burn', desc: 'Cáscara densa de hollín por alta presión (20 psi) cerca de la gota'),
  NasaPsiExperiment(id: 'PSI68-03', study: 'FLEX-2 CO2 Diluent Reabsorption', mat: 2, diluent: 'CO2', o2: 21.0, pKpa: 101.3, flow: 1.0, g: 0.0, rate: 0.56, tempK: 1380, out: 'burn', desc: 'Reabsorción radiativa en bandas 2.7/4.3 μm de CO2 reduce T_f y radio'),
  NasaPsiExperiment(id: 'PSI68-04', study: 'FLEX-2 Helium Diffusive Quench', mat: 2, diluent: 'He', o2: 16.0, pKpa: 101.3, flow: 1.0, g: 0.0, rate: 0.00, tempK: 580, out: 'extinct', desc: 'Alta difusividad térmica del Helio extingue prematuramente la llama'),
  NasaPsiExperiment(id: 'PSI39-01', study: 'CFI Two-Stage Autoignition NTC', mat: 2, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 0.5, g: 0.0, rate: 0.74, tempK: 640, out: 'cool', desc: 'Combustión fría controlada por difusión con pulsos de vapor'),
  NasaPsiExperiment(id: 'PSI98-01', study: 'SAFFIRE-I Large Scale SIBAL', mat: 3, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 20.0, g: 0.0, rate: 1.62, tempK: 1280, out: 'burn', desc: 'Propagación concurrente estacionaria en conducto Cygnus a 20 cm/s'),
  NasaPsiExperiment(id: 'PSI99-04', study: 'SAFFIRE-II Thin Silicone Sheet', mat: 1, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 20.0, g: 0.0, rate: 2.10, tempK: 1310, out: 'burn', desc: 'Lámina ultradelgada de silicona con estela de ceniza blanca SiO2'),
  NasaPsiExperiment(id: 'PSI99-06', study: 'SAFFIRE-II Thick Silicone Quench', mat: 1, diluent: 'N2', o2: 18.0, pKpa: 100.8, flow: 20.0, g: 0.0, rate: 0.00, tempK: 740, out: 'extinct', desc: 'Costra aislante de sílice SiO2 bloquea transferencia térmica y apaga'),
  NasaPsiExperiment(id: 'PSI100-01', study: 'SAFFIRE-III High Flow 30 cm/s', mat: 3, diluent: 'N2', o2: 20.9, pKpa: 101.3, flow: 30.0, g: 0.0, rate: 2.25, tempK: 1350, out: 'burn', desc: 'Crecimiento lineal de longitud de pirólisis en flujo forzado alto'),
  NasaPsiExperiment(id: 'PSI10-01', study: 'ACME Flame Design High-O2', mat: 4, diluent: 'N2', o2: 30.0, pKpa: 101.3, flow: 4.5, g: 0.166, rate: 1.95, tempK: 1890, out: 'burn', desc: 'Llama inversa/normal en atmósfera enriquecida con diseño estequiométrico'),
  NasaPsiExperiment(id: 'PSI20-01', study: 'ACME BRE Stanford Stagnation', mat: 4, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 2.2, g: 0.0, rate: 0.85, tempK: 1290, out: 'burn', desc: 'Quemador poroso esférico con reciclaje de entalpía radiativa'),
  NasaPsiExperiment(id: 'PSI21-01', study: 'ACME CLD Lifted Triple-Flame', mat: 4, diluent: 'N2', o2: 19.0, pKpa: 101.3, flow: 25.5, g: 0.0, rate: 1.15, tempK: 1480, out: 'lifted', desc: 'Base tri-braquial desprendida (Liftoff H_L > 6mm) cerca de blowoff'),
  NasaPsiExperiment(id: 'PSI22-02', study: 'ACME E-FIELD Ion-Driven Wind', mat: 4, diluent: 'N2', o2: 20.5, pKpa: 101.2, flow: 8.5, g: 0.166, rate: 1.75, tempK: 1810, out: 'burn', desc: 'Viento iónico electrohidrodinámico emula convección lunar y reduce hollín'),
  NasaPsiExperiment(id: 'PSI106-01', study: 'SLICE Coflow Lifted Jet Cone', mat: 4, diluent: 'N2', o2: 21.0, pKpa: 101.3, flow: 22.0, g: 0.0, rate: 1.42, tempK: 1640, out: 'lifted', desc: 'Estructura cónica levantada con borde de ataque azul CH* intenso'),
  NasaPsiExperiment(id: 'PSI107-02', study: 'SPICE Soot Tip-Opening Wings', mat: 4, diluent: 'N2', o2: 26.5, pKpa: 101.3, flow: 6.5, g: 0.0, rate: 1.68, tempK: 1740, out: 'sootopen', desc: 'Punta del cono abierta por enfriamiento radiativo liberando alas de hollín'),
  NasaPsiExperiment(id: 'PSI101-01', study: 'SAME Smoke Aerosol Aggregation', mat: 0, diluent: 'N2', o2: 21.5, pKpa: 101.3, flow: 4.0, g: 0.0, rate: 0.55, tempK: 1340, out: 'sootopen', desc: 'Agregación fractal de humo en microgravedad (CMD = 0.42 μm)'),
  NasaPsiExperiment(id: 'PSI108-01', study: 'Nomex HT90-40 Artemis Enriched', mat: 5, diluent: 'N2', o2: 32.0, pKpa: 70.3, flow: 6.0, g: 0.166, rate: 0.92, tempK: 1690, out: 'burn', desc: 'Propagación en tejido ignífugo Nomex bajo atmósfera lunar (32% O2, 10.2 psi)'),
  NasaPsiExperiment(id: 'SOFIE-01', study: 'SoFIE-GEL PMMA Sphere 8.2 psia', mat: 0, diluent: 'N2', o2: 34.0, pKpa: 56.5, flow: 5.0, g: 0.0, rate: 1.48, tempK: 1120, out: 'burn', desc: 'Atmósfera SEA 8.2 psia / 34% O2 en SoFIE-CIR (ISS)'),
  NasaPsiExperiment(id: 'SOFIE-02', study: 'SoFIE-MIST Radiant 37% O2 Band', mat: 0, diluent: 'N2', o2: 37.0, pKpa: 56.5, flow: 8.0, g: 0.0, rate: 1.75, tempK: 1290, out: 'burn', desc: 'Banda máxima de exploración 37% O2 a baja presión 56.5 kPa'),
  NasaPsiExperiment(id: 'SOFIE-04', study: 'SoFIE-RTDFS Radiative Quench', mat: 0, diluent: 'N2', o2: 15.4, pKpa: 56.5, flow: 0.4, g: 0.0, rate: 0.00, tempK: 380, out: 'extinct', desc: 'Extinción radiativa segura en atmósfera SEA hipóxica'),
  NasaPsiExperiment(id: 'MARS-SEA', study: 'Mars Surface 8.2 psia 34% O2', mat: 0, diluent: 'N2', o2: 34.0, pKpa: 56.5, flow: 10.5, g: 0.38, rate: 1.85, tempK: 1590, out: 'burn', desc: 'Hábitat Marciano 0.38g en atmósfera de exploración 34% O2'),
  NasaPsiExperiment(id: 'MARS-CO2', study: 'Mars In-Situ CO2 Buffer Quench', mat: 3, diluent: 'CO2', o2: 16.2, pKpa: 56.5, flow: 0.6, g: 0.38, rate: 0.00, tempK: 690, out: 'extinct', desc: 'Inundación con CO2 marciano en 0.38g extingue por pérdida radiativa'),
  NasaPsiExperiment(id: 'MARS-ISRU', study: 'Mars MOXIE ISRU 45% O2 Hazard', mat: 4, diluent: 'CO2', o2: 45.0, pKpa: 120.0, flow: 6.0, g: 0.38, rate: 2.85, tempK: 1750, out: 'burn', desc: 'Línea O2 de alta pureza (45%) en presencia de CO2 ISRU'),
  NasaPsiExperiment(id: 'SAFFIRE-5', study: 'SAFFIRE-V Grooved PMMA 34% O2', mat: 0, diluent: 'N2', o2: 34.0, pKpa: 56.5, flow: 12.0, g: 0.0, rate: 1.95, tempK: 1580, out: 'burn', desc: 'Propagación acelerada a gran escala en 8.2 psia / 34% O2'),
  NasaPsiExperiment(id: 'NESC-LI', study: 'Li-Ion 18650 Thermal Runaway', mat: 4, diluent: 'N2', o2: 34.0, pKpa: 56.5, flow: 6.5, g: 0.166, rate: 2.15, tempK: 1340, out: 'burn', desc: 'Fuga térmica de celda Li-Ion con eyección de HF/POF3'),
];

class Flame3DTelemetry {
  final double prob;
  final bool isCool;
  final bool isPulsating;
  final bool isTipOpen;
  final double tempK;
  final double radLossFraction;
  final double soot;
  final double sootPpm;
  final double smokeCmdUm;
  final double spread;
  final double aspectLD;
  final double liftoffMm;
  final double effVel;
  final double uBuoy;
  final double mocActual;
  final double bNumber;
  final double lewisNumber;
  final double damkohler;
  final int reynolds;
  final double nozzleExpansionRatio;
  final NasaPsiExperiment bestExp;
  final String regime;

  const Flame3DTelemetry({
    required this.prob,
    required this.isCool,
    required this.isPulsating,
    required this.isTipOpen,
    required this.tempK,
    required this.radLossFraction,
    required this.soot,
    required this.sootPpm,
    required this.smokeCmdUm,
    required this.spread,
    required this.aspectLD,
    required this.liftoffMm,
    required this.effVel,
    required this.uBuoy,
    required this.mocActual,
    required this.bNumber,
    required this.lewisNumber,
    required this.damkohler,
    required this.reynolds,
    required this.nozzleExpansionRatio,
    required this.bestExp,
    required this.regime,
  });
}

class FirestormPhysicsEngine {
  // Modelo Polinomial Cuadrático (Curva-U en microgravedad, model.json v2.2, ROC-AUC = 0.9947)
  static const List<double> polyMean = [20.30893371, 99.16023153, 7.47752162, 476.24783822, 2000.68189145, 151.93789586, 10419.66405687, 723.94724217, 141.64083571];
  static const List<double> polyStd  = [7.98718034,  24.22627942, 9.25891496, 782.96771931,  981.21111424, 175.85272843,  7040.62138853, 902.81745398, 301.98203107];
  static const List<double> polyCoef = [3.99038434,  0.50505549,  2.09220338,   1.23499072,    3.43201947,   3.41061616,     0.35504466,   2.20769477, -10.21895599];
  static const double polyIntercept  = 1.30763960;

  static const Map<int, ({String name, double moc0g, double bNumRef, double baseRate, double sootYield, double lewisBase, double cmdBase, bool canCool})> fuelProps = {
    0: (name: 'PMMA Acrylic (BASS / SoFIE)', moc0g: 15.5, bNumRef: 1.32, baseRate: 0.42, sootYield: 1.05, lewisBase: 1.08, cmdBase: 0.36, canCool: false),
    1: (name: 'Silicone SiO₂ (PSI-99)', moc0g: 17.8, bNumRef: 0.94, baseRate: 0.86, sootYield: 0.82, lewisBase: 1.15, cmdBase: 0.58, canCool: false),
    2: (name: 'n-Heptane Droplet NTC (FLEX-2)', moc0g: 13.8, bNumRef: 3.45, baseRate: 0.84, sootYield: 0.92, lewisBase: 1.28, cmdBase: 0.28, canCool: true),
    3: (name: 'SIBAL Fabric (SAFFIRE)', moc0g: 15.6, bNumRef: 1.65, baseRate: 1.58, sootYield: 0.58, lewisBase: 0.98, cmdBase: 0.24, canCool: false),
    4: (name: 'C₂H₄/CH₄ Jet (SPICE/SLICE)', moc0g: 14.4, bNumRef: 2.35, baseRate: 1.32, sootYield: 1.28, lewisBase: 0.96, cmdBase: 0.45, canCool: false),
    5: (name: 'Nomex HT90-40 (PSI-108)', moc0g: 24.5, bNumRef: 0.68, baseRate: 0.52, sootYield: 0.74, lewisBase: 1.12, cmdBase: 0.40, canCool: false),
  };

  static const Map<String, ({String name, double cpFactor, double alphaFactor, double mocShift, double radReabsorb, double leFactor, double tempDelta})> diluentProps = {
    'N2':  (name: 'N₂',  cpFactor: 1.00, alphaFactor: 1.00, mocShift:  0.0, radReabsorb: 0.00, leFactor: 1.00, tempDelta:    0),
    'CO2': (name: 'CO₂', cpFactor: 1.28, alphaFactor: 0.78, mocShift:  1.8, radReabsorb: 0.22, leFactor: 0.86, tempDelta: -145),
    'He':  (name: 'He',  cpFactor: 0.72, alphaFactor: 2.65, mocShift:  1.2, radReabsorb: 0.00, leFactor: 1.48, tempDelta:  -95),
    'Ar':  (name: 'Ar',  cpFactor: 0.71, alphaFactor: 1.08, mocShift: -1.1, radReabsorb: 0.00, leFactor: 1.32, tempDelta:  115),
  };

  static double _smoothstep(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static Flame3DTelemetry evaluateFull({
    required double o2Pct,
    required double pressurePsi,
    required double flowCmS,
    required double gravityG,
    required int fuelIdx,
    required String diluentKey,
    required bool forceCoolFlame,
  }) {
    final pressKpa = pressurePsi * 6.89476;
    final fProp = fuelProps[fuelIdx] ?? fuelProps[0]!;
    final dProp = diluentProps[diluentKey] ?? diluentProps['N2']!;

    final absGrav = gravityG.abs();
    final uBuoyMag = 26.2 * math.sqrt(absGrav) * math.pow(pressKpa / 101.3, 0.35);
    final uBuoy = (gravityG >= 0 ? 1.0 : -1.0) * uBuoyMag;
    final effVel = math.sqrt(flowCmS * flowCmS + uBuoyMag * uBuoyMag);

    final mocActual = fProp.moc0g + dProp.mocShift - 0.85 * math.sqrt(absGrav) + (101.3 - pressKpa) * 0.016;
    final bNumber = (fProp.bNumRef / dProp.cpFactor) * (o2Pct / 20.9) * math.pow(pressKpa / 101.3, 0.2);
    final lewisNumber = fProp.lewisBase * dProp.leFactor * (1.0 + math.max(0.0, 2.0 - effVel) * 0.06);

    final tauFlow = 14.5 / math.max(0.7, effVel * dProp.alphaFactor);
    final tauChem = 1.12 * dProp.cpFactor * math.pow(20.9 / math.max(10.0, o2Pct), 2.1) * math.pow(101.3 / pressKpa, 0.75);
    final damkohler = tauFlow / tauChem;

    final strainRatio = flowCmS / math.max(12.0, 22.0 + (o2Pct - 18.0) * 1.15);
    final liftoffMm = math.max(0.0, (strainRatio - 0.52) * 26.0 + math.max(0.0, (18.5 - o2Pct) * 0.85));

    final polyFeatures = [
      o2Pct, pressKpa, flowCmS,
      o2Pct * o2Pct, o2Pct * pressKpa, o2Pct * flowCmS,
      pressKpa * pressKpa, pressKpa * flowCmS, flowCmS * flowCmS,
    ];
    double logit = polyIntercept;
    for (int i = 0; i < 9; i++) {
      logit += ((polyFeatures[i] - polyMean[i]) / polyStd[i]) * polyCoef[i];
    }
    double prob = 1.0 / (1.0 + math.exp(-logit));

    if (effVel < 0.85 * dProp.alphaFactor && o2Pct < 19.8) {
      final radQuench = math.max(0.03, (effVel / (0.85 * dProp.alphaFactor)) * math.max(0.0, (o2Pct - (mocActual - 0.4)) / 3.6));
      prob *= math.min(1.0, radQuench);
    }
    if (o2Pct < mocActual + 0.5) {
      prob *= math.max(0.0, (o2Pct - (mocActual - 1.2)) / 1.7) * 0.36;
    }
    final blowoffLimit = (30.5 + (o2Pct - 18.0) * 1.20) / math.sqrt(dProp.alphaFactor);
    if (flowCmS > blowoffLimit - 5.0) {
      final blowFactor = math.max(0.0, 1.0 - (flowCmS - (blowoffLimit - 5.0)) / 7.8);
      prob *= blowFactor;
    }

    final isCool = forceCoolFlame || (fProp.canCool && prob < 0.48 && o2Pct >= 13.5 && flowCmS < 10.0);
    final radLossFraction = math.min(0.68, math.max(0.12, 0.38 / math.pow(math.max(0.4, effVel), 0.28) + dProp.radReabsorb));

    double tempK;
    if (isCool) {
      tempK = (575.0 + (o2Pct - 13.5) * 9.8 + math.min(flowCmS, 6.0) * 7.0).roundToDouble();
    } else if (prob < 0.20) {
      tempK = (510.0 + o2Pct * 8.5).roundToDouble();
    } else {
      final radLossPenalty = effVel < 2.8 ? (2.8 - effVel) * 68.0 * dProp.alphaFactor : 0.0;
      final strainPenalty  = flowCmS > 15.0 ? (flowCmS - 15.0) * 8.8 : 0.0;
      final o2Enrichment   = (o2Pct - 15.5) * 44.0;
      final pressEffect    = (pressKpa - 101.3) * 1.40;
      tempK = (1025.0 + o2Enrichment + pressEffect + dProp.tempDelta - radLossPenalty - strainPenalty).clamp(940.0, 1960.0).roundToDouble();
    }

    double soot = 0.0;
    if (!isCool && prob >= 0.20) {
      final residenceFactor = _smoothstep(0.35, 3.2, effVel) * math.max(0.15, 1.0 - math.max(0.0, flowCmS - 18.0) / 24.0);
      final o2Factor = math.max(0.0, (o2Pct - 16.5) / 12.0);
      final pressFactor = math.pow(pressKpa / 101.3, 1.30).toDouble();
      final co2Suppress = diluentKey == 'CO2' ? 0.68 : 1.0;
      soot = math.min(1.0, o2Factor * residenceFactor * pressFactor * fProp.sootYield * co2Suppress * 1.32);
    }
    final sootPpm = soot * 3.40;
    final isTipOpen = !isCool && prob >= 0.25 && sootPpm > 1.35;
    final smokeCmdUm = prob >= 0.20 ? (fProp.cmdBase * (0.75 + 0.65 * soot) * math.pow(pressKpa / 101.3, 0.4)).toDouble() : 0.0;

    final isPulsating = !isCool && prob >= 0.14 && ((prob < 0.42 && lewisNumber > 1.05) || (diluentKey == 'Ar' && effVel < 3.5));

    double spread = 0.0;
    if (prob >= 0.20 || isCool) {
      final flowPower = math.pow(math.max(0.4, math.min(effVel, 30.0)) / 5.0, 0.34).toDouble();
      spread = fProp.baseRate * math.log(1.0 + math.max(0.05, bNumber)) * flowPower * (0.32 + 0.68 * prob);
      if (isCool) spread *= 0.42;
    }

    final kinematicViscCm2S = 0.15 * (101.3 / pressKpa) * dProp.alphaFactor;
    final reynolds = ((effVel * 2.5) / kinematicViscCm2S).round();
    final nozzleExpansionRatio = (101.3 / pressKpa) * (1.0 + (flowCmS / 25.0) * 0.65 + (o2Pct / 30.0) * 0.35);
    final aspectLD = 1.02 + math.pow(effVel / 8.5, 0.72) * 1.15 + (nozzleExpansionRatio - 1.0) * 0.28;

    var bestExp = nasaPsiExperiments[0];
    double bestDist = 1e9;
    for (final exp in nasaPsiExperiments) {
      final dMat  = (exp.mat == fuelIdx) ? 0.0 : 1.6;
      final dDil  = (exp.diluent == diluentKey) ? 0.0 : 1.4;
      final dO2   = (exp.o2 - o2Pct).abs() / 4.5;
      final dFlow = (exp.flow - flowCmS).abs() / 7.5;
      final dGrav = (exp.g - gravityG).abs() * 3.0;
      final dCool = (isCool && exp.out == 'cool') ? -2.2 : 0.0;
      final dist  = dMat + dDil + dO2 + dFlow + dGrav + dCool;
      if (dist < bestDist) {
        bestDist = dist;
        bestExp = exp;
      }
    }

    String regime = 'CONCURRENT_BOUNDARY_LAYER_CONE (BASS / SAFFIRE)';
    if (isCool) {
      regime = 'SUSTAINED_NTC_COOL_FLAME (FLEX-2 / CFI HCHO* 665K)';
    } else if (prob < 0.20 && flowCmS > 25) {
      regime = 'AERODYNAMIC_BLOWOFF_EXTINCTION (Da < 1.0 / SLICE)';
    } else if (prob < 0.20) {
      regime = 'RADIATIVE_HYPOXIC_QUENCH_EXTINCTION (PSI-25 / MOC)';
    } else if (isPulsating) {
      regime = 'DIFFUSIVE_THERMAL_PULSATING_INSTABILITY (Le > 1 / PSI-23)';
    } else if (absGrav < 0.03 && flowCmS < 1.3) {
      regime = 'MICROGRAVITY_SPHERICAL_BLUE_DIFFUSION (0g s-FLAME)';
    } else if (liftoffMm > 3.5) {
      regime = 'LIFTED_TRIPLE_FLAME_BASE (ACME CLD / SLICE)';
    } else if (isTipOpen) {
      regime = 'RADIATIVE_TIP_OPENING_SOOT_WINGS (SPICE / SAME)';
    } else if (o2Pct >= 26.0) {
      regime = 'EXPLORATION_ATMOSPHERE_ACCELERATED_CONE (ARTEMIS)';
    }

    return Flame3DTelemetry(
      prob: prob,
      isCool: isCool,
      isPulsating: isPulsating,
      isTipOpen: isTipOpen,
      tempK: tempK,
      radLossFraction: radLossFraction,
      soot: soot,
      sootPpm: sootPpm,
      smokeCmdUm: smokeCmdUm,
      spread: spread,
      aspectLD: aspectLD,
      liftoffMm: liftoffMm,
      effVel: effVel,
      uBuoy: uBuoy,
      mocActual: mocActual,
      bNumber: bNumber,
      lewisNumber: lewisNumber,
      damkohler: damkohler,
      reynolds: reynolds,
      nozzleExpansionRatio: nozzleExpansionRatio,
      bestExp: bestExp,
      regime: regime,
    );
  }
}
