import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/primary_button.dart';
import 'create_controller.dart';

Future<void> showCreateModeSheet({
  required BuildContext context,
  required CreateController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return _CreateModeSheet(
        controller: controller,
      );
    },
  );
}

class _CreateModeSheet extends StatelessWidget {
  const _CreateModeSheet({
    required this.controller,
  });

  final CreateController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<CreateWorkbenchMode> modes = controller.availableModes;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '切换创作入口',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '简单适合快速生成，入门适合链接跟做，自定义适合模板创作。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            for (final CreateWorkbenchMode mode in modes) ...<Widget>[
              _ModeTile(
                controller: controller,
                mode: mode,
                selected: mode == controller.mode,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.setMode(mode);
                },
              ),
              if (mode != modes.last) const SizedBox(height: 12),
            ],
            const SizedBox(height: 18),
            PrimaryButton.outline(
              label: '暂不切换',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.controller,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CreateController controller;
  final CreateWorkbenchMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tint = mode.tint;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: selected
                ? tint.withValues(alpha: 0.12)
                : AppTheme.surfaceSoft.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? tint.withValues(alpha: 0.32)
                  : AppTheme.outline.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(mode.icon, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.labelForMode(mode),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.subtitleForMode(mode),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? tint : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? tint : AppTheme.outline,
                    width: 1.4,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
