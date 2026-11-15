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
  double _yaw = 0.35;
  double _pitch = 0.22;
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
            _yaw += 0.004;
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
          _buildExperimentBar(tel),
          const SizedBox(height: 12),
          _buildKpiGrid(tel),
          const SizedBox(height: 12),
          _buildDropdownBar(),
          const SizedBox(height: 12),
          _buildViewportCard(tel),
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
        title: 'P(BURN) · MODEL v2.2',
        value: '$probPct%',
        subtitle: '${tel.regime} · ROC 0.9947',
        accent: probColor,
      ),
      _kpiCard(
        title: 'SPREAD / REGRESSION',
        value: '${tel.spread.toStringAsFixed(2)} mm/s',
        subtitle: 'T_f ${tel.tempK.round()} K · B ${tel.bNumber.toStringAsFixed(2)}',
        accent: _accentAmber,
      ),
      _kpiCard(
        title: 'FLAMMABILITY LIMIT (MOC)',
        value: '${tel.mocActual.toStringAsFixed(1)}% O₂',
        subtitle: 'Margin ${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}% · Le ${tel.lewisNumber.toStringAsFixed(2)}',
        accent: margin >= 0 ? _accentRed : _accentGreen,
      ),
      _kpiCard(
        title: 'MIXED FLOW & SOOT',
        value: '${tel.effVel.toStringAsFixed(1)} cm/s',
        subtitle: 'u_b ${tel.uBuoy >= 0 ? '+' : ''}${tel.uBuoy.toStringAsFixed(1)} · Soot ${tel.sootPpm.toStringAsFixed(1)} ppm',
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

  Widget _buildDropdownBar() {
    final presetCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdownLabel('1. HABITAT / GRAVITY PRESET'),
        const SizedBox(height: 5),
        _buildStyledDropdown<String>(
          value: _selectedPreset,
          items: const [
            DropdownMenuItem(value: 'CUSTOM', child: Text('Custom / Slider Conditions', overflow: TextOverflow.ellipsis, maxLines: 1)),
            DropdownMenuItem(value: 'ISS', child: Text('ISS Destiny (0.0g · 21% O2 · 14.7 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
            DropdownMenuItem(value: 'LUNAR', child: Text('Lunar Artemis SEA (0.166g · 34% O2 · 8.2 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
            DropdownMenuItem(value: 'MARS', child: Text('Mars Habitat (0.38g · 34% O2 · 8.2 psi)', overflow: TextOverflow.ellipsis, maxLines: 1)),
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
      ],
    );

    final diluentCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdownLabel('2. DILUENT GAS'),
        const SizedBox(height: 5),
        _buildStyledDropdown<String>(
          value: _diluentKey,
          items: const [
            DropdownMenuItem(value: 'N2', child: Text('N₂ — Nitrogen (Standard Cabin)', overflow: TextOverflow.ellipsis, maxLines: 1)),
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
      ],
    );

    final fuelCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdownLabel('3. FUEL SPECIMEN & BURNER FAMILY'),
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
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bgPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 660) {
            return Row(
              children: [
                Expanded(child: presetCol),
                const SizedBox(width: 10),
                Expanded(child: diluentCol),
                const SizedBox(width: 10),
                Expanded(child: fuelCol),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              presetCol,
              const SizedBox(height: 8),
              diluentCol,
              const SizedBox(height: 8),
              fuelCol,
            ],
          );
        },
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

    final scale = (size.height * 0.42) * zoom / (3.8 + z2 * 0.35);
    return (size.width * 0.34 + x1 * scale, size.height * 0.56 - y2 * scale, z2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dark grid
    final gridPaint = Paint()
      ..color = const Color(0xFF192130)
      ..strokeWidth = 0.8;
    for (double gx = -1.6; gx <= 2.4; gx += 0.4) {
      final p1 = _project(gx, -0.8, -0.8, size);
      final p2 = _project(gx, -0.8, 0.8, size);
      canvas.drawLine(Offset(p1.$1, p1.$2), Offset(p2.$1, p2.$2), gridPaint);
    }

    // 1. Solid De Laval Nozzle + Fuel Specimen Holder
    final nozzlePoints = <List<(double, double, double)>>[];
    const segs = 14;
    const rings = 10;
    for (int i = 0; i <= rings; i++) {
      final t = i / rings;
      final x = -1.35 + t * 1.35;
      // Convergent-divergent De Laval profile
      double r;
      if (t < 0.4) {
        r = 0.24 - 0.12 * (t / 0.4);
      } else {
        final dt = (t - 0.4) / 0.6;
        r = 0.12 + 0.14 * dt * dt + 0.04 * dt;
      }
      final ring = <(double, double, double)>[];
      for (int j = 0; j < segs; j++) {
        final ang = (j / segs) * 2 * math.pi;
        ring.add(_project(x, r * math.sin(ang), r * math.cos(ang), size));
      }
      nozzlePoints.add(ring);
    }

    for (int i = 0; i < rings; i++) {
      for (int j = 0; j < segs; j++) {
        final nj = (j + 1) % segs;
        final a = nozzlePoints[i][j];
        final b = nozzlePoints[i + 1][j];
        final c = nozzlePoints[i + 1][nj];
        final d = nozzlePoints[i][nj];
        final shade = (0.35 + 0.4 * ((a.$3 + b.$3) * 0.5 + 0.3)).clamp(0.15, 0.9);
        final path = Path()
          ..moveTo(a.$1, a.$2)
          ..lineTo(b.$1, b.$2)
          ..lineTo(c.$1, c.$2)
          ..lineTo(d.$1, d.$2)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF334155),
              const Color(0xFFB45309),
              (i / rings) * shade,
            )!
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.08)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }

    // 2. Multi-Regime Flame Body
    if (tel.prob < 0.06 && !tel.isCool) {
      // Quenched smoke/vapor wisps
      final smokePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      for (int k = 0; k < 4; k++) {
        final sx = 0.15 + k * 0.28 + 0.05 * math.sin(time * 2 + k);
        final p = _project(sx, 0.04 * math.sin(time + k), 0.0, size);
        canvas.drawCircle(Offset(p.$1, p.$2), 10 + k * 4.0, smokePaint);
      }
      return;
    }

    final pulse = tel.isPulsating
        ? (0.72 + 0.28 * math.sin(time * 7.5))
        : (0.94 + 0.06 * math.sin(time * 12.0));
    final liftoffX = (tel.liftoffMm / 25.0).clamp(0.0, 0.45);
    final isSphere = tel.effVel < 3.5;

    final flameLen = isSphere
        ? 0.65 * pulse
        : (0.9 + (tel.aspectLD * 0.28).clamp(0.2, 1.9)) * pulse;
    final flameRad = isSphere
        ? (0.34 + 0.08 * tel.prob) * pulse
        : (0.24 + 0.07 * (o2Pct / 45.0)) * pulse;

    // Gravity buoyancy curve (+g pushes up, -g pushes down)
    final buoyCurve = (gravityG / 2.0) * 0.38;

    final Color outerColor;
    final Color innerColor;
    if (tel.isCool) {
      outerColor = const Color(0xFF7C3AED).withValues(alpha: 0.55);
      innerColor = const Color(0xFF38BDF8).withValues(alpha: 0.75);
    } else if (o2Pct >= 28.0 && tel.soot < 0.4) {
      outerColor = const Color(0xFF2563EB).withValues(alpha: 0.75);
      innerColor = const Color(0xFFE0F2FE).withValues(alpha: 0.95);
    } else {
      outerColor = Color.lerp(
        const Color(0xFF38BDF8),
        const Color(0xFFEF4444),
        (tel.soot * 1.1).clamp(0.15, 1.0),
      )!
          .withValues(alpha: 0.78);
      innerColor = Color.lerp(
        const Color(0xFFBAE6FD),
        const Color(0xFFFDE047),
        (tel.soot * 0.9).clamp(0.1, 0.95),
      )!
          .withValues(alpha: 0.95);
    }

    if (isSphere) {
      final center = _project(0.22 + liftoffX, buoyCurve * 0.3, 0, size);
      final edge = _project(0.22 + liftoffX + flameRad, buoyCurve * 0.3, 0, size);
      final rPx = (edge.$1 - center.$1).abs().clamp(16.0, 110.0);

      canvas.drawCircle(
        Offset(center.$1, center.$2),
        rPx * 1.35,
        Paint()
          ..color = outerColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(
        Offset(center.$1, center.$2),
        rPx,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(center.$1, center.$2),
            rPx,
            [innerColor, outerColor, outerColor.withValues(alpha: 0.0)],
            [0.0, 0.55, 1.0],
          ),
      );
    } else {
      final base = _project(0.02 + liftoffX, 0, 0, size);
      final mid = _project(
        0.02 + liftoffX + flameLen * 0.45,
        buoyCurve * 0.35,
        0,
        size,
      );
      final tip = _project(
        0.02 + liftoffX + flameLen,
        buoyCurve + 0.04 * math.sin(time * 9.0),
        0,
        size,
      );
      final rBasePx = flameRad * (size.height * 0.25);

      // Outer glow plume
      final outerPath = Path()
        ..moveTo(base.$1, base.$2 - rBasePx)
        ..quadraticBezierTo(
          mid.$1,
          mid.$2 - rBasePx * 0.85,
          tip.$1,
          tip.$2 - (tel.isTipOpen ? rBasePx * 0.35 : 0),
        )
        ..lineTo(tip.$1, tip.$2 + (tel.isTipOpen ? rBasePx * 0.35 : 0))
        ..quadraticBezierTo(
          mid.$1,
          mid.$2 + rBasePx * 0.85,
          base.$1,
          base.$2 + rBasePx,
        )
        ..close();

      canvas.drawPath(
        outerPath,
        Paint()
          ..color = outerColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Inner core
      final corePath = Path()
        ..moveTo(base.$1, base.$2 - rBasePx * 0.52)
        ..quadraticBezierTo(mid.$1, mid.$2 - rBasePx * 0.42, tip.$1 * 0.72 + base.$1 * 0.28, mid.$2 * 0.6 + tip.$2 * 0.4)
        ..quadraticBezierTo(mid.$1, mid.$2 + rBasePx * 0.42, base.$1, base.$2 + rBasePx * 0.52)
        ..close();

      canvas.drawPath(
        corePath,
        Paint()
          ..color = innerColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Liftoff ring if H_L > 1.0mm
      if (tel.liftoffMm > 1.0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(base.$1, base.$2),
            width: 8,
            height: rBasePx * 1.9,
          ),
          Paint()
            ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    // Soot / SiO2 particles
    if (tel.soot > 0.25 || fuelIdx == 1) {
      final pColor = fuelIdx == 1
          ? Colors.white.withValues(alpha: 0.65)
          : const Color(0xFFF59E0B).withValues(alpha: 0.55);
      final pPaint = Paint()..color = pColor;
      for (int i = 0; i < 14; i++) {
        final phase = ((time * 0.8 + i * 0.17) % 1.0);
        final px = 0.2 + liftoffX + phase * (flameLen + 0.45);
        final py = buoyCurve * phase + math.sin(i * 2.1 + time * 3) * 0.14;
        final pt = _project(px, py, 0, size);
        canvas.drawCircle(Offset(pt.$1, pt.$2), 1.8, pPaint);
      }
    }
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
