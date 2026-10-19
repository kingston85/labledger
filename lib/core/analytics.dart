// Aggregations for the dashboard: monthly volumes, compliance, turnaround,
// exceedance ranking, revenue.

import '../data/app_state.dart';
import '../data/models.dart';
import 'guidelines.dart';

class Month {
  final int year, month;
  const Month(this.year, this.month);
  bool contains(DateTime d) => d.year == year && d.month == month;
  String get label => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  String get longLabel => '$label $year';
}

/// The last [n] calendar months ending with the current one.
List<Month> lastMonths(int n, [DateTime? now]) {
  final t = now ?? DateTime.now();
  return [
    for (var i = n - 1; i >= 0; i--)
      () {
        final d = DateTime(t.year, t.month - i, 1);
        return Month(d.year, d.month);
      }(),
  ];
}

bool sampleExceeds(AppState app, Sample s) {
  final set = app.limitsFor(s);
  return s.results.any((r) {
    final k = checkResult(r, set).status;
    return k == Compliance.exceed || k == Compliance.belowMin;
  });
}

class Analytics {
  final AppState app;
  final List<Month> months;
  Analytics(this.app, {int months = 12, DateTime? now}) : months = lastMonths(months, now);

  DateTime _when(Sample s) => s.receivedAt ?? s.collectedAt;

  List<double> samplesPerMonth() => [for (final m in months) app.samples.where((s) => m.contains(_when(s))).length.toDouble()];

  List<double> exceedingPerMonth() => [for (final m in months) app.samples.where((s) => m.contains(_when(s)) && sampleExceeds(app, s)).length.toDouble()];

  /// Share of results (with an applicable limit) that comply, per month (null = no data).
  List<double?> compliancePerMonth() => [
        for (final m in months)
          () {
            var ok = 0, n = 0;
            for (final s in app.samples.where((s) => m.contains(_when(s)))) {
              final set = app.limitsFor(s);
              for (final r in s.results) {
                final k = checkResult(r, set).status;
                if (k == Compliance.pass || k == Compliance.belowLod) {
                  ok++;
                  n++;
                } else if (k == Compliance.exceed || k == Compliance.belowMin) {
                  n++;
                }
              }
            }
            return n == 0 ? null : ok / n * 100;
          }(),
      ];

  double? overallCompliance({int days = 365}) {
    final from = DateTime.now().subtract(Duration(days: days));
    var ok = 0, n = 0;
    for (final s in app.samples.where((s) => _when(s).isAfter(from))) {
      final set = app.limitsFor(s);
      for (final r in s.results) {
        final k = checkResult(r, set).status;
        if (k == Compliance.pass || k == Compliance.belowLod) {
          ok++;
          n++;
        } else if (k == Compliance.exceed || k == Compliance.belowMin) {
          n++;
        }
      }
    }
    return n == 0 ? null : ok / n * 100;
  }

  /// Mean turnaround (days, receipt → report) per month of reporting.
  List<double?> turnaroundPerMonth() => [
        for (final m in months)
          () {
            final t = app.samples.where((s) => s.reportedAt != null && m.contains(s.reportedAt!)).map((s) => s.turnaroundDays).whereType<double>().toList();
            return t.isEmpty ? null : t.reduce((a, b) => a + b) / t.length;
          }(),
      ];

  double? meanTurnaround() {
    final t = app.samples.map((s) => s.turnaroundDays).whereType<double>().toList();
    return t.isEmpty ? null : t.reduce((a, b) => a + b) / t.length;
  }

  /// Parameters ranked by number of non-compliant results.
  List<(String, int)> topExceeded({int top = 8}) {
    final m = <String, int>{};
    for (final s in app.samples) {
      final set = app.limitsFor(s);
      for (final r in s.results) {
        final k = checkResult(r, set).status;
        if (k == Compliance.exceed || k == Compliance.belowMin) m[canonicalParameter(r.parameter)] = (m[canonicalParameter(r.parameter)] ?? 0) + 1;
      }
    }
    final l = m.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return l.take(top).toList();
  }

  Map<Matrix, int> byMatrix() {
    final m = <Matrix, int>{};
    for (final s in app.samples) {
      m[s.matrix] = (m[s.matrix] ?? 0) + 1;
    }
    return m;
  }

  List<double> invoicedPerMonth() => [
        for (final m in months) app.invoices.where((i) => !i.cancelled && i.issued && m.contains(i.date)).fold(0.0, (a, i) => a + i.total),
      ];

  List<double> collectedPerMonth() => [
        for (final m in months) app.invoices.where((i) => !i.cancelled).expand((i) => i.payments).where((p) => m.contains(p.date)).fold(0.0, (a, p) => a + p.amount),
      ];

  List<(String, double)> topClients({int top = 6}) {
    final m = <String, double>{};
    for (final i in app.invoices.where((i) => !i.cancelled && i.issued)) {
      final name = app.client(i.clientId)?.name ?? 'No client';
      m[name] = (m[name] ?? 0) + i.total;
    }
    final l = m.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return l.take(top).toList();
  }

  /// Values of one parameter across samples of a project or location, in time order.
  List<(Sample, Result)> trend(String parameter, {String? project, String? site}) {
    final k = paramKey(parameter);
    final out = <(Sample, Result)>[];
    for (final s in app.samples) {
      if (project != null && s.project != project) continue;
      if (site != null && s.site != site) continue;
      for (final r in s.results) {
        if (paramKey(r.parameter) == k && (r.value != null || r.belowLod)) out.add((s, r));
      }
    }
    out.sort((a, b) => a.$1.collectedAt.compareTo(b.$1.collectedAt));
    return out;
  }
}
