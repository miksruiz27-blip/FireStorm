import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/i18n.dart';
import 'app/telemetry_bar.dart';
import 'app/theme.dart';
import 'data/habitats.dart';
import 'screens/copilot_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/gap_map_screen.dart';
import 'screens/habitat_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/report_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await (
    loadHabitats(),
    loadDataTranslations(),
  ).wait; // atmospheres from the API (snapshot offline) before the first frame
  runApp(const ProviderScope(child: FirestormApp()));
}

List<({String path, String label, IconData icon})> get _destinations => [
  (path: '/', label: tr('Ambient', 'Hábitat'), icon: Icons.public),
  (
    path: '/forecast',
    label: tr('Forecast', 'Pronóstico'),
    icon: Icons.local_fire_department_outlined,
  ),
  (path: '/ranking', label: 'Ranking', icon: Icons.format_list_numbered),
  (path: '/gaps', label: tr('Gap map', 'Mapa de vacíos'), icon: Icons.grid_on),
  (
    path: '/copilot',
    label: tr('Copilot', 'Copiloto'),
    icon: Icons.chat_bubble_outline,
  ),
  (
    path: '/report',
    label: tr('Report', 'Reporte'),
    icon: Icons.description_outlined,
  ),
  (path: '/lab', label: tr('Lab', 'Laboratorio'), icon: Icons.science_outlined),
];

class FirestormApp extends StatefulWidget {
  const FirestormApp({super.key});

  @override
  State<FirestormApp> createState() => _FirestormAppState();
}

class _FirestormAppState extends State<FirestormApp> {
  late var _router = _buildRouter('/');

  /// A language switch rebuilds every screen: new router (fresh pages) at the same location.
  void _onLang() {
    final at = _router.routerDelegate.currentConfiguration.uri.toString();
    final old = _router;
    setState(() => _router = _buildRouter(at));
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void initState() {
    super.initState();
    lang.addListener(_onLang);
  }

  GoRouter _buildRouter(String initial) => GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _Shell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HabitatScreen()),
          GoRoute(path: '/forecast', builder: (_, _) => const ForecastScreen()),
          GoRoute(path: '/ranking', builder: (_, _) => const RankingScreen()),
          GoRoute(path: '/gaps', builder: (_, _) => const GapMapScreen()),
          GoRoute(path: '/copilot', builder: (_, _) => const CopilotScreen()),
          GoRoute(path: '/lab', builder: (_, _) => const LabScreen()),
          GoRoute(
            path: '/report',
            builder: (_, _) => const ReportScreen(),
            routes: [
              GoRoute(
                path: ':code',
                builder: (_, s) => ReportScreen(code: s.pathParameters['code']),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    lang.removeListener(_onLang);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    key: ValueKey(_router), // remount with the new router
    title: 'FireStorm',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    routerConfig: _router,
  );
}

/// Nav rail full-height on the left with the telemetry bar over the content (wide), or bottom bar (narrow).
class _Shell extends StatelessWidget {
  const _Shell({required this.path, required this.child});
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = _destinations
        .indexWhere(
          (d) =>
              d.path == path ||
              (d.path != '/' && path.startsWith('${d.path}/')),
        )
        .clamp(0, 99);
    void go(int i) => context.go(_destinations[i].path);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final content = Column(
      children: [
        // Phones: keep the telemetry bar below the system status bar.
        const ColoredBox(
          color: AppColors.rail,
          child: SafeArea(bottom: false, child: TelemetryBar()),
        ),
        Expanded(child: child),
      ],
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: go,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 12),
                    child: BrandMark(),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: go,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
