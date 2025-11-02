import 'package:flutter/material.dart';

class EmptyStateIndicator extends StatelessWidget {
  const EmptyStateIndicator({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 80,
    this.iconColor,
    this.padding = const EdgeInsets.all(32.0),
  });

  final IconData icon;

  final String title;

  final String? subtitle;

  final double iconSize;

  final Color? iconColor;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: iconColor ?? colorScheme.secondary.withOpacity(0.7),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
