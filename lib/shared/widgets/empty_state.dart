import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2D8),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 46,
                color: Color(0xFF6E7E78),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
