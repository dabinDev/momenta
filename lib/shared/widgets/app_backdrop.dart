import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
    this.primaryTint = AppTheme.primary,
    this.secondaryTint = AppTheme.sky,
    this.tertiaryTint = AppTheme.jade,
  });

  final Widget child;
  final Color primaryTint;
  final Color secondaryTint;
  final Color tertiaryTint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppTheme.warmBackground,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -68,
            right: -38,
            child: _GlowOrb(
              size: 210,
              color: primaryTint.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: 180,
            left: -54,
            child: _GlowOrb(
              size: 148,
              color: secondaryTint.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -54,
            right: 28,
            child: _GlowOrb(
              size: 160,
              color: tertiaryTint.withValues(alpha: 0.10),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color,
              blurRadius: 70,
              spreadRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

