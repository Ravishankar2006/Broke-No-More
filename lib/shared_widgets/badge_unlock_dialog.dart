import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/badge_engine.dart';
import '../core/utils/badge_icons.dart';
import 'celebration_effects.dart';

Future<void> showBadgeUnlockDialog(
  BuildContext context,
  List<BadgeDefinition> badges,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => CelebrationBurst(
      child: AlertDialog(
        title: const Text('Badge unlocked!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final badge in badges)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    BounceIn(
                      child: CircleAvatar(
                        backgroundColor: AppColors.xp.withValues(alpha: 0.15),
                        child: Icon(
                          badgeIcon(badge.iconId),
                          color: AppColors.xp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
    ),
  );
}
