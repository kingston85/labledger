import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_state.dart';
import 'data/models.dart';
import 'screens/admin_screen.dart';
import 'screens/business_screen.dart';
import 'screens/calibration_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/investigation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/more_screen.dart';
import 'screens/qc_screen.dart';
import 'screens/register_screen.dart';
import 'screens/samples_screen.dart';
import 'screens/stats_screen.dart';
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
        return Listener(
          onPointerDown: (_) => app.touch(),
          child: MaterialApp(
            title: 'LabLedger',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(light ? LBColors.daylight : LBColors.lab),
            home: app.locked ? const LoginScreen() : const Shell(),
          ),
        );
      }),
    );
  }
}

class NavItem {
  final String key;
  final String group;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget page;
  const NavItem(this.key, this.group, this.icon, this.activeIcon, this.label, this.page);
}

const navItems = <NavItem>[
  NavItem('dashboard', 'Overview', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Dashboard', DashboardScreen()),
  NavItem('samples', 'Laboratory', Icons.science_outlined, Icons.science_rounded, 'Samples', SamplesScreen()),
  NavItem('investigations', 'Laboratory', Icons.travel_explore_outlined, Icons.travel_explore_rounded, 'Investigations', InvestigationsScreen()),
  NavItem('calibration', 'Laboratory', Icons.show_chart_outlined, Icons.show_chart_rounded, 'Calibration', CalibrationScreen()),
  NavItem('qc', 'Laboratory', Icons.verified_outlined, Icons.verified_rounded, 'Quality control', QcScreen()),
  NavItem('stats', 'Laboratory', Icons.functions_outlined, Icons.functions_rounded, 'Statistics', StatsScreen()),
  NavItem('map', 'Field', Icons.map_outlined, Icons.map_rounded, 'Map & GIS', MapScreen()),
  NavItem('requests', 'Business', Icons.request_quote_outlined, Icons.request_quote_rounded, 'Requests & quotes', BusinessScreen(tab: 0)),
  NavItem('invoices', 'Business', Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Invoices', BusinessScreen(tab: 1)),
  NavItem('clients', 'Business', Icons.business_outlined, Icons.business_rounded, 'Clients', BusinessScreen(tab: 2)),
  NavItem('prices', 'Business', Icons.sell_outlined, Icons.sell_rounded, 'Price list', BusinessScreen(tab: 3)),
  NavItem('register', 'Administration', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing_rounded, 'Lab register', RegisterScreen()),
  NavItem('admin', 'Administration', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded, 'Users & audit', AdminScreen()),
  NavItem('more', 'Administration', Icons.tune_outlined, Icons.tune_rounded, 'Settings & tools', MoreScreen()),
];

// Phone bottom bar: a subset; everything else is reachable from "More".
const _phoneKeys = ['dashboard', 'samples', 'map', 'requests', 'more'];
const _phoneLabels = ['Home', 'Samples', 'Map', 'Business', 'More'];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> with WidgetsBindingObserver {
  String current = 'dashboard';
  Timer? _lock;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock = Timer.periodic(const Duration(seconds: 30), (_) {
      final app = AppScope.read(context);
      final m = app.settings.autoLockMinutes;
      if (app.usersEnabled && app.currentUser != null && m > 0 && DateTime.now().difference(app.lastActivity).inMinutes >= m) {
        app.log('auto-lock', 'User', app.currentUser!.name, 'after $m min idle');
        app.logout();
      }
    });
  }

  @override
  void dispose() {
    _lock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) AppScope.read(context).saveNow();
  }

  /// Navigate to a section by key ('samples', 'invoices', …).
  void goTo(String key) => setState(() => current = key);

  /// Legacy numeric navigation (0 home, 1 samples, 2 calibration, 3 QC, 4 more).
  void go(int i) => goTo(const ['dashboard', 'samples', 'calibration', 'qc', 'more'][i.clamp(0, 4).toInt()]);

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final index = navItems.indexWhere((n) => n.key == current).clamp(0, navItems.length - 1).toInt();
    final pages = IndexedStack(index: index, children: [for (final n in navItems) n.page]);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(current: current, collapsed: _collapsed, onSelect: goTo, onToggle: () => setState(() => _collapsed = !_collapsed)),
          VerticalDivider(width: 1, color: c.line),
          Expanded(child: pages),
        ]),
      );
    }
    // Business sub-pages share the "Business" tab on phones.
    final phoneIndex = () {
      final i = _phoneKeys.indexOf(current);
      if (i >= 0) return i;
      if (const ['invoices', 'clients', 'prices'].contains(current)) return 3;
      return 4;
    }();
    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: phoneIndex,
        backgroundColor: c.surface,
        indicatorColor: c.accent.withOpacity(0.18),
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          goTo(_phoneKeys[i]);
        },
        destinations: [
          for (var i = 0; i < _phoneKeys.length; i++)
            () {
              final n = navItems.firstWhere((x) => x.key == _phoneKeys[i]);
              return NavigationDestination(icon: Icon(n.icon), selectedIcon: Icon(n.activeIcon), label: _phoneLabels[i]);
            }(),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String current;
  final bool collapsed;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  const _Sidebar({required this.current, required this.collapsed, required this.onSelect, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final w = collapsed ? 72.0 : 248.0;
    final groups = <String>[];
    for (final n in navItems) {
      if (!groups.contains(n.group)) groups.add(n.group);
    }
    final alerts = app.registerAlerts.length;
    final overdueInv = app.invoices.where((i) => i.status.name == 'overdue').length;
    final toApprove = app.settings.requireApproval ? app.samples.where((s) => s.results.isNotEmpty && s.results.any((r) => !r.approved) && s.status.index >= 2).length : 0;
    int? badge(String key) => switch (key) {
          'register' => alerts == 0 ? null : alerts,
          'invoices' => overdueInv == 0 ? null : overdueInv,
          'samples' => toApprove == 0 ? null : toApprove,
          _ => null,
        };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: w,
      color: c.surface,
      child: Column(children: [
        SizedBox(
          height: 64,
          child: Row(children: [
            const SizedBox(width: 18),
            Icon(Icons.biotech_rounded, color: c.accent, size: 28),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Row(children: [
                  Text('LAB', style: LBText.label(c.ink, size: 15)),
                  Text('LEDGER', style: LBText.label(c.accent, size: 15)),
                ]),
              ),
            ] else
              const Spacer(),
            IconButton(
              tooltip: collapsed ? 'Expand' : 'Collapse',
              onPressed: onToggle,
              icon: Icon(collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: c.inkDim, size: 20),
            ),
          ]),
        ),
        Divider(height: 1, color: c.line),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
            for (final g in groups) ...[
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                  child: Text(g.toUpperCase(), style: LBText.label(c.inkDim, size: 9.5)),
                )
              else
                const SizedBox(height: 10),
              for (final n in navItems.where((n) => n.group == g))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                  child: Tooltip(
                    message: collapsed ? n.label : '',
                    child: Material(
                      color: current == n.key ? c.accent.withOpacity(0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onSelect(n.key),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          child: Row(children: [
                            Icon(current == n.key ? n.activeIcon : n.icon, size: 20, color: current == n.key ? c.accent : c.inkDim),
                            if (!collapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(n.label,
                                    style: LBText.body(current == n.key ? c.ink : c.inkDim, size: 13.5, weight: current == n.key ? FontWeight.w700 : FontWeight.w500)),
                              ),
                              if (badge(n.key) != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: (n.key == 'samples' ? c.fair : c.poor).withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${badge(n.key)}', style: LBText.reading(11, n.key == 'samples' ? c.fair : c.poor, weight: FontWeight.w700)),
                                ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ]),
        ),
        Divider(height: 1, color: c.line),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: c.accent.withOpacity(0.18),
              child: Text(app.currentUser?.initials ?? '•', style: LBText.body(c.accent, size: 12, weight: FontWeight.w700)),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.userName, style: LBText.body(c.ink, size: 12.5, weight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  Text(app.usersEnabled ? app.role.label : 'Single-user mode', style: LBText.body(c.inkDim, size: 11), overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                tooltip: app.settings.daylight ? 'Dark theme' : 'Daylight theme',
                onPressed: () => app.update(() => app.settings.daylight = !app.settings.daylight),
                icon: Icon(app.settings.daylight ? Icons.dark_mode_outlined : Icons.light_mode_outlined, size: 19, color: c.inkDim),
              ),
              if (app.usersEnabled)
                IconButton(tooltip: 'Lock / sign out', onPressed: app.logout, icon: Icon(Icons.lock_outline_rounded, size: 19, color: c.inkDim)),
            ],
          ]),
        ),
      ]),
    );
  }
}
