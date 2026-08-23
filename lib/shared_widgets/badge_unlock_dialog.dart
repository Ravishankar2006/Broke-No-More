import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/badge_icons.dart';
import 'celebration_effects.dart';

/// Celebrates one or more newly-unlocked badges.
///
/// Medallions are 56px here to match the shelf's treatment — the previous
/// version used a default 40px [CircleAvatar], so the badge the user was being
/// congratulated for looked smaller than the same badge sitting on the shelf.
/// Multiple unlocks now reveal in sequence rather than all bouncing at once.
///
/// [totalUnlocked] is the user's full badge count; pass it to show the
/// "N of M earned" line, omit it to hide that line entirely.
Future<void> showBadgeUnlockDialog(
  BuildContext context,
  List<BadgeDefinition> badges, {
  int? totalUnlocked,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final semantics = context.semantics;
      final multiple = badges.length > 1;

      return CelebrationBurst(
        child: AlertDialog(
          contentPadding: EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
            Spacing.lg,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CelebrationAnimation(
                asset: CelebrationAssets.badgeUnlock,
                fallbackIcon: Icons.workspace_premium,
                size: 96,
              ),
              SizedBox(height: Spacing.sm),
              Text(
                multiple ? '${badges.length} badges unlocked!' : 'Badge unlocked!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Spacing.lg),
              for (var i = 0; i < badges.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == badges.length - 1 ? 0 : Spacing.lg,
                  ),
                  child: Row(
                    children: [
                      BounceIn(
                        // Stagger so several unlocks land one after another.
                        delay: Duration(milliseconds: 120 * i),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppGradients.xp(theme.brightness),
                            boxShadow: AppShadows.gold(theme.brightness),
                          ),
                          child: Icon(
                            badgeIcon(badges[i].iconId),
                            color: semantics.onGold,
                            size: 28,
                          ),
                        ),
                      ),
                      SizedBox(width: Spacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badges[i].name,
                              style: theme.textTheme.titleSmall,
                            ),
                            SizedBox(height: Spacing.xxs),
                            Text(
                              badges[i].description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Only shown when the caller supplies the real total — a
              // progress line that guessed would be worse than none.
              if (totalUnlocked != null) ...[
                SizedBox(height: Spacing.lg),
                Text(
                  '$totalUnlocked of ${kBadgeCatalog.length} badges earned',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice!'),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      );
    },
  );
}
