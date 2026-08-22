import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../data/quest_repository.dart';
import '../models/quest.dart';

/// Renders an already-accepted [Quest] with its progress.
class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final fraction =
        quest.targetValue == 0 ? 0.0 : quest.currentProgress / quest.targetValue;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.title, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: Spacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(value: fraction.clamp(0, 1)),
            ),
            SizedBox(height: Spacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${quest.currentProgress} / ${quest.targetValue}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('+${quest.xpReward} XP',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: semantics.goldInk,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ],
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
  });

  final QuestCandidate candidate;
  final VoidCallback onAccept;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.title, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: Spacing.xs),
            Text('+${candidate.xpReward} XP',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: semantics.goldInk,
                      fontWeight: FontWeight.w700,
                    )),
            SizedBox(height: Spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onSkip, child: const Text('Skip')),
                SizedBox(width: Spacing.sm),
                FilledButton(onPressed: onAccept, child: const Text('Accept')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
