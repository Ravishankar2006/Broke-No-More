import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/date_helpers.dart';
import '../data/quest_repository.dart';
import '../models/quest.dart';
import 'animated_progress_bar.dart';
import 'app_card.dart';

/// Iconography per quest type. The model has carried a [QuestType] since the
/// beginning and the UI never showed it, so every quest looked the same.
IconData questTypeIcon(QuestType type) => switch (type) {
  QuestType.streak => Icons.local_fire_department,
  QuestType.categoryAvoid => Icons.block,
  QuestType.budgetLimit => Icons.savings_outlined,
  QuestType.count => Icons.checklist_rtl,
};

String questTypeLabel(QuestType type) => switch (type) {
  QuestType.streak => 'Streak',
  QuestType.categoryAvoid => 'Avoid',
  QuestType.budgetLimit => 'Budget',
  QuestType.count => 'Logging',
};

/// Renders an already-accepted [Quest] with its progress.
class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final cs = theme.colorScheme;

    final fraction = quest.targetValue == 0
        ? 0.0
        : quest.currentProgress / quest.targetValue;

    final isDone = quest.status == QuestStatus.completed;
    final isFailed = quest.status == QuestStatus.failed;
    final isExpired = quest.status == QuestStatus.expired;
    final isOver = isDone || isFailed || isExpired;

    final accent = switch (quest.status) {
      QuestStatus.completed => semantics.income,
      QuestStatus.failed => semantics.expense,
      QuestStatus.expired => cs.onSurfaceVariant,
      QuestStatus.active => cs.primary,
    };

    return Opacity(
      // Finished quests recede rather than disappear — they're still a record.
      opacity: isExpired ? 0.6 : 1,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: MedallionSize.iconChip,
                  height: MedallionSize.iconChip,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_rounded
                        : isFailed
                        ? Icons.close_rounded
                        : questTypeIcon(quest.type),
                    size: IconSize.md,
                    color: accent,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          decoration: isFailed || isExpired
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        _statusLine(quest),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isOver ? accent : cs.onSurfaceVariant,
                          fontWeight: isOver ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
                _XpReward(xp: quest.xpReward, earned: isDone),
              ],
            ),
            if (!isOver) ...[
              const SizedBox(height: Spacing.md),
              AnimatedProgressBar(
                value: fraction,
                variant: ProgressVariant.quest,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                '${quest.currentProgress} / ${quest.targetValue}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Quest type plus time remaining. `endDate` existed on the model from the
  /// start and was never surfaced, so an expiring quest gave no warning.
  static String _statusLine(Quest quest) {
    final type = questTypeLabel(quest.type);
    switch (quest.status) {
      case QuestStatus.completed:
        return '$type · Completed';
      case QuestStatus.failed:
        return '$type · Failed';
      case QuestStatus.expired:
        return '$type · Expired';
      case QuestStatus.active:
        final left = daysBetween(DateTime.now(), quest.endDate);
        if (left < 0) return '$type · Ending';
        if (left == 0) return '$type · Ends today';
        if (left == 1) return '$type · 1 day left';
        return '$type · $left days left';
    }
  }
}

class _XpReward extends StatelessWidget {
  const _XpReward({required this.xp, required this.earned});

  final int xp;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: earned ? semantics.xp : semantics.goldSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '+$xp XP',
        style: theme.textTheme.labelSmall?.copyWith(
          color: earned ? semantics.onGold : semantics.goldInk,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Renders a not-yet-accepted [QuestCandidate] with accept/skip actions.
class QuestCandidateCard extends StatelessWidget {
  const QuestCandidateCard({
    super.key,
    required this.candidate,
    required this.onAccept,
    required this.onSkip,
    required this.onCustomize,
  });

  final QuestCandidate candidate;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  /// PRD §4/§7's third quest response — adjust target and duration before
  /// accepting, rather than take-it-or-leave-it.
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppCard(
      // Dashed-feeling tint separates "on offer" from "accepted" at a glance,
      // rather than relying on the buttons alone.
      color: cs.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: MedallionSize.iconChip,
                height: MedallionSize.iconChip,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  questTypeIcon(candidate.type),
                  size: IconSize.md,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      'Suggested · ${questTypeLabel(candidate.type)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _XpReward(xp: candidate.xpReward, earned: false),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              IconButton(
                onPressed: onCustomize,
                tooltip: 'Customize before accepting',
                icon: const Icon(Icons.tune_rounded),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
