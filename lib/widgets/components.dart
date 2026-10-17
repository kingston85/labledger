import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Frosted panel that floats over the map.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.glass,
            borderRadius: radius,
            border: Border.all(color: c.line.withOpacity(0.8)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Instrument-panel label: small capitals with letter spacing.
class PanelLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const PanelLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: LBText.label(color ?? context.lb.inkDim, size: 10.5));
}

/// A labelled reading: LABEL over a monospaced value.
class Reading extends StatelessWidget {
  final String label;
  final String value;
  final double size;
  final Color? color;
  final CrossAxisAlignment align;
  const Reading({
    super.key,
    required this.label,
    required this.value,
    this.size = 15,
    this.color,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelLabel(label),
        const SizedBox(height: 4),
        Text(value,
            style: LBText.reading(size, color ?? c.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// A number that rolls smoothly to its new value.
class RollingNumber extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;
  const RollingNumber({super.key, required this.value, required this.format, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Round icon button used over the map.
class GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool active;
  const GlassButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Tooltip(
      message: tooltip,
      child: Glass(
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: active ? c.accent : c.ink, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading used on list screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(child: PanelLabel(title)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Card with the app's border and radius.
class LBCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  const LBCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor ?? c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Small rounded tag.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Tag(this.text, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontFamily: LBText.sans,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

/// Friendly empty state.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: c.accent, size: 34),
          ),
          const SizedBox(height: 18),
          Text(title, style: LBText.title(c.ink, size: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: LBText.body(c.inkDim), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// "Coming in phase N" notice for features not built yet.
void showComingSoon(BuildContext context, String feature, String when) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature arrives in $when.')));
}
