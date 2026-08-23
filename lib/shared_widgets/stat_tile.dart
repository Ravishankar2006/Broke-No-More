import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';

/// A compact label/value pair for stat strips.
///
/// The Profile screen surfaced only level and badge count, and Insights showed
/// week-over-week as two bare columns. This gives both a consistent unit, with
/// the value dominant and the label receding.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.caption,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  /// Optional third line — a delta, a comparison, a qualifier.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: cs.onSurfaceVariant),
              SizedBox(width: Spacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        SizedBox(height: Spacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(color: valueColor),
        ),
        if (caption != null) ...[
          SizedBox(height: Spacing.xxs),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
