import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'screens/calibration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/qc_screen.dart';
import 'screens/samples_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(LabLedgerApp(state: state));
}

class LabLedgerApp extends StatelessWidget {
  final AppState state;
  const LabLedgerApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final app = AppScope.of(context);
        final light = app.settings.daylight;
        SystemChrome.setSystemUIOverlayStyle(light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);
        return MaterialApp(
          title: 'LabLedger',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(light ? LBColors.daylight : LBColors.lab),
          home: const Shell(),
        );
      }),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    SamplesScreen(),
    CalibrationScreen(),
    QcScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) AppScope.read(context).saveNow();
  }

  void go(int i) => setState(() => tab = i);

  static const _dest = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
    (Icons.science_outlined, Icons.science_rounded, 'Samples'),
    (Icons.show_chart_rounded, Icons.show_chart_rounded, 'Calibrate'),
    (Icons.verified_outlined, Icons.verified_rounded, 'QC'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'More'),
  ];

  void _select(int i) {
    HapticFeedback.selectionClick();
    go(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final pages = IndexedStack(index: tab, children: _pages);
    if (wide) {
      // PC / tablet: side rail, and keep reading width comfortable.
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: _select,
              backgroundColor: c.surface,
              indicatorColor: c.accent.withOpacity(0.18),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Icon(Icons.biotech_rounded, color: c.accent, size: 30),
              ),
              destinations: [
                for (final d in _dest)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            VerticalDivider(width: 1, color: c.line),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: pages),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: c.surface,
        indicatorColor: c.accent.withOpacity(0.18),
        onDestinationSelected: _select,
        destinations: [
          for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
