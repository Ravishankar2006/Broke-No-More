import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_elevation.dart';
import '../core/theme/app_semantic_colors.dart';
import '../models/quest.dart';
import 'celebration_effects.dart';
import 'quest_card.dart' show questTypeIcon;

/// Celebrates one or more quests completed by the mutation that just ran.
///
/// Was entirely missing: `LogTransactionResult.completedQuests` was computed
/// by the orchestrator and returned, but nothing ever read it — a quest could
/// fill its progress bar to 100% and the user would get no acknowledgement
/// at all. Mirrors [showBadgeUnlockDialog]'s multi-item reveal, since one
/// transaction can complete more than one quest at once (e.g. a streak quest
/// and a count quest both crossing their target together).
Future<void> showQuestCompleteDialog(
  BuildContext context,
  List<Quest> quests,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final semantics = context.semantics;
      final multiple = quests.length > 1;
      final totalXp = quests.fold<int>(0, (sum, q) => sum + q.xpReward);

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
              BounceIn(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.xp(theme.brightness),
                    boxShadow: AppShadows.gold(theme.brightness),
                  ),
                  child: Icon(
                    Icons.flag_circle,
                    color: semantics.onGold,
                    size: 36,
                  ),
                ),
              ),
              SizedBox(height: Spacing.sm),
              Text(
                multiple
                    ? '${quests.length} quests completed!'
                    : 'Quest completed!',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Spacing.lg),
              for (var i = 0; i < quests.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == quests.length - 1 ? 0 : Spacing.lg,
                  ),
                  child: Row(
                    children: [
                      BounceIn(
                        // Stagger so several completions land one after another.
                        delay: Duration(milliseconds: 120 * (i + 1)),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: semantics.goldSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            questTypeIcon(quests[i].type),
                            color: semantics.goldInk,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: Spacing.lg),
                      Expanded(
                        child: Text(
                          quests[i].title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '+${quests[i].xpReward} XP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: semantics.goldInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (multiple) ...[
                SizedBox(height: Spacing.lg),
                Text(
                  '+$totalXp XP total',
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
