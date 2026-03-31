import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = accentColor ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (icon != null)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: accent, size: 22),
                  ),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleLarge),
                      if (subtitle.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 54,
              height: 4,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
