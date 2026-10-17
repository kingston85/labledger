# LabLedger — project status

Flutter 3.24.5; plugins: geolocator (android pinned 4.6.1), path_provider,
share_plus 10, pdf. Same CI pipeline as TerraPlot/NumeriLab (CI reports
analyzer, test and Gradle errors as annotations).

## Version 0.1
- Data: samples, results, custody, limit sets, calibration runs + readings,
  QC checks, control charts; JSON on device, demo data on first launch.
- Core: stats.dart (t, F, incomplete beta, Welch, ANOVA, Grubbs, Westgard),
  calibration.dart (LOD/LOQ via sy/x), guidelines.dart (WHO GDWQ values,
  matching, unit conversion, compliance), report.dart (PDF, CSV).
- Tests: p-values checked against scipy.stats.

## Ideas next
- Batch/worklist view, instrument CSV import, sample labels with QR codes
- Detection-limit studies (MDL), uncertainty budgets, method validation report
- Multi-user sync (shared folder) for the lab team
