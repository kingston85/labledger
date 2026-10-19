import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/lab_models.dart';
import '../data/lab_ops.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/panels.dart';
import 'business_screen.dart';
import 'field_screen.dart';
import 'quality_screen.dart';
import 'register_screen.dart';
import 'sample_detail_screen.dart';

IconData calIcon(CalKind k) => switch (k) {
      CalKind.sampleDue => Icons.science_rounded,
      CalKind.trip => Icons.directions_car_rounded,
      CalKind.calibration => Icons.tune_rounded,
      CalKind.service => Icons.build_rounded,
      CalKind.reagentExpiry => Icons.hourglass_bottom_rounded,
      CalKind.invoiceDue => Icons.receipt_long_rounded,
      CalKind.ncDue => Icons.report_problem_rounded,
      CalKind.ptDue => Icons.emoji_events_rounded,
      CalKind.methodReview => Icons.menu_book_rounded,
      CalKind.purchase => Icons.shopping_cart_rounded,
    };

Color calColor(LBColors c, CalKind k) => switch (k) {
      CalKind.sampleDue => c.accent,
      CalKind.trip => const Color(0xFF2EC4B6),
      CalKind.calibration || CalKind.service => const Color(0xFF9B7BFF),
      CalKind.reagentExpiry => c.fair,
      CalKind.invoiceDue => const Color(0xFFFF6FA8),
      CalKind.ncDue => c.poor,
      CalKind.ptDue || CalKind.methodReview => c.good,
      CalKind.purchase => c.inkDim,
    };

/// Opens whatever a calendar event refers to.
void openCalEvent(BuildContext context, CalEvent e) {
  final r = e.ref;
  if (r is Sample) {
    openPage(context, SampleDetailScreen(sample: r));
  } else if (r is FieldTrip) {
    openTripEditor(context, r);
  } else if (r is Instrument) {
    openInstrumentLog(context, r);
  } else if (r is Reagent) {
    editReagent(context, r);
  } else if (r is Invoice) {
    openInvoiceEditor(context, r);
  } else if (r is NonConformance) {
    openNcEditor(context, r);
  } else if (r is PtRound) {
    openPtEditor(context, r);
  } else if (r is LabMethod) {
    openMethodEditor(context, r);
  }
}

/// Lab calendar: due results, field trips, calibrations, expiries, invoice
/// due dates, corrective actions and PT deadlines in one place.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  final Set<CalKind> _hidden = {};

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final all = app.calendarEvents().where((e) => !_hidden.contains(e.kind)).toList();
    final today = DateTime.now();
    final lateEvents = all.where((e) => e.overdue).toList();
    final kinds = CalKind.values.where((k) => app.calendarEvents().any((e) => e.kind == k)).toList();

    final grid = _MonthGrid(
      month: _month,
      events: all,
      selected: _day,
      onDay: (d) => setState(() => _day = _day != null && _same(_day!, d) ? null : d),
    );

    final agendaEvents = _day != null
        ? all.where((e) => _same(e.date, _day!)).toList()
        : all.where((e) => !e.date.isBefore(DateTime(today.year, today.month, today.day)) && e.date.isBefore(today.add(const Duration(days: 45)))).toList();

    final agenda = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_day == null && lateEvents.isNotEmpty) ...[
        PanelLabel('Overdue (${lateEvents.length})', color: c.poor),
        const SizedBox(height: 6),
        for (final e in lateEvents.take(12)) _EventTile(e),
        const SizedBox(height: 14),
      ],
      PanelLabel(_day == null ? 'Next 45 days' : '${_day!.day} ${_months[_day!.month - 1]} ${_day!.year}'),
      const SizedBox(height: 6),
      if (agendaEvents.isEmpty) LBCard(child: Text(_day == null ? 'Nothing scheduled.' : 'Nothing on this day.', style: LBText.body(c.inkDim, size: 13))),
      for (final e in agendaEvents.where((e) => _day != null || !e.overdue)) _EventTile(e),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab calendar'),
        actions: [
          IconButton(tooltip: 'Previous month', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
          TextButton(onPressed: () => setState(() => _month = DateTime(today.year, today.month)), child: Text('${_months[_month.month - 1]} ${_month.year}')),
          IconButton(tooltip: 'Next month', onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in kinds)
              FilterChip(
                avatar: Icon(calIcon(k), size: 16, color: calColor(c, k)),
                label: Text(k.label),
                selected: !_hidden.contains(k),
                onSelected: (v) => setState(() => v ? _hidden.remove(k) : _hidden.add(k)),
              ),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth >= 980) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: grid),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: agenda),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [grid, const SizedBox(height: 16), agenda]);
          }),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalEvent e;
  const _EventTile(this.e);

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final col = calColor(c, e.kind);
    final d = daysUntil(e.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LBCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderColor: e.overdue ? c.poor.withOpacity(0.5) : null,
        onTap: () => openCalEvent(context, e),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: col.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(calIcon(e.kind), size: 18, color: col),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${e.kind.label} · ${e.detail}', style: LBText.body(c.inkDim, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(shortDate(e.date), style: LBText.reading(11.5, c.inkDim)),
            Text(d == 0 ? 'today' : (d < 0 ? '${-d} d late' : 'in $d d'), style: LBText.body(e.overdue ? c.poor : c.inkDim, size: 11, weight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<CalEvent> events;
  final DateTime? selected;
  final ValueChanged<DateTime> onDay;
  const _MonthGrid({required this.month, required this.events, required this.selected, required this.onDay});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final first = DateTime(month.year, month.month, 1);
    final lead = (first.weekday + 6) % 7; // Monday first
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((lead + days + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final byDay = <int, List<CalEvent>>{};
    for (final e in events) {
      if (e.date.year == month.year && e.date.month == month.month) (byDay[e.date.day] ??= []).add(e);
    }
    return LBCard(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Row(children: [
          for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(d, style: LBText.label(c.inkDim, size: 10))))),
        ]),
        for (var w = 0; w < cells ~/ 7; w++)
          Row(children: [
            for (var k = 0; k < 7; k++)
              Expanded(
                child: () {
                  final n = w * 7 + k - lead + 1;
                  if (n < 1 || n > days) return const SizedBox(height: 74);
                  final date = DateTime(month.year, month.month, n);
                  final ev = byDay[n] ?? const <CalEvent>[];
                  final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                  final isSel = selected != null && selected!.year == date.year && selected!.month == date.month && selected!.day == date.day;
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: isSel ? c.accent.withOpacity(0.16) : (k >= 5 ? c.surface2.withOpacity(0.5) : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onDay(date),
                        child: Container(
                          height: 70,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: isToday ? c.accent : c.line.withOpacity(0.6))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$n', style: LBText.reading(12, isToday ? c.accent : c.ink, weight: isToday ? FontWeight.w700 : FontWeight.w500)),
                            const Spacer(),
                            if (ev.isNotEmpty)
                              Wrap(spacing: 3, runSpacing: 3, children: [
                                for (final e in ev.take(6))
                                  Container(width: 7, height: 7, decoration: BoxDecoration(color: e.overdue ? c.poor : calColor(c, e.kind), shape: BoxShape.circle)),
                                if (ev.length > 6) Text('+${ev.length - 6}', style: LBText.body(c.inkDim, size: 9)),
                              ]),
                          ]),
                        ),
                      ),
                    ),
                  );
                }(),
              ),
          ]),
      ]),
    );
  }
}
