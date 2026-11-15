import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/flame_3d_physics.dart';

/// Interactive Multi-Regime 3D Combustion & NASA PSI Atlas Panel.
/// Includes 36 NASA PSI presets, 4 reactive KPIs, 4 atmosphere/gravity sliders,
/// 3 categorized dropdowns, 3D De Laval Thruster & Multi-Regime Flame Canvas,
/// Dual Telemetry HUD, 4 camera presets, and 2 live `fl_chart` plots.
class HabitatFlame3DCard extends StatefulWidget {
  final double o2Percent;
  final double pressurePsi;
  final double forcedFlowCmS;
  final double gravityG;
  final String materialName;
  final String diluentGas;
  final void Function({
    double? o2Percent,
    double? pressurePsi,
    double? forcedFlowCmS,
    double? gravityG,
    String? materialName,
  })? onSyncConditions;

  const HabitatFlame3DCard({
    super.key,
    required this.o2Percent,
    required this.pressurePsi,
    required this.forcedFlowCmS,
    required this.gravityG,
    this.materialName = 'PMMA',
    this.diluentGas = 'N2',
    this.onSyncConditions,
  });

  @override
  State<HabitatFlame3DCard> createState() => _HabitatFlame3DCardState();
}

class _HabitatFlame3DCardState extends State<HabitatFlame3DCard>
    with SingleTickerProviderStateMixin {
  static const _bgCard = Color(0xFF141820);
  static const _bgPanel = Color(0xFF11151E);
  static const _bgInner = Color(0xFF0A0D14);
  static const _border = Color(0xFF232834);
  static const _accentRed = Color(0xFFE53935);
  static const _accentCyan = Color(0xFF38BDF8);
  static const _accentAmber = Color(0xFFF59E0B);
  static const _accentGreen = Color(0xFF10B981);
  static const _accentPurple = Color(0xFFA855F7);

  Ticker? _ticker;
  double _time = 0.0;

  // Interactive simulation state (synced with parent props on change)
  late double _o2Pct;
  late double _pressPsi;
  late double _flowCmS;
  late double _gravG;
  late int _fuelIdx;
  late String _diluentKey;
  String _selectedPreset = 'CUSTOM';
  int? _selectedExpIndex;
  bool _forceCoolFlame = false;

  // 3D camera controls
  double _yaw = 0.16;
  double _pitch = 0.12;
  double _zoom = 1.0;
  bool _autoOrbit = true;
  int _camMode = 3; // 0: Cool NTC, 1: 0g Top, 2: Nozzle Profile, 3: 3D Orbit

  @override
  void initState() {
    super.initState();
    _syncFromWidget(initial: true);
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _ticker = createTicker((elapsed) {
        if (!mounted) return;
        setState(() {
          _time = elapsed.inMilliseconds / 1000.0;
          if (_autoOrbit) {
            _yaw = 0.16 + 0.22 * math.sin(_time * 0.55);
          }
        });
      });
      _ticker?.start();
    }
  }

  void _syncFromWidget({bool initial = false}) {
    _o2Pct = widget.o2Percent.clamp(12.5, 45.0);
    _pressPsi = widget.pressurePsi.clamp(4.3, 44.1);
    _flowCmS = widget.forcedFlowCmS.clamp(0.0, 45.0);
    _gravG = widget.gravityG.clamp(-2.0, 2.0);
    _fuelIdx = _mapMaterialToFuelIdx(widget.materialName);
    _diluentKey = FirestormPhysicsEngine.diluentProps.containsKey(widget.diluentGas)
        ? widget.diluentGas
        : 'N2';
    if (initial) {
      _selectedPreset = _detectPreset(_o2Pct, _pressPsi, _flowCmS, _gravG);
    }
  }

  int _mapMaterialToFuelIdx(String matName) {
    final lower = matName.toLowerCase();
    if (lower.contains('silicone')) return 1;
    if (lower.contains('heptane')) return 2;
    if (lower.contains('cotton') || lower.contains('sibal')) return 3;
    if (lower.contains('ethylene') || lower.contains('methane') || lower.contains('c2h4')) return 4;
    if (lower.contains('nomex') || lower.contains('aramid')) return 5;
    return 0;
  }

  String _mapFuelIdxToAppMaterial(int idx) {
    switch (idx) {
      case 1:
        return 'silicone';
      case 3:
        return 'cotton-fiberglass fabric';
      case 5:
        return 'aramid fabric';
      default:
        return 'PMMA';
    }
  }

  String _detectPreset(double o2, double psi, double flow, double g) {
    if ((g - 0.0).abs() < 0.01 && (o2 - 21.0).abs() < 0.5) return 'ISS';
    if ((g - 0.166).abs() < 0.02 && (o2 - 34.0).abs() < 0.5) return 'LUNAR';
    if ((g - 0.38).abs() < 0.03) return 'MARS';
    if ((g - 1.0).abs() < 0.05) return 'EARTH';
    return 'CUSTOM';
  }

  @override
  void didUpdateWidget(covariant HabitatFlame3DCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.o2Percent != widget.o2Percent ||
        oldWidget.pressurePsi != widget.pressurePsi ||
        oldWidget.forcedFlowCmS != widget.forcedFlowCmS ||
        oldWidget.gravityG != widget.gravityG ||
        oldWidget.materialName != widget.materialName ||
        oldWidget.diluentGas != widget.diluentGas) {
      setState(() {
        _syncFromWidget();
        _selectedPreset = _detectPreset(_o2Pct, _pressPsi, _flowCmS, _gravG);
        _selectedExpIndex = null;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _notifyParent() {
    widget.onSyncConditions?.call(
      o2Percent: _o2Pct,
      pressurePsi: _pressPsi,
      forcedFlowCmS: _flowCmS,
      gravityG: _gravG,
      materialName: _mapFuelIdxToAppMaterial(_fuelIdx),
    );
  }

  void _applyHabitatPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      _selectedExpIndex = null;
      _forceCoolFlame = false;
      switch (preset) {
        case 'ISS':
          _o2Pct = 21.0;
          _pressPsi = 14.7;
          _flowCmS = 10.0;
          _gravG = 0.0;
          _diluentKey = 'N2';
          break;
        case 'LUNAR':
          _o2Pct = 34.0;
          _pressPsi = 8.2;
          _flowCmS = 18.0;
          _gravG = 0.166;
          _diluentKey = 'N2';
          break;
        case 'MARS':
          _o2Pct = 34.0;
          _pressPsi = 8.2;
          _flowCmS = 12.0;
          _gravG = 0.38;
          _diluentKey = 'N2';
          break;
        case 'EARTH':
          _o2Pct = 21.0;
          _pressPsi = 14.7;
          _flowCmS = 5.0;
          _gravG = 1.0;
          _diluentKey = 'N2';
          break;
        case 'VAC_HYPOXIC':
          _o2Pct = 15.2;
          _pressPsi = 6.0;
          _flowCmS = 1.5;
          _gravG = 0.0;
          _diluentKey = 'N2';
          break;
        case 'HYPER_O2':
          _o2Pct = 42.0;
          _pressPsi = 30.0;
          _flowCmS = 22.0;
          _gravG = 1.0;
          _diluentKey = 'N2';
          break;
        case 'INVERTED_G':
          _o2Pct = 24.0;
          _pressPsi = 14.7;
          _flowCmS = 8.0;
          _gravG = -1.0;
          _diluentKey = 'N2';
          break;
        case 'CENTRIFUGE_2G':
          _o2Pct = 26.0;
          _pressPsi = 18.0;
          _flowCmS = 14.0;
          _gravG = 2.0;
          _diluentKey = 'N2';
          break;
      }
    });
    _notifyParent();
  }

  void _applyNasaExperiment(int idx) {
    final exp = nasaPsiExperiments[idx];
    setState(() {
      _selectedExpIndex = idx;
      _selectedPreset = 'CUSTOM';
      _o2Pct = exp.o2.clamp(12.5, 45.0);
      _pressPsi = (exp.pKpa / 6.89476).clamp(4.3, 44.1);
      _flowCmS = exp.flow.clamp(0.0, 45.0);
      _gravG = exp.g.clamp(-2.0, 2.0);
      _fuelIdx = exp.mat;
      _diluentKey = exp.diluent;
      _forceCoolFlame = exp.out == 'cool';
      if (_forceCoolFlame) {
        _camMode = 0;
        _autoOrbit = false;
        _yaw = 0.0;
        _pitch = 0.12;
      }
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final tel = FirestormPhysicsEngine.evaluateFull(
      o2Pct: _o2Pct,
      pressurePsi: _pressPsi,
      flowCmS: _flowCmS,
      gravityG: _gravG,
      fuelIdx: _fuelIdx,
      diluentKey: _diluentKey,
      forceCoolFlame: _forceCoolFlame,
    );

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'STEP 02 · MULTI-REGIME COMBUSTION PHYSICS & 3D THRUSTER / PLUME CONE',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _buildExperimentBar(tel),
          const SizedBox(height: 12),
          _buildKpiGrid(tel),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final controlsPanel = _buildControlsPanel(tel);
              final viewportPanel = _buildViewportCard(tel);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 345, child: controlsPanel),
                    const SizedBox(width: 14),
                    Expanded(child: viewportPanel),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  viewportPanel,
                  const SizedBox(height: 12),
                  controlsPanel,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final chart1 = _buildPBurnChart(tel);
              final chart2 = _buildSpreadChart(tel);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart1),
                    const SizedBox(width: 14),
                    Expanded(child: chart2),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chart1,
                  const SizedBox(height: 12),
                  chart2,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentBar(Flame3DTelemetry tel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final dropdown = _buildStyledDropdown<int?>(
            value: _selectedExpIndex,
            hint: 'Seleccionar experimento NASA PSI (36 disponibles)...',
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'Modo libre — ajustado por controles / hábitat',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (int i = 0; i < nasaPsiExperiments.length; i++)
                DropdownMenuItem<int?>(
                  value: i,
                  child: Text(
                    '${nasaPsiExperiments[i].id} · ${nasaPsiExperiments[i].study} (${nasaPsiExperiments[i].o2.toStringAsFixed(1)}% O2, ${nasaPsiExperiments[i].g}g)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (val) {
              if (val != null) _applyNasaExperiment(val);
            },
          );

          final badge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _accentCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _accentCyan.withValues(alpha: 0.35)),
            ),
            child: Text(
              'NEAREST: ${tel.bestExp.id} (${tel.bestExp.out.toUpperCase()})',
              style: const TextStyle(
                color: _accentCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LOAD NASA PSI EXPERIMENT (36 PRESETS)',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                dropdown,
                const SizedBox(height: 8),
                badge,
              ],
            );
          }

          return Row(
            children: [
              const Text(
                'NASA PSI:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: dropdown),
              const SizedBox(width: 10),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(Flame3DTelemetry tel) {
    final probPct = (tel.prob * 100).round();
    final probColor = tel.isCool
        ? _accentPurple
        : (probPct >= 65
            ? _accentRed
            : (probPct >= 35 ? _accentAmber : _accentGreen));
    final margin = _o2Pct - tel.mocActual;

    final cards = [
      _kpiCard(
        title: 'P(BURN) · ONNX + QUENCH',
        value: tel.prob.toStringAsFixed(2),
        subtitle:
            'T_f ${tel.tempK.round()} K | Rad Loss χ_r = ${(tel.radLossFraction * 100).round()}%',
        accent: probColor,
      ),
      _kpiCard(
        title: 'SPREAD / REGRESSION RATE',
        value: '≈ ${tel.spread.toStringAsFixed(2)} mm/s',
        subtitle:
            'Da = ${tel.damkohler.toStringAsFixed(2)} | Liftoff H_L = ${tel.liftoffMm.toStringAsFixed(1)} mm',
        accent: _accentAmber,
      ),
      _kpiCard(
        title: 'FLAMMABILITY LIMIT (MOC)',
        value: '${tel.mocActual.toStringAsFixed(1)} % O₂',
        subtitle:
            'Margin ${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}% | B=${tel.bNumber.toStringAsFixed(2)} | Le=${tel.lewisNumber.toStringAsFixed(2)}',
        accent: margin >= 0 ? _accentRed : _accentGreen,
      ),
      _kpiCard(
        title: 'MIXED FLOW & SOOT AEROSOL',
        value: '≈ ${tel.effVel.toStringAsFixed(1)} cm/s',
        subtitle:
            'f_v = ${tel.sootPpm.toStringAsFixed(2)} ppm | SAME CMD = ${tel.smokeCmdUm.toStringAsFixed(2)} μm',
        accent: _accentCyan,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 10.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildControlsPanel(Flame3DTelemetry tel) {
    final gravLabel = _gravG.abs() < 0.01
        ? '0.00g (0g)'
        : (_gravG - 0.166).abs() < 0.02
            ? '${_gravG.toStringAsFixed(2)}g (Lunar)'
            : (_gravG - 0.38).abs() < 0.02
                ? '${_gravG.toStringAsFixed(2)}g (Mars)'
                : '${_gravG >= 0 ? '+' : ''}${_gravG.toStringAsFixed(2)}g';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'SLIDERS · ATMOSPHERE, FLOW & GRAVITY',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'REAL-TIME CFD SURROGATE',
                style: TextStyle(
                  color: _accentCyan.withValues(alpha: 0.85),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSliderRow(
            label: 'OXYGEN CONCENTRATION (Y_O2)',
            valueText: '${_o2Pct.toStringAsFixed(1)} %',
            value: _o2Pct,
            min: 12.5,
            max: 45.0,
            activeColor: _accentRed,
            onChanged: (v) {
              setState(() {
                _o2Pct = v;
                _selectedPreset = 'CUSTOM';
                _selectedExpIndex = null;
              });
              _notifyParent();
            },
          ),
          _buildSliderRow(
            label: 'AMBIENT PRESSURE (P_amb)',
            valueText:
                '${_pressPsi.toStringAsFixed(1)} psi (${(_pressPsi * 6.89476).toStringAsFixed(1)} kPa)',
            value: _pressPsi,
            min: 4.3,
            max: 44.1,
            activeColor: _accentRed,
            onChanged: (v) {
              setState(() {
                _pressPsi = v;
                _selectedPreset = 'CUSTOM';
                _selectedExpIndex = null;
              });
              _notifyParent();
            },
          ),
          _buildSliderRow(
            label: 'FORCED FLOW / JET VELOCITY (U_f)',
            valueText: '${_flowCmS.toStringAsFixed(1)} cm/s',
            value: _flowCmS,
            min: 0.0,
            max: 45.0,
            activeColor: _accentRed,
            onChanged: (v) {
              setState(() {
                _flowCmS = v;
                _selectedPreset = 'CUSTOM';
                _selectedExpIndex = null;
              });
              _notifyParent();
            },
          ),
          _buildSliderRow(
            label: 'GRAVITY ACCELERATION (g / g_0) [-2g .. +2g]',
            valueText: gravLabel,
            value: _gravG,
            min: -2.0,
            max: 2.0,
            activeColor: _gravG < 0 ? _accentPurple : _accentRed,
            onChanged: (v) {
              setState(() {
                _gravG = v;
                _selectedPreset = 'CUSTOM';
                _selectedExpIndex = null;
              });
              _notifyParent();
            },
          ),
          const Divider(color: _border, height: 18),
          const Text(
            'EXPERIMENT CATEGORIES (DROPDOWN SELECTORS)',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _dropdownLabel('1. AMBIENT / GRAVITY PRESET'),
          const SizedBox(height: 5),
          _buildStyledDropdown<String>(
            value: _selectedPreset,
            items: const [
              DropdownMenuItem(value: 'CUSTOM', child: Text('Custom (Manual Slider Values)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'ISS', child: Text('ISS Destiny (0.0g · 21% O2 · 14.7 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'LUNAR', child: Text('Lunar Artemis SEA (0.166g · 34% O2 · 8.2 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'MARS', child: Text('Mars Ambient (0.38g · 34% O2 · 8.2 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'EARTH', child: Text('Earth Sea Level (1.0g · 21% O2 · 14.7 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'VAC_HYPOXIC', child: Text('Hypoxic Extinguish (0.0g · 15.2% O2 · 6 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'HYPER_O2', child: Text('Hyperbaric Enriched (1.0g · 42% O2 · 30 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'INVERTED_G', child: Text('Inverted Gravity (-1.0g · Downward Buoyancy)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'CENTRIFUGE_2G', child: Text('Hypergravity Centrifuge (+2.0g · 26% O2)', overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
            onChanged: (v) {
              if (v != null && v != 'CUSTOM') _applyHabitatPreset(v);
            },
          ),
          const SizedBox(height: 10),
          _dropdownLabel('2. DILUENT GAS (PSI-68 / PSI-23)'),
          const SizedBox(height: 5),
          _buildStyledDropdown<String>(
            value: _diluentKey,
            items: const [
              DropdownMenuItem(value: 'N2', child: Text('N₂ — Standard Nitrogen Air', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'CO2', child: Text('CO₂ — Carbon Dioxide (Radiative Reabsorption)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'He', child: Text('He — Helium (High Thermal Diffusivity)', overflow: TextOverflow.ellipsis, maxLines: 1)),
              DropdownMenuItem(value: 'Ar', child: Text('Ar — Argon (Low Cp · High Temp)', overflow: TextOverflow.ellipsis, maxLines: 1)),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _diluentKey = v;
                  _selectedExpIndex = null;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          _dropdownLabel('3. FUEL SPECIMEN & BURNER FAMILY (NASA PSI)'),
          const SizedBox(height: 5),
          _buildStyledDropdown<int>(
            value: _fuelIdx,
            items: [
              for (final entry in FirestormPhysicsEngine.fuelProps.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value.name, overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _fuelIdx = v;
                  _selectedExpIndex = null;
                });
                _notifyParent();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                valueText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: const Color(0xFF252B3B),
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.16),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _bgInner,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: _bgPanel,
          hint: hint != null
              ? Text(
                  hint,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
          iconEnabledColor: const Color(0xFF94A3B8),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildViewportCard(Flame3DTelemetry tel) {
    final badgeColor = tel.isCool
        ? _accentPurple
        : (tel.prob < 0.35
            ? _accentGreen
            : (tel.prob < 0.65 ? _accentAmber : _accentRed));

    return Container(
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D REGENERATIVE DE LAVAL THRUSTER & MULTI-REGIME CONE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'MULTI-REGIME COMBUSTION VIEWPORT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    tel.regime,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3D Canvas + Dual HUD
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 500;
              return Container(
                height: narrow ? 280 : 330,
                decoration: BoxDecoration(
                  color: _bgInner,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          setState(() {
                            _autoOrbit = false;
                            _yaw += d.delta.dx * 0.01;
                            _pitch = (_pitch + d.delta.dy * 0.01).clamp(-1.2, 1.2);
                          });
                        },
                        child: CustomPaint(
                          painter: _MultiRegimeFlamePainter(
                            time: _time,
                            yaw: _yaw,
                            pitch: _pitch,
                            zoom: _zoom,
                            o2Pct: _o2Pct,
                            pressPsi: _pressPsi,
                            flowCmS: _flowCmS,
                            gravityG: _gravG,
                            fuelIdx: _fuelIdx,
                            diluentKey: _diluentKey,
                            tel: tel,
                          ),
                        ),
                      ),
                    ),
                    // Top-Left HUD: Multi-Regime Combustion Telemetry
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: narrow ? constraints.maxWidth - 16 : 265,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0D14).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _accentCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'T_f: ${tel.tempK.round()} K | Da: ${tel.damkohler.toStringAsFixed(2)} | Le: ${tel.lewisNumber.toStringAsFixed(2)}\n'
                          'Liftoff H_L: ${tel.liftoffMm.toStringAsFixed(1)} mm | Soot: ${tel.sootPpm.toStringAsFixed(1)} ppm\n'
                          'Rad Loss: ${(tel.radLossFraction * 100).round()}% | L/D: ${tel.aspectLD.toStringAsFixed(2)} | Re: ${tel.reynolds}',
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 9.8,
                            height: 1.35,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    // Top-Right HUD (wide only): Matched NASA PSI Experiment
                    if (!narrow)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 255),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0A0D14).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _accentAmber.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'NASA MATCH: ${tel.bestExp.id}',
                                style: const TextStyle(
                                  color: _accentAmber,
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                tel.bestExp.study,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                tel.bestExp.desc,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Active phenomena tags & 4 Camera preset buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final pills = _buildPhenomenaPills(tel);
              final cams = _buildCameraButtons();
              if (constraints.maxWidth >= 600) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(child: pills),
                    const SizedBox(width: 8),
                    cams,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pills,
                  const SizedBox(height: 8),
                  cams,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhenomenaPills(Flame3DTelemetry tel) {
    final List<(String, Color)> tags = [];
    if (tel.isCool) tags.add(('NTC COOL FLAME (HCHO*)', _accentPurple));
    if (tel.isPulsating) tags.add(('LEWIS PULSATING (Le > 1)', _accentAmber));
    if (tel.isTipOpen) tags.add(('TIP-OPENING SOOT WINGS', _accentAmber));
    if (tel.liftoffMm > 1.2) tags.add(('LIFTED TRIPLE-FLAME', _accentCyan));
    if (_gravG.abs() < 0.05) tags.add(('0g DIFFUSION SPHERE', _accentCyan));
    if (_gravG < -0.05) tags.add(('INVERTED BUOYANCY (-g)', _accentPurple));
    if (_fuelIdx == 1) tags.add(('SiO₂ ASH SHELL', Colors.white70));
    if (tags.isEmpty) {
      tags.add((
        tel.prob >= 0.45 ? 'ATTACHED CONE BURN' : 'RADIATIVE / BLOWOFF QUENCH',
        tel.prob >= 0.45 ? _accentRed : _accentGreen,
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: t.$2.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: t.$2.withValues(alpha: 0.45)),
            ),
            child: Text(
              t.$1,
              style: TextStyle(
                color: t.$2,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCameraButtons() {
    final defs = [
      (0, 'COOL FLAME NTC'),
      (1, '0g TOP'),
      (2, 'NOZZLE PROFILE'),
      (3, '3D ORBIT'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in defs)
          InkWell(
            onTap: () {
              setState(() {
                _camMode = d.$1;
                if (d.$1 == 0) {
                  _forceCoolFlame = !_forceCoolFlame;
                  _autoOrbit = false;
                  _yaw = 0.0;
                  _pitch = 0.15;
                  _zoom = 1.1;
                } else if (d.$1 == 1) {
                  _autoOrbit = false;
                  _yaw = 0.0;
                  _pitch = 1.15;
                  _zoom = 1.05;
                } else if (d.$1 == 2) {
                  _autoOrbit = false;
                  _yaw = 0.0;
                  _pitch = 0.0;
                  _zoom = 1.12;
                } else {
                  _forceCoolFlame = false;
                  _autoOrbit = true;
                  _yaw = 0.35;
                  _pitch = 0.22;
                  _zoom = 1.0;
                }
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: (_camMode == d.$1 && (d.$1 != 0 || _forceCoolFlame))
                    ? _accentRed
                    : const Color(0xFF1A202C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (_camMode == d.$1 && (d.$1 != 0 || _forceCoolFlame))
                      ? _accentRed
                      : _border,
                ),
              ),
              child: Text(
                d.$2,
                style: TextStyle(
                  color: (_camMode == d.$1 && (d.$1 != 0 || _forceCoolFlame))
                      ? Colors.white
                      : const Color(0xFFCBD5E1),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // FL_CHART 1: P(burn) U-Curve vs Forced Flow (0..45 cm/s)
  Widget _buildPBurnChart(Flame3DTelemetry tel) {
    final List<FlSpot> curveSpots = [];
    for (int f = 0; f <= 45; f += 2) {
      final t = FirestormPhysicsEngine.evaluateFull(
        o2Pct: _o2Pct,
        pressurePsi: _pressPsi,
        flowCmS: f.toDouble(),
        gravityG: _gravG,
        fuelIdx: _fuelIdx,
        diluentKey: _diluentKey,
        forceCoolFlame: false,
      );
      curveSpots.add(FlSpot(f.toDouble(), t.prob * 100.0));
    }

    final List<FlSpot> nasaBurnSpots = [];
    final List<FlSpot> nasaExtinctSpots = [];
    for (final exp in nasaPsiExperiments) {
      if ((exp.o2 - _o2Pct).abs() <= 7.5 && exp.flow <= 45.0) {
        final y = exp.out == 'extinct' ? 12.0 : 88.0;
        if (exp.out == 'extinct') {
          nasaExtinctSpots.add(FlSpot(exp.flow, y));
        } else {
          nasaBurnSpots.add(FlSpot(exp.flow, y));
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FL_CHART 1 · P(BURN) U-CURVE VS FLOW (0–45 cm/s)',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 45,
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 25,
                  verticalInterval: 10,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFF1E2433), strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      const FlLine(color: Color(0xFF1E2433), strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: _border),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 15,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 9.5),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: _flowCmS,
                      color: _accentCyan.withValues(alpha: 0.7),
                      strokeWidth: 1.5,
                      dashArray: [4, 4],
                    ),
                  ],
                  horizontalLines: [
                    HorizontalLine(
                      y: 50,
                      color: Colors.white24,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: curveSpots,
                    isCurved: true,
                    color: _accentRed,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _accentRed.withValues(alpha: 0.12),
                    ),
                  ),
                  if (nasaBurnSpots.isNotEmpty)
                    LineChartBarData(
                      spots: nasaBurnSpots,
                      barWidth: 0,
                      color: Colors.transparent,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3,
                          color: _accentAmber,
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  if (nasaExtinctSpots.isNotEmpty)
                    LineChartBarData(
                      spots: nasaExtinctSpots,
                      barWidth: 0,
                      color: Colors.transparent,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                          radius: 3,
                          color: _accentGreen,
                          strokeWidth: 0,
                        ),
                      ),
                    ),
                  LineChartBarData(
                    spots: [FlSpot(_flowCmS, tel.prob * 100.0)],
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: _accentCyan,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FL_CHART 2: Spread Rate vs O2 (12.5..45%) with MOC & NASA PSI scatter
  Widget _buildSpreadChart(Flame3DTelemetry tel) {
    final List<FlSpot> spreadSpots = [];
    double maxY = 3.5;
    for (double o2 = 13.0; o2 <= 45.0; o2 += 2.0) {
      final t = FirestormPhysicsEngine.evaluateFull(
        o2Pct: o2,
        pressurePsi: _pressPsi,
        flowCmS: _flowCmS,
        gravityG: _gravG,
        fuelIdx: _fuelIdx,
        diluentKey: _diluentKey,
        forceCoolFlame: false,
      );
      if (t.spread > maxY) maxY = t.spread + 0.5;
      spreadSpots.add(FlSpot(o2, t.spread));
    }

    final List<FlSpot> nasaScatter = [
      for (final exp in nasaPsiExperiments)
        if (exp.o2 >= 12.5 && exp.o2 <= 45.0)
          FlSpot(exp.o2, exp.rate.clamp(0.0, maxY)),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FL_CHART 2 · SPREAD RATE VS O₂% + MOC & NASA PSI',
            style: TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 12.5,
                maxX: 45,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: (maxY / 4).clamp(0.5, 5.0),
                  verticalInterval: 8,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFF1E2433), strokeWidth: 1),
                  getDrawingVerticalLine: (_) =>
                      const FlLine(color: Color(0xFF1E2433), strokeWidth: 1),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: _border),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 8,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 9.5),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 9.5),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: tel.mocActual.clamp(12.5, 45.0),
                      color: _accentRed.withValues(alpha: 0.8),
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                    ),
                    VerticalLine(
                      x: _o2Pct,
                      color: _accentCyan.withValues(alpha: 0.7),
                      strokeWidth: 1.5,
                      dashArray: [3, 3],
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spreadSpots,
                    isCurved: true,
                    color: _accentAmber,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _accentAmber.withValues(alpha: 0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: nasaScatter,
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 2.5,
                        color: Colors.white54,
                        strokeWidth: 0,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: [FlSpot(_o2Pct, tel.spread.clamp(0.0, maxY))],
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: _accentCyan,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiRegimeFlamePainter extends CustomPainter {
  final double time;
  final double yaw;
  final double pitch;
  final double zoom;
  final double o2Pct;
  final double pressPsi;
  final double flowCmS;
  final double gravityG;
  final int fuelIdx;
  final String diluentKey;
  final Flame3DTelemetry tel;

  const _MultiRegimeFlamePainter({
    required this.time,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.o2Pct,
    required this.pressPsi,
    required this.flowCmS,
    required this.gravityG,
    required this.fuelIdx,
    required this.diluentKey,
    required this.tel,
  });

  (double, double, double) _project(double x, double y, double z, Size size) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;
    final y2 = y * cp - z1 * sp;
    final z2 = y * sp + z1 * cp;

    final scale = (size.height * 0.88) * zoom / (2.7 + z2 * 0.28);
    return (size.width * 0.34 + x1 * scale, size.height * 0.52 - y2 * scale, z2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Perspective Floor Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2639).withValues(alpha: 0.75)
      ..strokeWidth = 0.9;
    for (double gx = -2.2; gx <= 3.4; gx += 0.45) {
      final p1 = _project(gx, -0.82, -1.35, size);
      final p2 = _project(gx, -0.82, 1.35, size);
      canvas.drawLine(Offset(p1.$1, p1.$2), Offset(p2.$1, p2.$2), gridPaint);
    }
    for (double gz = -1.35; gz <= 1.35; gz += 0.45) {
      final p1 = _project(-2.2, -0.82, gz, size);
      final p2 = _project(3.4, -0.82, gz, size);
      canvas.drawLine(Offset(p1.$1, p1.$2), Offset(p2.$1, p2.$2), gridPaint);
    }

    // 2. Solid De Laval Nozzle + Back-to-Front Painter's Sort
    final nozzlePoints = <List<(double, double, double)>>[];
    const segs = 18;
    const rings = 12;
    for (int i = 0; i <= rings; i++) {
      final t = i / rings;
      final x = -1.35 + t * 1.35;
      double r;
      if (t < 0.18) {
        // Injector dome taper
        final dt = t / 0.18;
        r = 0.06 + 0.21 * math.sin(dt * math.pi * 0.5);
      } else if (t < 0.42) {
        // Combustion chamber
        r = 0.27;
      } else if (t < 0.62) {
        // Convergent throat
        final dt = (t - 0.42) / 0.20;
        r = 0.27 - 0.12 * math.sin(dt * math.pi * 0.5);
      } else {
        // Divergent bell nozzle
        final dt = (t - 0.62) / 0.38;
        r = 0.15 + 0.15 * math.pow(dt, 0.82);
      }
      final ring = <(double, double, double)>[];
      for (int j = 0; j < segs; j++) {
        final ang = (j / segs) * 2 * math.pi;
        ring.add(_project(x, r * math.sin(ang), r * math.cos(ang), size));
      }
      nozzlePoints.add(ring);
    }

    final faces = <(double z, Path path, Color fill)>[];
    for (int i = 0; i < rings; i++) {
      final t = i / rings;
      for (int j = 0; j < segs; j++) {
        final nj = (j + 1) % segs;
        final a = nozzlePoints[i][j];
        final b = nozzlePoints[i + 1][j];
        final c = nozzlePoints[i + 1][nj];
        final d = nozzlePoints[i][nj];
        final avgZ = (a.$3 + b.$3 + c.$3 + d.$3) * 0.25;
        final ny = math.sin(((j + 0.5) / segs) * 2 * math.pi);
        final light = (0.45 + 0.45 * ny + 0.15 * (-avgZ)).clamp(0.12, 1.0);
        final baseColor = t < 0.42
            ? Color.lerp(const Color(0xFF1F1612), const Color(0xFF7C3AED).withValues(alpha: 0.0), 0.0)!
            : const Color(0xFF451A03);
        final hiColor = t < 0.60
            ? const Color(0xFF9A4A18)
            : const Color(0xFFD97724);
        final fill = Color.lerp(
          t < 0.42 ? const Color(0xFF231814) : baseColor,
          hiColor,
          light,
        )!;
        final path = Path()
          ..moveTo(a.$1, a.$2)
          ..lineTo(b.$1, b.$2)
          ..lineTo(c.$1, c.$2)
          ..lineTo(d.$1, d.$2)
          ..close();
        faces.add((avgZ, path, fill));
      }
    }
    faces.sort((u, v) => v.$1.compareTo(u.$1));
    final ribPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final f in faces) {
      canvas.drawPath(
        f.$2,
        Paint()
          ..color = f.$3
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(f.$2, ribPaint);
    }

    // Regenerative cooling bypass pipes (top & bottom silver manifolds)
    final pipePaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final sign in [-1.0, 1.0]) {
      final p0 = _project(-1.12, sign * 0.30, 0, size);
      final p1 = _project(-0.78, sign * 0.34, 0, size);
      final p2 = _project(-0.48, sign * 0.21, 0, size);
      final p3 = _project(-0.04, sign * 0.33, 0, size);
      final pipePath = Path()
        ..moveTo(p0.$1, p0.$2)
        ..lineTo(p1.$1, p1.$2)
        ..lineTo(p2.$1, p2.$2)
        ..lineTo(p3.$1, p3.$2);
      canvas.drawPath(pipePath, pipePaint);
    }

    // Nozzle exit inner combustion glow
    if (tel.prob >= 0.06 || tel.isCool) {
      final exitCenter = _project(-0.02, 0, 0, size);
      final exitTop = _project(-0.02, 0.28, 0, size);
      final exitR = (exitCenter.$2 - exitTop.$2).abs().clamp(14.0, 70.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(exitCenter.$1, exitCenter.$2),
          width: exitR * 0.55,
          height: exitR * 1.85,
        ),
        Paint()
          ..color = (tel.isCool ? const Color(0xFF8B5CF6) : const Color(0xFFBAE6FD))
              .withValues(alpha: 0.72)
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // 3. Multi-Regime Volumetric Flame Body
    if (tel.prob < 0.06 && !tel.isCool) {
      final smokePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      for (int k = 0; k < 5; k++) {
        final sx = 0.12 + k * 0.32 + 0.06 * math.sin(time * 2 + k);
        final p = _project(sx, 0.05 * math.sin(time + k), 0.0, size);
        canvas.drawCircle(Offset(p.$1, p.$2), 14 + k * 5.0, smokePaint);
      }
      _drawAxisGizmo(canvas, size);
      return;
    }

    final pulse = tel.isPulsating
        ? (0.76 + 0.24 * math.sin(time * 7.5))
        : (0.95 + 0.05 * math.sin(time * 12.0));
    final liftoffX = (tel.liftoffMm / 28.0).clamp(0.0, 0.38);
    final isSphere = tel.effVel < 3.5;

    final flameLen = isSphere
        ? 0.78 * pulse
        : (1.95 + (tel.aspectLD * 0.38).clamp(0.4, 2.15)) * pulse;
    final flameRad = isSphere
        ? (0.40 + 0.08 * tel.prob) * pulse
        : (0.31 + 0.08 * (o2Pct / 45.0)) * pulse;
    final buoyCurve = (gravityG / 2.0) * 0.42;

    final Color sheathColor;
    final Color coreColor;
    final Color tailColor;
    if (tel.isCool) {
      sheathColor = const Color(0xFF7C3AED).withValues(alpha: 0.72);
      coreColor = const Color(0xFF38BDF8).withValues(alpha: 0.92);
      tailColor = const Color(0xFFA855F7).withValues(alpha: 0.65);
    } else if (o2Pct >= 28.0 && tel.soot < 0.35) {
      sheathColor = const Color(0xFF0EA5E9).withValues(alpha: 0.75);
      coreColor = const Color(0xFFFFFFFF);
      tailColor = const Color(0xFF38BDF8).withValues(alpha: 0.85);
    } else {
      sheathColor = const Color(0xFF0EA5E9).withValues(alpha: 0.70);
      coreColor = const Color(0xFFFFFFFF);
      tailColor = Color.lerp(
        const Color(0xFFFDE047),
        const Color(0xFFEA580C),
        (tel.soot * 0.82).clamp(0.25, 0.92),
      )!
          .withValues(alpha: 0.94);
    }

    if (isSphere) {
      final center = _project(0.28 + liftoffX, buoyCurve * 0.25, 0, size);
      final edge = _project(0.28 + liftoffX + flameRad, buoyCurve * 0.25, 0, size);
      final rPx = (edge.$1 - center.$1).abs().clamp(26.0, 125.0);

      canvas.drawCircle(
        Offset(center.$1, center.$2),
        rPx * 1.5,
        Paint()
          ..color = sheathColor.withValues(alpha: 0.48)
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
      canvas.drawCircle(
        Offset(center.$1, center.$2),
        rPx,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(
            Offset(center.$1, center.$2),
            rPx,
            [coreColor, sheathColor, sheathColor.withValues(alpha: 0.0)],
            [0.0, 0.48, 1.0],
          ),
      );
    } else {
      final x0 = 0.05 + liftoffX;
      final base = _project(x0, 0, 0, size);
      final tip = _project(
        x0 + flameLen,
        buoyCurve + 0.03 * math.sin(time * 9.0),
        0,
        size,
      );
      final rBasePx = flameRad * (size.height * 0.34);

      // Ambient cyan flow streamlines around plume
      final streamPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22)
        ..strokeWidth = 1.0;
      for (int s = 0; s < 4; s++) {
        final sy = (s - 1.5) * 0.36;
        final sx = x0 + 0.2 + ((time * 0.9 + s * 0.31) % 1.0) * (flameLen * 0.7);
        final sp1 = _project(sx, sy, 0, size);
        final sp2 = _project(sx + 0.32, sy, 0, size);
        canvas.drawLine(Offset(sp1.$1, sp1.$2), Offset(sp2.$1, sp2.$2), streamPaint);
      }

      // Layer 1: Undulating Kelvin-Helmholtz Cyan CH* Outer Sheath
      const segCount = 24;
      final upperPts = <Offset>[];
      final lowerPts = <Offset>[];
      for (int i = 0; i <= segCount; i++) {
        final frac = i / segCount;
        final px = x0 + flameLen * frac;
        final py = buoyCurve * (frac * frac) +
            0.02 * math.sin(time * 8.0 - frac * 6.0);
        final pt = _project(px, py, 0, size);
        // Swell at Mach nodes & taper toward tip
        final wave = 1.0 + 0.20 * math.sin(frac * math.pi * 4.5);
        final taper = (1.0 - frac * 0.65) * wave;
        final rad = rBasePx * 1.25 * taper;
        upperPts.add(Offset(pt.$1, pt.$2 - rad));
        lowerPts.add(Offset(pt.$1, pt.$2 + rad));
      }
      final sheathPath = Path()..moveTo(upperPts.first.dx, upperPts.first.dy);
      for (int i = 1; i < upperPts.length; i++) {
        sheathPath.lineTo(upperPts[i].dx, upperPts[i].dy);
      }
      for (int i = lowerPts.length - 1; i >= 0; i--) {
        sheathPath.lineTo(lowerPts[i].dx, lowerPts[i].dy);
      }
      sheathPath.close();

      canvas.drawPath(
        sheathPath,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(base.$1, base.$2),
            Offset(tip.$1, tip.$2),
            [
              sheathColor,
              const Color(0xFF0284C7).withValues(alpha: 0.55),
              sheathColor.withValues(alpha: 0.0),
            ],
            [0.0, 0.55, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );

      // Layer 2: Luminous Plume Body (white-hot -> golden amber -> orange tail)
      final coreUpper = <Offset>[];
      final coreLower = <Offset>[];
      for (int i = 0; i <= segCount; i++) {
        final frac = i / segCount;
        final px = x0 + flameLen * frac;
        final py = buoyCurve * (frac * frac) +
            0.02 * math.sin(time * 9.0 - frac * 7.0);
        final pt = _project(px, py, 0, size);
        final pinch = 1.0 + 0.28 * math.sin(frac * math.pi * 5.0);
        final rad = rBasePx * 0.62 * (1.0 - frac * 0.72) * pinch;
        coreUpper.add(Offset(pt.$1, pt.$2 - rad));
        coreLower.add(Offset(pt.$1, pt.$2 + rad));
      }
      final plumePath = Path()..moveTo(coreUpper.first.dx, coreUpper.first.dy);
      for (int i = 1; i < coreUpper.length; i++) {
        plumePath.lineTo(coreUpper[i].dx, coreUpper[i].dy);
      }
      for (int i = coreLower.length - 1; i >= 0; i--) {
        plumePath.lineTo(coreLower[i].dx, coreLower[i].dy);
      }
      plumePath.close();

      canvas.drawPath(
        plumePath,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(base.$1, base.$2),
            Offset(tip.$1, tip.$2),
            [
              coreColor,
              const Color(0xFFFEF08A),
              tailColor,
              tailColor.withValues(alpha: 0.15),
            ],
            [0.0, 0.35, 0.78, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Layer 3: Intense White-Hot Mach Shock Diamonds (Additive Bloom)
      const nodes = 4;
      for (int k = 0; k < nodes; k++) {
        final frac = 0.11 + k * 0.24;
        final nx = x0 + flameLen * frac;
        final ny = buoyCurve * (frac * frac) +
            0.02 * math.sin(time * 10.0 - k * 1.4);
        final np = _project(nx, ny, 0, size);
        final nodeRx = rBasePx * (0.76 - frac * 0.36);
        final nodeRy = rBasePx * (0.56 - frac * 0.28);
        final nodeColor = k < 2
            ? Colors.white
            : Color.lerp(const Color(0xFFFEF08A), tailColor, (k - 1) / 2.5)!;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(np.$1, np.$2),
            width: nodeRx * 2.4,
            height: nodeRy * 1.75,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = nodeColor.withValues(alpha: 0.92 - frac * 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }

      // Layer 4: Lifted Triple-Flame Crescent Ring if H_L > 1.0mm
      if (tel.liftoffMm > 1.0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(base.$1, base.$2),
            width: 11,
            height: rBasePx * 1.85,
          ),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // 4. Soot / SiO2 Particles
    if (tel.soot > 0.20 || fuelIdx == 1) {
      final pColor = fuelIdx == 1
          ? Colors.white.withValues(alpha: 0.72)
          : const Color(0xFFFBBF24).withValues(alpha: 0.72);
      final pPaint = Paint()..color = pColor;
      for (int i = 0; i < 18; i++) {
        final phase = ((time * 0.75 + i * 0.13) % 1.0);
        final px = 0.25 + liftoffX + phase * (flameLen + 0.55);
        final py = buoyCurve * (phase * phase) +
            math.sin(i * 2.3 + time * 3.5) * 0.16;
        final pt = _project(px, py, math.cos(i * 1.7) * 0.12, size);
        canvas.drawCircle(Offset(pt.$1, pt.$2), 2.0, pPaint);
      }
    }

    // 5. Bottom-left 3D Axis Gizmo (+Y BUOY, +X FLOW, +Z)
    _drawAxisGizmo(canvas, size);
  }

  void _drawAxisGizmo(Canvas canvas, Size size) {
    const ox = 28.0;
    final oy = size.height - 24.0;
    canvas.drawLine(
      Offset(ox, oy),
      Offset(ox, oy - 22),
      Paint()
        ..color = const Color(0xFF22C55E)
        ..strokeWidth = 1.8,
    );
    canvas.drawLine(
      Offset(ox, oy),
      Offset(ox + 22, oy),
      Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 1.8,
    );
    canvas.drawLine(
      Offset(ox, oy),
      Offset(ox + 10, oy + 8),
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.6,
    );

    void label(String txt, Offset pos, Color col) {
      final tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            color: col,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos);
    }

    label('+Y (BUOY)', Offset(ox + 4, oy - 24), const Color(0xFF4ADE80));
    label('+Z +X (FLOW)', Offset(ox + 6, oy + 2), const Color(0xFFF87171));
  }

  @override
  bool shouldRepaint(covariant _MultiRegimeFlamePainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.o2Pct != o2Pct ||
      oldDelegate.pressPsi != pressPsi ||
      oldDelegate.flowCmS != flowCmS ||
      oldDelegate.gravityG != gravityG ||
      oldDelegate.fuelIdx != fuelIdx ||
      oldDelegate.diluentKey != diluentKey ||
      oldDelegate.tel.isCool != tel.isCool;
}
