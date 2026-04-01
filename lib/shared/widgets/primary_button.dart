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
    final Color foreground =
        _outlined ? theme.colorScheme.onSurface : Colors.white;
    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 19, color: foreground),
        const SizedBox(width: 8),
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
