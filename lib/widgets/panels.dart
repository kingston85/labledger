// Desktop-aware navigation helpers.
//
// On a PC (wide window) forms open as a side panel that slides in from the
// right over a dimmed workspace, and pickers open as centred dialogs, so the
// sidebar and the list you came from stay visible. On a phone the same calls
// open full-screen pages and bottom sheets.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

bool wideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// Opens a detail page. On wide screens it opens inside the workspace (the
/// sidebar stays) and is centred with a comfortable reading width.
Future<T?> openPage<T>(BuildContext context, Widget page, {double maxWidth = 1180}) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (ctx) => wideLayout(ctx) ? _Centered(maxWidth: maxWidth, child: page) : page));
}

/// Replaces the current page (same rules as [openPage]).
Future<T?> replacePage<T>(BuildContext context, Widget page, {double maxWidth = 1180}) {
  return Navigator.of(context).pushReplacement<T, Object?>(MaterialPageRoute(builder: (ctx) => wideLayout(ctx) ? _Centered(maxWidth: maxWidth, child: page) : page));
}

class _Centered extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const _Centered({required this.maxWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return ColoredBox(
      color: c.bg,
      child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child)),
    );
  }
}

/// Opens a form. Wide screens: a side panel from the right. Phones: a page.
Future<T?> openForm<T>(BuildContext context, Widget form, {double width = 640}) {
  if (!wideLayout(context)) return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => form));
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) {
      final size = MediaQuery.sizeOf(ctx);
      final w = width.clamp(360.0, size.width * 0.92).toDouble();
      final c = ctx.lb;
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: w,
          height: size.height,
          decoration: BoxDecoration(
            color: c.bg,
            border: Border(left: BorderSide(color: c.line)),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(-6, 0))],
          ),
          child: ClipRect(child: form),
        ),
      );
    },
    transitionBuilder: (ctx, a, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

/// Bottom sheet on phones, centred dialog on wide screens. Drop-in for
/// showModalBottomSheet.
Future<T?> showSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  double maxWidth = 600,
}) {
  if (!wideLayout(context)) {
    return showModalBottomSheet<T>(context: context, isScrollControlled: isScrollControlled, showDragHandle: showDragHandle, builder: builder);
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: h * 0.88),
          child: Padding(padding: const EdgeInsets.only(top: 18), child: builder(ctx)),
        ),
      );
    },
  );
}

/// A titled group of form fields, drawn as a card.
class FormSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? trailing;
  const FormSection(this.title, {super.key, this.icon, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 17, color: c.accent), const SizedBox(width: 8)],
            Expanded(child: Text(title.toUpperCase(), style: LBText.label(c.inkDim, size: 10.5))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}

/// Lays children out two-up on wide forms and stacked on phones.
class FieldRow extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  const FieldRow(this.children, {super.key, this.gap = 10});

  @override
  Widget build(BuildContext context) {
    // MediaQuery rather than LayoutBuilder, so it also works inside dialogs
    // (which measure their content's intrinsic size).
    if (MediaQuery.sizeOf(context).width < 480) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 10), child: w),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ]),
    );
  }
}

/// Coloured KPI tile used on module headers.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? sub;
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.color, this.sub});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final col = color ?? c.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: col, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: LBText.body(c.inkDim, size: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(value, style: LBText.reading(19, c.ink, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub!, style: LBText.body(c.inkDim, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

/// Responsive grid of [StatTile]s.
class StatRow extends StatelessWidget {
  final List<Widget> tiles;
  const StatRow(this.tiles, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 560 ? 3 : 2);
      final w = (box.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }
}

/// Save / cancel bar pinned to the bottom of a form.
class FormActions extends StatelessWidget {
  final VoidCallback? onSave;
  final String saveLabel;
  final VoidCallback? onDelete;
  final List<Widget> extra;
  const FormActions({super.key, required this.onSave, this.saveLabel = 'Save', this.onDelete, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (onDelete != null) IconButton(tooltip: 'Delete', onPressed: onDelete, icon: Icon(Icons.delete_outline_rounded, color: c.poor)),
          ...extra,
          const Spacer(),
          TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.check_rounded, size: 18), label: Text(saveLabel)),
        ]),
      ),
    );
  }
}

/// Date button used in forms.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = true});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    String two(int n) => n.toString().padLeft(2, '0');
    final text = value == null ? 'Not set' : '${two(value!.day)}/${two(value!.month)}/${value!.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: clearable && value != null
              ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => onChanged(null))
              : Icon(Icons.event_rounded, size: 18, color: c.inkDim),
        ),
        child: Text(text, style: LBText.body(value == null ? c.inkDim : c.ink)),
      ),
    );
  }
}
