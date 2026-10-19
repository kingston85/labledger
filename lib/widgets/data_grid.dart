import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GridColumn<T> {
  final String label;
  final double flex;
  final double? width;
  final Widget Function(T row) cell;
  final Comparable Function(T row)? sortKey;
  final bool numeric;
  const GridColumn(this.label, {required this.cell, this.flex = 1, this.width, this.sortKey, this.numeric = false});
}

/// Desktop-style data table: sticky header, click-to-sort, zebra rows,
/// hover highlight and paging. Scrolls sideways when narrower than [minWidth].
class DataGrid<T> extends StatefulWidget {
  final List<GridColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onTap;
  final double minWidth;
  final int pageSize;
  final int? initialSort;
  final bool initialAscending;
  final String empty;
  const DataGrid({
    super.key,
    required this.columns,
    required this.rows,
    this.onTap,
    this.minWidth = 760,
    this.pageSize = 50,
    this.initialSort,
    this.initialAscending = true,
    this.empty = 'Nothing to show',
  });

  @override
  State<DataGrid<T>> createState() => _DataGridState<T>();
}

class _DataGridState<T> extends State<DataGrid<T>> {
  int? _sort;
  bool _asc = true;
  int _page = 0;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort;
    _asc = widget.initialAscending;
  }

  @override
  void didUpdateWidget(DataGrid<T> old) {
    super.didUpdateWidget(old);
    if (old.rows.length != widget.rows.length) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final rows = [...widget.rows];
    final sc = _sort == null ? null : widget.columns[_sort!];
    if (sc?.sortKey != null) {
      rows.sort((a, b) {
        final r = sc!.sortKey!(a).compareTo(sc.sortKey!(b));
        return _asc ? r : -r;
      });
    }
    final pages = (rows.length / widget.pageSize).ceil();
    final page = _page.clamp(0, pages == 0 ? 0 : pages - 1).toInt();
    final view = rows.skip(page * widget.pageSize).take(widget.pageSize).toList();

    Widget cellBox(GridColumn<T> col, Widget child) {
      final w = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft, child: child),
      );
      return col.width != null ? SizedBox(width: col.width, child: w) : Expanded(flex: (col.flex * 10).round(), child: w);
    }

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 42,
          decoration: BoxDecoration(color: c.surface2, border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            for (var i = 0; i < widget.columns.length; i++)
              cellBox(
                widget.columns[i],
                InkWell(
                  onTap: widget.columns[i].sortKey == null
                      ? null
                      : () => setState(() {
                            if (_sort == i) {
                              _asc = !_asc;
                            } else {
                              _sort = i;
                              _asc = true;
                            }
                          }),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(widget.columns[i].label.toUpperCase(), overflow: TextOverflow.ellipsis, style: LBText.label(_sort == i ? c.accent : c.inkDim, size: 10))),
                    if (_sort == i) Icon(_asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: c.accent),
                  ]),
                ),
              ),
          ]),
        ),
        if (view.isEmpty)
          Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(widget.empty, style: LBText.body(c.inkDim)))),
        for (var r = 0; r < view.length; r++)
          MouseRegion(
            onEnter: (_) => setState(() => _hover = r),
            onExit: (_) => setState(() => _hover = null),
            cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap == null ? null : () => widget.onTap!(view[r]),
              child: Container(
                constraints: const BoxConstraints(minHeight: 46),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _hover == r ? c.accent.withOpacity(0.08) : (r.isOdd ? c.surface2.withOpacity(0.35) : null),
                  border: Border(bottom: BorderSide(color: c.line.withOpacity(0.6), width: 0.6)),
                ),
                child: Row(children: [for (final col in widget.columns) cellBox(col, col.cell(view[r]))]),
              ),
            ),
          ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              Text('${page * widget.pageSize + 1}–${page * widget.pageSize + view.length} of ${rows.length}', style: LBText.body(c.inkDim, size: 12)),
              const Spacer(),
              IconButton(onPressed: page > 0 ? () => setState(() => _page = page - 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
              Text('${page + 1} / $pages', style: LBText.reading(12, c.ink)),
              IconButton(onPressed: page < pages - 1 ? () => setState(() => _page = page + 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
            ]),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= widget.minWidth) return table;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(width: widget.minWidth, child: table));
      }),
    );
  }
}

/// Text in a grid cell.
Widget gridText(BuildContext context, String t, {bool bold = false, bool mono = false, Color? color, double size = 13}) {
  final c = context.lb;
  return Text(
    t,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: mono
        ? LBText.reading(size - 0.5, color ?? c.ink, weight: bold ? FontWeight.w700 : FontWeight.w500)
        : LBText.body(color ?? c.ink, size: size, weight: bold ? FontWeight.w700 : FontWeight.w400),
  );
}

/// True on desktop/tablet widths.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;
