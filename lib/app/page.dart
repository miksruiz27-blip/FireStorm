import 'package:flutter/material.dart';

import 'theme.dart';

/// Scrollable page content: responsive side padding, 1288px max width, vertical rhythm.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.gap = 32});
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 40.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(side, 36, side, 56),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1288),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Step label, Michroma title, livery sweep, description; [trailing] sits bottom-right (wraps below on narrow).
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.step,
    required this.title,
    this.description,
    this.trailing,
  });
  final String step, title;
  final InlineSpan? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.end,
    spacing: 24,
    runSpacing: 24,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            Text(step, style: AppText.label),
            Text(
              title,
              style: AppText.display.copyWith(fontSize: 30, letterSpacing: 4.2),
            ),
            const LiverySweep(width: 200),
            if (description != null)
              Text.rich(
                description!,
                style: AppText.body.copyWith(color: AppColors.secondary),
              ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}
