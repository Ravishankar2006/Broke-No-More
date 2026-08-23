import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/xp_engine.dart';
import 'celebration_effects.dart';

/// The app's biggest reward moment.
///
/// Keeps the confetti and the elastic bounce, and adds a Lottie ring burst
/// behind the level medallion plus a teaser for the next level, so the dialog
/// points forward instead of dead-ending.
Future<void> showLevelUpDialog(BuildContext context, int newLevel) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final semantics = context.semantics;
      // What the *next* level will cost, to give the moment somewhere to go.
      final nextLevelXp = xpForLevel(newLevel) - xpForLevel(newLevel - 1);

      return CelebrationBurst(
        child: AlertDialog(
          contentPadding: EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xxl,
            Spacing.xl,
            Spacing.lg,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CelebrationAnimation(
                      asset: CelebrationAssets.levelUp,
                      fallbackIcon: Icons.bolt,
                      size: 148,
                    ),
                    BounceIn(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.xp(theme.brightness),
                          boxShadow: AppShadows.gold(theme.brightness),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$newLevel',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: semantics.onGold,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.lg),
              Text('Level up!', style: theme.textTheme.headlineSmall),
              SizedBox(height: Spacing.xs),
              Text(
                "You're now level $newLevel",
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: Spacing.md),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: semantics.goldSurface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$nextLevelXp XP to level ${newLevel + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantics.goldInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep going'),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      );
    },
  );
}
