import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/badge_icons.dart';
import 'celebration_effects.dart';

Future<void> showBadgeUnlockDialog(
  BuildContext context,
  List<BadgeDefinition> badges,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final semantics = context.semantics;
      return CelebrationBurst(
        child: AlertDialog(
          title: const Text('Badge unlocked!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final badge in badges)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Spacing.sm),
                  child: Row(
                    children: [
                      BounceIn(
                        child: CircleAvatar(
                          backgroundColor: semantics.xp.withValues(alpha: 0.15),
                          child: Icon(
                            badgeIcon(badge.iconId),
                            color: semantics.goldInk,
                          ),
                        ),
                      ),
                      SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badge.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              badge.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice!'),
            ),
          ],
        ),
      );
    },
  );
}
