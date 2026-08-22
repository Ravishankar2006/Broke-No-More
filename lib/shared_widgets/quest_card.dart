import 'package:flutter/material.dart';

import '../data/quest_repository.dart';
import '../models/quest.dart';

/// Renders an already-accepted [Quest] with its progress.
class QuestCard extends StatelessWidget {
  const QuestCard({super.key, required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context) {
    final fraction =
        quest.targetValue == 0 ? 0.0 : quest.currentProgress / quest.targetValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quest.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: fraction.clamp(0, 1)),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${quest.currentProgress} / ${quest.targetValue}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('+${quest.xpReward} XP',
                    style: Theme.of(context).textTheme.bodySmall),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(candidate.title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('+${candidate.xpReward} XP',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onSkip, child: const Text('Skip')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onAccept, child: const Text('Accept')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
