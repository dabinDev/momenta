import 'package:flutter/material.dart';

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
    final ThemeData theme = Theme.of(context);
    final Color iconColor =
        _outlined ? theme.colorScheme.primary : Colors.white;
    final Color iconBackground = _outlined
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.16);

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: iconColor),
        ),
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
      return OutlinedButton(
        onPressed: onPressed,
        child: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}
