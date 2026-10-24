import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ResponsiveActionFab extends StatelessWidget {
  const ResponsiveActionFab({
    required this.heroTag,
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String heroTag;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 480) {
      return FloatingActionButton(
        heroTag: heroTag,
        tooltip: label,
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: Icon(icon),
      );
    }

    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
