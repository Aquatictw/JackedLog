import 'package:flutter/material.dart';

class RepsButton extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;

  const RepsButton({
    super.key,
    required this.icon,
    required this.accentColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 32,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed != null
              ? accentColor
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
