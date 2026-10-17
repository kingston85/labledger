import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/expr.dart';
import '../theme/app_theme.dart';
import 'components.dart';

/// Text field for a mathematical expression with live validation and a
/// row of quick-insert keys (^, (, ), x, sin, …).
class ExprField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final Set<String> vars;
  final ValueChanged<String>? onChanged;
  final List<String> keys;

  const ExprField({
    super.key,
    required this.controller,
    this.label = 'f(x)',
    this.prefix = 'f(x) =',
    this.vars = const {'x'},
    this.onChanged,
    this.keys = const ['x', '^', '(', ')', '*', '/', 'sin(', 'cos(', 'exp(', 'ln(', 'sqrt(', 'pi', 'e', 'tan(', 'abs(', 'log('],
  });

  @override
  State<ExprField> createState() => _ExprFieldState();
}

class _ExprFieldState extends State<ExprField> {
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _validate();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _validate() {
    try {
      Expr.parse(widget.controller.text, vars: widget.vars);
      _error = null;
    } on ExprError catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    }
  }

  void _insert(String s) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, s);
    c.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + s.length));
    HapticFeedback.selectionClick();
    setState(_validate);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    _validate(); // also catches text set by presets
    final ok = _error == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          style: LBText.reading(17, c.ink),
          onChanged: (v) {
            setState(_validate);
            widget.onChanged?.call(v);
          },
          decoration: InputDecoration(
            labelText: widget.label,
            prefixText: '${widget.prefix} ',
            prefixStyle: LBText.reading(15, c.accent, weight: FontWeight.w700),
            suffixIcon: Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: ok ? c.good : c.poor,
              size: 20,
            ),
            errorText: widget.controller.text.isEmpty ? null : _error,
            errorMaxLines: 2,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _focus.hasFocus
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final k in widget.keys)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Material(
                              color: c.surface2,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _insert(k),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Center(
                                    child: Text(k.replaceAll('(', ''),
                                        style: LBText.reading(14, c.ink, weight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Compact number field that also accepts expressions like "pi/2" or "1e-6".
class NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  const NumField({super.key, required this.controller, required this.label, this.suffix, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final v = evalNumber(controller.text);
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: LBText.reading(15, c.ink),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
        errorText: controller.text.isNotEmpty && v == null ? 'Not a number' : null,
      ),
    );
  }
}

double numOf(TextEditingController c, double fallback) => evalNumber(c.text) ?? fallback;

/// Horizontal segmented choice.
class Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.values, required this.selected, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: v == selected ? c.accent : c.line),
                  ),
                  child: Text(
                    label(v),
                    style: TextStyle(
                      fontFamily: LBText.sans,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: v == selected ? c.onAccent : c.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scrollable table with monospaced numbers and an optional copy button.
class ResultTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final int? highlightRow;
  final int maxRows;
  const ResultTable({super.key, required this.columns, required this.rows, this.highlightRow, this.maxRows = 200});

  String get csv => [columns.join(','), for (final r in rows) r.join(',')].join('\n');

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final shown = rows.length > maxRows ? [...rows.take(maxRows ~/ 2), ...rows.skip(rows.length - maxRows ~/ 2)] : rows;
    final skipped = rows.length - shown.length;
    Widget cell(String s, {bool head = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(s,
              style: head ? LBText.label(c.inkDim, size: 10) : LBText.reading(12.5, color ?? c.ink),
              textAlign: TextAlign.right),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: c.surface2),
                  children: [for (final h in columns) cell(h.toUpperCase(), head: true)],
                ),
                for (var i = 0; i < shown.length; i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i == (highlightRow ?? -1) ? c.accent.withOpacity(0.12) : null,
                      border: Border(top: BorderSide(color: c.line.withOpacity(0.5))),
                    ),
                    children: [for (final v in shown[i]) cell(v)],
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            if (skipped > 0)
              Expanded(child: Text('$skipped middle rows hidden', style: LBText.body(c.inkDim, size: 12)))
            else
              const Spacer(),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Table copied as CSV.')));
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy table'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Headline result card.
class ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final bool ok;
  final List<Widget> extra;
  const ResultCard({super.key, required this.label, required this.value, this.sub, this.ok = true, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final color = ok ? c.accent : c.poor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label, color: color),
          const SizedBox(height: 6),
          SelectableText(value, style: LBText.reading(26, c.ink, weight: FontWeight.w700)),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: LBText.body(c.inkDim, size: 13)),
          ],
          ...extra,
        ],
      ),
    );
  }
}

/// Grid of numeric cells for a matrix (and optional right-hand side).
class MatrixEditor extends StatelessWidget {
  final List<List<TextEditingController>> a;
  final List<TextEditingController>? b;
  final VoidCallback onChanged;
  const MatrixEditor({super.key, required this.a, this.b, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final n = a.length;
    final m = n == 0 ? 0 : a[0].length;
    Widget cellField(TextEditingController t, {bool rhs = false}) => SizedBox(
          width: 64,
          child: TextField(
            controller: t,
            onChanged: (_) => onChanged(),
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: LBText.reading(14, rhs ? c.accent : c.ink),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              fillColor: rhs ? c.accent.withOpacity(0.08) : c.surface2,
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < n; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  for (var j = 0; j < m; j++) ...[cellField(a[i][j]), const SizedBox(width: 6)],
                  if (b != null) ...[
                    Container(width: 2, height: 36, color: c.line),
                    const SizedBox(width: 8),
                    cellField(b![i], rhs: true),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// +/- stepper.
class Stepper2 extends StatelessWidget {
  final String label;
  final int value;
  final int min, max;
  final ValueChanged<int> onChanged;
  const Stepper2({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: LBText.body(c.inkDim, size: 13)),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded, size: 18),
        ),
        SizedBox(
          width: 30,
          child: Text('$value', textAlign: TextAlign.center, style: LBText.reading(16, c.ink, weight: FontWeight.w700)),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded, size: 18),
        ),
      ],
    );
  }
}

/// Parses pasted x,y data: one pair per line, separated by spaces, commas, tabs or semicolons.
({List<double> x, List<double> y, int bad}) parseXY(String text) {
  final xs = <double>[], ys = <double>[];
  var bad = 0;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final nums = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?').allMatches(line).map((m) => double.parse(m.group(0)!)).toList();
    if (nums.length < 2) {
      bad++;
      continue;
    }
    xs.add(nums[nums.length - 2]);
    ys.add(nums[nums.length - 1]);
  }
  return (x: xs, y: ys, bad: bad);
}

/// Section with a title above content.
class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const Section(this.title, {super.key, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: PanelLabel(title)), if (trailing != null) trailing!]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Formula/explainer box.
class FormulaBox extends StatelessWidget {
  final String text;
  final String? note;
  const FormulaBox(this.text, {super.key, this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: LBText.reading(13.5, c.ink)),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: LBText.body(c.inkDim, size: 12.5)),
          ],
        ],
      ),
    );
  }
}

/// Example chips that fill inputs with a preset.
class Presets extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<int> onPick;
  const Presets({super.key, required this.labels, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Center(child: Text('Examples  ', style: LBText.label(c.inkDim, size: 10))),
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                label: Text(labels[i], style: LBText.body(c.ink, size: 12.5, weight: FontWeight.w600)),
                onPressed: () => onPick(i),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
