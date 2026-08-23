import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';

/// A designed empty state.
///
/// The app previously had exactly two, both a single centred sentence of
/// `bodyMedium` with no padding, no icon and no way forward — and the screens
/// that most needed one (Home and Profile on first run) had none at all, so a
/// new user's first impression was three cards of zeros.
///
/// An empty state is the screen at its most instructive moment, so this always
/// offers a next step when one exists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter spacing, for an empty state sitting inside a card rather than
  /// filling a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final iconSize = compact ? 40.0 : 56.0;
    final circleSize = compact ? 76.0 : 104.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: compact ? Spacing.lg : Spacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: semantics.goldSurface,
              ),
              child: Icon(icon, size: iconSize, color: semantics.goldInk),
            ),
            SizedBox(height: compact ? Spacing.lg : Spacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: Spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: Spacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        )
            .animate()
            .fadeIn(duration: AppMotion.slow)
            .slideY(begin: 0.06, end: 0, curve: AppMotion.enter),
      ),
    );
  }
}
