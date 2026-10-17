// LabLedger tests. Statistical expectations come from SciPy (scipy.stats).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:labledger/core/calibration.dart';
import 'package:labledger/core/guidelines.dart';
import 'package:labledger/core/investigation.dart';
import 'package:labledger/core/utm.dart';
import 'package:labledger/core/stats.dart';
import 'package:labledger/data/models.dart';

void main() {
  group('Distributions (vs scipy.stats)', () {
    test('Student t two-sided p', () {
      expect(tTwoSidedP(2.0, 5), closeTo(0.10193947882985835, 1e-12));
      expect(tTwoSidedP(4.5, 3), closeTo(0.0204904123444534, 1e-12));
      expect(tTwoSidedP(0.2, 30), closeTo(0.8428301570593247, 1e-12));
    });
    test('F upper tail', () {
      expect(fUpperP(3.5, 2, 12), closeTo(0.06346961596914298, 1e-12));
      expect(fUpperP(8.0, 1, 5), closeTo(0.03674259800515246, 1e-12));
    });
    test('t inverse', () {
      expect(tInv(0.975, 4), closeTo(2.7764451051977934, 1e-9));
    });
  });

  group('Tests', () {
    test('one-way ANOVA', () {
      final a = Stats.anova([
        [4.2, 4.5, 4.1, 4.4],
        [5.0, 5.2, 4.9, 5.3],
        [4.6, 4.8, 4.7, 4.5],
      ]);
      expect(a.f, closeTo(23.16, 1e-9));
      expect(a.p, closeTo(0.00028256705221403085, 1e-10));
    });
    test('Welch t-test', () {
      final r = Stats.welch([1.1, 1.3, 1.2, 1.4, 1.25], [1.5, 1.6, 1.45, 1.7]);
      expect(r.t, closeTo(-4.186091791394608, 1e-9));
      expect(r.df, closeTo(6.5937799961604915, 1e-9));
      expect(r.p, closeTo(0.004687525297635189, 1e-9));
    });
    test('one-sample t vs a limit', () {
      final r = Stats.oneSample([0.012, 0.009, 0.011, 0.013, 0.010], 0.01);
      expect(r.t, closeTo(1.4142135623730936, 1e-9));
      expect(r.p, closeTo(0.23019964108049926, 1e-9));
    });
    test('descriptive and 95% CI', () {
      final d = Describe.of([2, 4, 4, 4, 5, 5, 7, 9]);
      expect(d.mean, 5);
      expect(d.median, 4.5);
      expect(d.sd, closeTo(2.138089935299395, 1e-12));
    });
    test('Grubbs flags an obvious outlier', () {
      final g = Stats.grubbs([10.1, 10.2, 9.9, 10.0, 10.1, 12.5])!;
      expect(g.isOutlier, isTrue);
      expect(g.value, 12.5);
      final h = Stats.grubbs([10.1, 10.2, 9.9, 10.0, 10.1, 10.3])!;
      expect(h.isOutlier, isFalse);
    });
  });

  group('QC', () {
    test('RPD and recoveries', () {
      expect(rpd(4.6, 4.3), closeTo(6.741573, 1e-5));
      expect(spikeRecovery(1.02, 0.024, 1.0), closeTo(99.6, 1e-9));
      expect(recovery(0.47, 0.50), closeTo(94, 1e-9));
    });
    test('Westgard rules', () {
      final v = [0.0, 0.5, 3.5, 2.2, 2.3, 1.2, 1.3, 1.1, 1.4];
      final f = westgard(v, 0, 1);
      expect(f[2], contains(WestgardRule.r13s));
      expect(f[4], contains(WestgardRule.r22s));
      expect(f[7], contains(WestgardRule.r41s));
      final drift = westgard([for (var i = 0; i < 10; i++) 0.5], 0, 1);
      expect(drift[9], contains(WestgardRule.r10x));
      final r4 = westgard([2.5, -2.5], 0, 1);
      expect(r4[1], contains(WestgardRule.rR4s));
    });
  });

  group('Calibration', () {
    test('linear fit, LOD, back-calculation', () {
      final f = fitCalibration([
        [0, 0.0012],
        [0.5, 0.0215],
        [1, 0.0431],
        [2, 0.0847],
        [4, 0.1702],
        [6, 0.2539],
      ]);
      expect(f.slope, closeTo(0.04221767, 1e-7));
      expect(f.intercept, closeTo(0.0007769, 1e-7));
      expect(f.r2, greaterThan(0.999));
      expect(f.conc(f.response(3)), closeTo(3, 1e-12));
      expect(f.lod, greaterThan(0));
      expect(f.loq, closeTo(f.lod * 10 / 3.3, 1e-12));
    });
    test('through origin', () {
      final f = fitCalibration([
        [1, 2],
        [2, 4],
        [3, 6],
      ], throughOrigin: true);
      expect(f.slope, closeTo(2, 1e-12));
      expect(f.intercept, 0);
    });
    test('too few standards', () {
      expect(() => fitCalibration([
            [0, 0],
            [1, 1],
          ]), throwsA(isA<CalError>()));
    });
  });

  group('Guidelines', () {
    final who = whoDrinkingWater();
    test('flexible parameter matching', () {
      expect(findLimit(who, 'Pb')?.max, 0.01);
      expect(findLimit(who, 'lead')?.max, 0.01);
      expect(findLimit(who, 'Lead (Pb)')?.max, 0.01);
      expect(findLimit(who, 'Unobtainium'), isNull);
    });
    test('unit conversion', () {
      expect(convertUnit(24, 'µg/L', 'mg/L'), closeTo(0.024, 1e-12));
      expect(convertUnit(0.5, 'ppm', 'mg/L'), 0.5);
      expect(convertUnit(1, 'mg/L', 'mg/kg'), isNull);
    });
    test('compliance checks', () {
      Result r(String p, double? v, String u, {bool lod = false}) => Result(id: 'x', parameter: p, value: v, unit: u, belowLod: lod);
      expect(checkResult(r('Lead (Pb)', 24, 'µg/L'), who).status, Compliance.exceed);
      expect(checkResult(r('Lead (Pb)', 24, 'µg/L'), who).factor, closeTo(2.4, 1e-9));
      expect(checkResult(r('Iron (Fe)', 0.21, 'mg/L'), who).status, Compliance.pass);
      expect(checkResult(r('pH', 3.9, ''), who).status, Compliance.belowMin);
      expect(checkResult(r('Lead (Pb)', null, 'mg/L', lod: true), who).status, Compliance.belowLod);
      expect(checkResult(r('COD', 50, 'mg/L'), who).status, Compliance.noLimit);
      expect(checkResult(r('Lead (Pb)', 3, 'mg/kg'), who).status, Compliance.unitMismatch);
    });
  });

  test('sample JSON round trip', () {
    final s = Sample(
      id: 'a',
      code: 'LAB-2026-0001',
      site: 'Stream',
      matrix: Matrix.groundwater,
      lat: 6.3,
      lon: -10.8,
      custody: [Custody(time: DateTime(2026, 10, 1), from: 'A', to: 'Lab', condition: '4 °C')],
      results: [Result(id: 'r', parameter: 'Lead (Pb)', value: 0.02, method: 'AAS')],
    );
    final back = Sample.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.code, s.code);
    expect(back.matrix, Matrix.groundwater);
    expect(back.custody.single.to, 'Lab');
    expect(back.results.single.value, 0.02);
    final run = CalibrationRun(id: 'c', parameter: 'Pb', standards: [
      [0, 0],
      [1, 0.04],
    ], readings: [CalReading(sampleId: 'a', response: 0.02, dilution: 5)]);
    final rb = CalibrationRun.fromJson(jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>);
    expect(rb.standards[1][1], 0.04);
    expect(rb.readings.single.dilution, 5);
  });

  group('UTM 29N (vs pyproj EPSG:32629)', () {
    test('forward', () {
      final u = toUtm(7.5427192, -8.6069047, zone: 29);
      expect(u.easting, closeTo(543366.0119, 0.01));
      expect(u.northing, closeTo(833764.8269, 0.01));
      expect(u.zoneLabel, '29N');
    });
    test('inverse', () {
      final (lat, lon) = fromUtm(537569, 837710);
      expect(lat, closeTo(7.578449648, 1e-7));
      expect(lon, closeTo(-8.659423609, 1e-7));
    });
    test('decimal degrees typed in UTM columns are recognised', () {
      final p = parseCoordinatePair(7.543189, -8.608411)!;
      expect(p.$1, closeTo(7.543189, 1e-9));
      expect(p.$2, closeTo(-8.608411, 1e-9));
    });
  });

  group('Field report conventions', () {
    test('parameter aliases find Liberian limits', () {
      final lr = liberiaWater();
      expect(findLimit(lr, 'Conductivity (µS/cm)')!.max, 150);
      expect(findLimit(lr, 'Iron (mg/L)')!.max, 2.0);
      expect(findLimit(lr, 'Aluminum (ppm)')!.max, 0.75);
      expect(findLimit(lr, 'TSS')!.max, 50);
      expect(findLimit(lr, 'Hardness')!.max, 200);
      expect(findLimit(lr, 'Nitrate')!.max, 50);
      expect(findLimit(lr, 'Bi')!.max, 0.7);
      expect(findLimit(lr, 'Strontium (ppm)'), isNull);
    });
    test('result text parsing', () {
      final nd = parseResultText('<0.001');
      expect(nd.belowLod, isTrue);
      expect(nd.lod, 0.001);
      final tri = parseResultText('2.05 2.08 2.08');
      expect(tri.value, closeTo(2.07, 1e-12));
      expect(tri.replicates.length, 3);
      expect(parseResultText('6.47').value, 6.47);
      expect(parseResultText('').isEmpty, isTrue);
    });
    test('sample codes', () {
      expect(buildSampleCode('kr', Matrix.surfaceWater, 4, control: true), 'KR-C-SW-004');
      expect(buildSampleCode('BT', Matrix.groundwater, 9), 'BT-GW-009');
      expect(codeSeq('YC-G-SW-008'), 8);
      expect(codeLooksControl('GR-C-SL-001'), isTrue);
      expect(codeLooksControl('YC-SW-005'), isFalse);
    });
    test('°F to °C', () => expect(fahrenheitToCelsius(71.6), closeTo(22.0, 1e-9)));
  });

  group('Investigation analysis', () {
    Sample mk(String code, bool ctrl, Map<String, double> v, {Matrix m = Matrix.surfaceWater}) => Sample(
          id: code,
          code: code,
          matrix: m,
          isControl: ctrl,
          results: [for (final e in v.entries) Result(id: '$code${e.key}', parameter: e.key, value: e.value, unit: e.key == 'pH' ? '' : (m.isSolid ? 'mg/kg' : 'mg/L'))],
        );
    final lr = liberiaWater();

    test('exceedance everywhere except control is reported', () {
      final samples = [
        mk('KR-SW-001', false, {'Iron (Fe)': 2.77, 'pH': 6.47, 'Nitrate (as NO3)': 14}),
        mk('KR-SW-002', false, {'Iron (Fe)': 2.20, 'pH': 8.13, 'Nitrate (as NO3)': 37}),
        mk('KR-C-SW-004', true, {'Iron (Fe)': 0.08, 'pH': 7.19, 'Nitrate (as NO3)': 25}),
      ];
      final g = buildInvestigation(samples, (_) => lr).single;
      expect(g.samples.first.code, 'KR-C-SW-004');
      final f = writeFindings(g).join('\n');
      expect(f, contains('Iron (Fe) exceeded the ≤ 2 mg/L limit at every sampling point except the control (KR-C-SW-004)'));
      expect(f, contains('pH was below the 6.5–8.5 range at KR-SW-001 (6.47)'));
      expect(f, contains('Complied at all points: Nitrate (as NO3)'));
      expect(g.factor(samples[0], 'Iron (Fe)'), closeTo(2.77 / 0.08, 1e-9));
      expect(g.factor(samples[0], 'pH'), isNull);
    });

    test('contamination factor and pollution load index', () {
      final samples = [
        mk('GR-C-SL-001', true, {'Iron (Fe)': 0.5, 'Zinc (Zn)': 1.0}, m: Matrix.soil),
        mk('GR-SL-001', false, {'Iron (Fe)': 4.0, 'Zinc (Zn)': 2.0}, m: Matrix.soil),
      ];
      final g = buildInvestigation(samples, (_) => lr).single;
      expect(g.solid, isTrue);
      expect(g.factor(samples[1], 'Iron (Fe)'), closeTo(8, 1e-12));
      expect(g.pli(samples[1]), closeTo(4, 1e-12)); // sqrt(8 × 2)
      expect(cfClass(8), 'Very high');
      expect(cfClass(2), 'Moderate');
      expect(writeFindings(g).join('\n'), contains('PLI 4.00'));
    });
  });
}
