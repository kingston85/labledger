import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/data_grid.dart';
import '../widgets/inputs.dart';
import '../widgets/share.dart';

/// Users & roles, security settings and the audit trail.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _tab = 0;
  final _q = TextEditingController();
  String? _userFilter;
  String? _actionFilter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Users & audit trail')),
      floatingActionButton: _tab == 0 && app.isAdmin
          ? FloatingActionButton.extended(onPressed: () => _editUser(context, null), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add user'))
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Segmented<int>(values: const [0, 1, 2], selected: _tab, label: (i) => const ['Users & roles', 'Audit trail', 'Security'][i], onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 12),
          switch (_tab) {
            0 => _users(context, app),
            1 => _audit(context, app),
            _ => _security(context, app),
          },
        ],
      ),
    );
  }

  Widget _users(BuildContext context, AppState app) {
    final c = context.lb;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!app.usersEnabled)
        LBCard(
          borderColor: c.accent.withOpacity(0.5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Single-user mode', style: LBText.body(c.ink, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'LabLedger opens without a login. Add the first user (an administrator) to switch on PIN sign-in, roles '
              '(administrator, reviewer, analyst, viewer), result approval and a named audit trail.',
              style: LBText.body(c.inkDim, size: 13),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: () => _editUser(context, null), icon: const Icon(Icons.admin_panel_settings_rounded), label: const Text('Create administrator')),
          ]),
        ),
      for (final u in app.users)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LBCard(
            onTap: app.isAdmin || app.currentUser == u ? () => _editUser(context, u) : null,
            child: Row(children: [
              CircleAvatar(backgroundColor: (u.active ? c.accent : c.inkDim).withOpacity(0.18), child: Text(u.initials, style: LBText.body(u.active ? c.accent : c.inkDim, weight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(u.name, style: LBText.body(c.ink, weight: FontWeight.w700))),
                    if (app.currentUser == u) ...[const SizedBox(width: 8), Tag('YOU', color: c.good)],
                    if (!u.active) ...[const SizedBox(width: 8), Tag('DISABLED', color: c.poor)],
                  ]),
                  Text('${u.role.label} · last sign-in ${u.lastLogin == null ? 'never' : dateTime(u.lastLogin!)}', style: LBText.body(c.inkDim, size: 12)),
                ]),
              ),
            ]),
          ),
        ),
      const SectionHeader('Roles'),
      LBCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final r in Role.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RichText(
                text: TextSpan(style: LBText.body(c.inkDim, size: 12.5), children: [
                  TextSpan(text: '${r.label}: ', style: LBText.body(c.ink, size: 12.5, weight: FontWeight.w700)),
                  TextSpan(text: r.blurb),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }

  Future<void> _editUser(BuildContext context, AppUser? existing) async {
    final app = AppScope.read(context);
    final first = !app.usersEnabled;
    final name = TextEditingController(text: existing?.name ?? (first ? app.settings.analyst : ''));
    final pin = TextEditingController();
    final pin2 = TextEditingController();
    var role = existing?.role ?? (first ? Role.admin : Role.analyst);
    var active = existing?.active ?? true;
    final selfOnly = existing != null && !app.isAdmin; // users may change their own PIN
    String? error;
    final res = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) {
          final c = context.lb;
          return AlertDialog(
            title: Text(existing == null ? (first ? 'Create administrator' : 'Add user') : (selfOnly ? 'Change my PIN' : 'Edit user')),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: name, readOnly: selfOnly, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                if (!selfOnly && !first)
                  DropdownButtonFormField<Role>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: [for (final r in Role.values) DropdownMenuItem(value: r, child: Text(r.label))],
                    onChanged: (r) => setS(() => role = r ?? role),
                  ),
                if (first) Text('The first user is the administrator.', style: LBText.body(c.inkDim, size: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(labelText: existing == null ? 'PIN (4–8 digits)' : 'New PIN (leave blank to keep)', counterText: ''),
                ),
                TextField(controller: pin2, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Repeat PIN', counterText: '')),
                if (existing != null && !selfOnly && existing != app.currentUser)
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setS(() => active = v), title: const Text('Account active')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: LBText.body(c.poor, size: 12.5))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final p = pin.text.trim();
                  if (name.text.trim().isEmpty) {
                    setS(() => error = 'Enter a name');
                    return;
                  }
                  if ((existing == null || p.isNotEmpty) && !RegExp(r'^\d{4,8}$').hasMatch(p)) {
                    setS(() => error = 'PIN must be 4 to 8 digits');
                    return;
                  }
                  if (p != pin2.text.trim()) {
                    setS(() => error = 'PINs do not match');
                    return;
                  }
                  final admins = app.users.where((u) => u.active && u.role == Role.admin && u != existing).length;
                  if (existing != null && existing.role == Role.admin && (role != Role.admin || !active) && admins == 0) {
                    setS(() => error = 'Keep at least one active administrator');
                    return;
                  }
                  Navigator.pop(context, 'save');
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (res != 'save') return;
    app.update(() {
      final u = existing ?? AppUser(id: newId(), name: name.text.trim(), role: role);
      final changes = <String>[];
      if (existing != null && existing.role != role) changes.add('role ${existing.role.label} → ${role.label}');
      if (existing != null && existing.active != active) changes.add(active ? 'enabled' : 'disabled');
      u.name = name.text.trim();
      if (!selfOnly) u.role = first ? Role.admin : role;
      u.active = active;
      if (pin.text.trim().isNotEmpty) {
        app.setPin(u, pin.text.trim());
        if (existing != null) changes.add('PIN changed');
      }
      if (existing == null) {
        app.users.add(u);
        app.log('create', 'User', u.name, u.role.label);
        if (first) {
          app.currentUser = u;
          u.lastLogin = DateTime.now();
          app.log('login', 'User', u.name, 'first administrator');
        }
      } else {
        app.log('update', 'User', u.name, changes.join(', '));
      }
    });
    if (first && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Users switched on. LabLedger now asks for a PIN when it starts or locks.')));
    }
  }

  Widget _audit(BuildContext context, AppState app) {
    final c = context.lb;
    final q = _q.text.trim().toLowerCase();
    final users = app.audit.map((a) => a.user).toSet().toList()..sort();
    final actions = app.audit.map((a) => a.action).toSet().toList()..sort();
    final list = app.audit.reversed.where((a) {
      if (_userFilter != null && a.user != _userFilter) return false;
      if (_actionFilter != null && a.action != _actionFilter) return false;
      if (q.isEmpty) return true;
      return a.ref.toLowerCase().contains(q) || a.detail.toLowerCase().contains(q) || a.entity.toLowerCase().contains(q);
    }).toList();
    Color actCol(String a) => switch (a) {
          'delete' || 'cancel' || 'login failed' => c.poor,
          'approve' || 'payment' => c.good,
          'create' || 'import' => c.accent,
          'update' => c.fair,
          _ => c.inkDim,
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search record, detail…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            value: _userFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User', isDense: true),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('All users')), for (final u in users) DropdownMenuItem<String?>(value: u, child: Text(u, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _userFilter = v),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String?>(
            value: _actionFilter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Action', isDense: true),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('All actions')), for (final a in actions) DropdownMenuItem<String?>(value: a, child: Text(a))],
            onChanged: (v) => setState(() => _actionFilter = v),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final b = StringBuffer('time,user,action,record_type,record,detail\n');
            String esc(String s) => s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
            for (final a in list) {
              b.writeln([a.time.toIso8601String(), esc(a.user), esc(a.action), esc(a.entity), esc(a.ref), esc(a.detail)].join(','));
            }
            shareText(context, 'LabLedger_audit_trail.csv', b.toString(), 'text/csv');
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export CSV'),
        ),
      ]),
      const SizedBox(height: 12),
      DataGrid<AuditEntry>(
        rows: list,
        minWidth: 820,
        pageSize: 60,
        empty: 'No audit entries match.',
        columns: [
          GridColumn('When', width: 150, cell: (a) => gridText(context, dateTime(a.time), mono: true, size: 12), sortKey: (a) => a.time),
          GridColumn('User', width: 150, cell: (a) => gridText(context, a.user, size: 12.5), sortKey: (a) => a.user),
          GridColumn('Action', width: 110, cell: (a) => Tag(a.action, color: actCol(a.action)), sortKey: (a) => a.action),
          GridColumn('Record', flex: 1.2, cell: (a) => gridText(context, '${a.entity} · ${a.ref}', size: 12.5, bold: true), sortKey: (a) => '${a.entity}${a.ref}'),
          GridColumn('Detail', flex: 2, cell: (a) => gridText(context, a.detail, size: 12.5)),
        ],
      ),
      const SizedBox(height: 6),
      Text('${app.audit.length} entries kept (the latest 5,000 are saved). Entries cannot be edited or deleted from the app.', style: LBText.body(c.inkDim, size: 11.5)),
    ]);
  }

  Widget _security(BuildContext context, AppState app) {
    final c = context.lb;
    final s = app.settings;
    final admin = app.isAdmin;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LBCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          SwitchListTile(
            value: s.requireApproval,
            onChanged: !admin
                ? null
                : (v) => app.update(() {
                      s.requireApproval = v;
                      app.log('update', 'Settings', 'Approval', v ? 'results must be approved before reporting' : 'approval not required');
                    }),
            title: const Text('Results must be approved before reporting'),
            subtitle: const Text('A reviewer or administrator signs off results; unapproved reports are marked DRAFT'),
          ),
          Divider(height: 1, color: c.line),
          ListTile(
            title: const Text('Auto-lock after inactivity'),
            subtitle: Text(s.autoLockMinutes == 0 ? 'Off' : '${s.autoLockMinutes} minutes'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: !admin || s.autoLockMinutes <= 0 ? null : () => app.update(() => s.autoLockMinutes = (s.autoLockMinutes - 5).clamp(0, 120).toInt()),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(width: 34, child: Text('${s.autoLockMinutes}', textAlign: TextAlign.center, style: LBText.reading(15, c.ink, weight: FontWeight.w700))),
              IconButton(
                onPressed: !admin || s.autoLockMinutes >= 120 ? null : () => app.update(() => s.autoLockMinutes = (s.autoLockMinutes + 5).clamp(0, 120).toInt()),
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (app.usersEnabled && admin)
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Turn off user accounts?'),
                content: const Text('All users are disabled and LabLedger opens without a PIN. The audit trail is kept.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn off')),
                ],
              ),
            );
            if (ok == true) {
              app.update(() {
                app.log('update', 'Settings', 'Users', 'user accounts turned off');
                for (final u in app.users) {
                  u.active = false;
                }
                app.currentUser = null;
              });
            }
          },
          icon: Icon(Icons.no_accounts_rounded, color: c.poor),
          label: Text('Turn off user accounts (single-user mode)', style: TextStyle(color: c.poor)),
        ),
      const SizedBox(height: 10),
      Text('PINs are stored only as salted SHA-256 hashes. Five wrong PINs lock the sign-in screen for 30 seconds. '
          'All changes to samples, results, approvals, invoices and users are written to the audit trail.', style: LBText.body(c.inkDim, size: 12)),
    ]);
  }
}
