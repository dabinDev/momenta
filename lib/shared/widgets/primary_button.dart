import 'package:flutter/material.dart';

import '../../app/theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  }) : _outlined = false;

  const PrimaryButton.outline({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  }) : _outlined = true;

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool _outlined;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final BorderRadius borderRadius = BorderRadius.circular(18);
    final Color foreground = _outlined
        ? (enabled ? AppTheme.primaryDeep : AppTheme.muted)
        : Colors.white;
    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20, color: foreground),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (_outlined) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              AppTheme.surfaceSky,
              AppTheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius,
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.sky.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: child,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            AppTheme.primary,
            AppTheme.coral,
            AppTheme.amber,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: borderRadius,
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: AppTheme.primaryDeep.withValues(alpha: 0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: child,
      ),
    );
  }
}
