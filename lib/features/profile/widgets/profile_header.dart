import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/xp_engine.dart';
import '../../../models/user_profile.dart';
import '../../../shared_widgets/app_avatar.dart';
import '../../../shared_widgets/app_card.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.profile,
    required this.progress,
  });

  final UserProfile profile;
  final LevelProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return AppCard.hero(
      gradient: AppGradients.brand(theme.brightness),
      child: Row(
        children: [
          AppAvatar(emoji: profile.avatarId, size: MedallionSize.profileAvatar),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: semantics.xp,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Level ${progress.level}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantics.onGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Since ${_monthYear(profile.joinDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
