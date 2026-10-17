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
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) AppScope.read(context).saveNow();
  }

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Scaffold(
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: c.surface,
        indicatorColor: c.accent.withOpacity(0.18),
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          go(i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.science_outlined), selectedIcon: Icon(Icons.science_rounded), label: 'Samples'),
          NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Calibrate'),
          NavigationDestination(icon: Icon(Icons.verified_outlined), selectedIcon: Icon(Icons.verified_rounded), label: 'QC'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }
}
