import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import 'celebration_effects.dart';

Future<void> showLevelUpDialog(BuildContext context, int newLevel) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final semantics = context.semantics;
      return CelebrationBurst(
        child: AlertDialog(
          contentPadding:
              EdgeInsets.fromLTRB(Spacing.xl, Spacing.xxl, Spacing.xl, Spacing.lg),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BounceIn(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: semantics.xp.withValues(alpha: 0.16),
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: semantics.xp,
                      ),
                      child: Icon(Icons.bolt, color: semantics.onGold, size: 40),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Spacing.lg),
              Text('Level up!', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: Spacing.xs),
              Text(
                'You\'re now level $newLevel',
                style: Theme.of(context).textTheme.bodyMedium,
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
