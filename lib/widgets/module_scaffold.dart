import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard page for a numerical-methods module: title, a theory button
/// and a scrolling body.
class ModuleScaffold extends StatelessWidget {
  final String title;
  final String theory;
  final List<Widget> children;
  final List<Widget> actions;
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.theory,
    required this.children,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          IconButton(
            tooltip: 'Theory',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => showTheory(context, title, theory),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
          children: children,
        ),
      ),
    );
  }
}

void showTheory(BuildContext context, String title, String text) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final c = context.lb;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
          children: [
            Text(title, style: LBText.title(c.ink)),
            const SizedBox(height: 14),
            Text(text, style: LBText.body(c.ink, size: 14.5)),
          ],
        ),
      );
    },
  );
}
