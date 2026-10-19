import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// Pick a user and enter the PIN. Shown whenever users are set up and
/// nobody is signed in (start-up, lock, auto-lock).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AppUser? _user;
  String _pin = '';
  String? _error;
  int _fails = 0;
  DateTime? _blockedUntil;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _key(String k) {
    if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 8) {
        _pin += k;
      }
    });
  }

  void _submit() {
    final app = AppScope.read(context);
    final u = _user;
    if (u == null) return;
    final pin = _pin.replaceAll('✓', '');
    if (pin.length < 4) {
      setState(() => _error = 'PIN has at least 4 digits');
      return;
    }
    if (!app.login(u, pin)) {
      _fails++;
      setState(() {
        _pin = '';
        _error = 'Wrong PIN';
        if (_fails >= 5) {
          _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
          _error = 'Too many attempts. Wait 30 seconds.';
          _fails = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final users = app.users.where((u) => u.active).toList();
    _user ??= users.length == 1 ? users.first : null;
    Widget keyBtn(String k) => Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 74,
            height: 60,
            child: FilledButton.tonal(
              onPressed: () => k == '✓' ? _submit() : _key(k),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(k, style: LBText.reading(k == '⌫' || k == '✓' ? 20 : 22, c.ink, weight: FontWeight.w700)),
            ),
          ),
        );
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('LAB', style: LBText.label(c.ink, size: 22)),
                Text('LEDGER', style: LBText.label(c.accent, size: 22)),
              ]),
              const SizedBox(height: 6),
              Text(app.settings.labName, textAlign: TextAlign.center, style: LBText.body(c.inkDim, size: 13)),
              const SizedBox(height: 26),
              if (_user == null) ...[
                Text('Who is signing in?', style: LBText.title(c.ink)),
                const SizedBox(height: 14),
                for (final u in users)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: c.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.line)),
                      child: ListTile(
                        onTap: () => setState(() => _user = u),
                        leading: CircleAvatar(backgroundColor: c.accent.withOpacity(0.18), child: Text(u.initials, style: LBText.body(c.accent, weight: FontWeight.w700))),
                        title: Text(u.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                        subtitle: Text(u.role.label, style: LBText.body(c.inkDim, size: 12)),
                        trailing: Icon(Icons.chevron_right_rounded, color: c.inkDim),
                      ),
                    ),
                  ),
              ] else ...[
                CircleAvatar(radius: 32, backgroundColor: c.accent.withOpacity(0.18), child: Text(_user!.initials, style: LBText.title(c.accent, size: 22))),
                const SizedBox(height: 10),
                Text(_user!.name, style: LBText.title(c.ink)),
                Text(_user!.role.label, style: LBText.body(c.inkDim, size: 12.5)),
                if (users.length > 1)
                  TextButton(
                    onPressed: () => setState(() {
                      _user = null;
                      _pin = '';
                    }),
                    child: const Text('Switch user'),
                  ),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 6; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length ? c.accent : Colors.transparent,
                        border: Border.all(color: _error != null ? c.poor : c.line, width: 2),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                SizedBox(height: 20, child: Text(_error ?? '', style: LBText.body(c.poor, size: 12.5))),
                const SizedBox(height: 8),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['⌫', '0', '✓'],
                ])
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final k in row) keyBtn(k)]),
                const SizedBox(height: 10),
                // Physical keyboards (PC): type the PIN and press Enter.
                SizedBox(
                  width: 1,
                  height: 1,
                  child: KeyboardListener(
                    focusNode: _focus,
                    autofocus: true,
                    onKeyEvent: (e) {
                      if (e is! KeyDownEvent) return;
                      final l = e.logicalKey;
                      if (l == LogicalKeyboardKey.enter || l == LogicalKeyboardKey.numpadEnter) {
                        _submit();
                      } else if (l == LogicalKeyboardKey.backspace) {
                        _key('⌫');
                      } else if (e.character != null && RegExp(r'^\d$').hasMatch(e.character!)) {
                        _key(e.character!);
                      }
                    },
                    child: const SizedBox(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Forgot your PIN? An administrator can reset it under Users.', textAlign: TextAlign.center, style: LBText.body(c.inkDim, size: 11.5)),
            ]),
          ),
        ),
      ),
    );
  }
}
