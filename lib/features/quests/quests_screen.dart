import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/badge_provider.dart';
import '../../providers/quest_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/badge_shelf.dart';
import '../../shared_widgets/quest_card.dart';
import '../../shared_widgets/streak_calendar.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  final Set<String> _skippedTitles = {};

  @override
  Widget build(BuildContext context) {
    final activeQuests = ref.watch(activeQuestsProvider);
    final candidates = ref
        .watch(questCandidatesProvider)
        .where((c) => !_skippedTitles.contains(c.title))
        .toList();
    final transactions = ref.watch(transactionsProvider);
    final unlockedBadges = ref.watch(badgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StreakCalendar(transactions: transactions),
            ),
          ),
          const SizedBox(height: 16),
          Text('Badges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          BadgeShelf(unlockedBadges: unlockedBadges),
          const SizedBox(height: 16),
          if (activeQuests.isNotEmpty) ...[
            Text('Active', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...activeQuests.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestCard(quest: q),
                )),
            const SizedBox(height: 16),
          ],
          if (candidates.isNotEmpty) ...[
            Text('Suggested for you',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...candidates.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuestCandidateCard(
                    candidate: c,
                    onAccept: () => ref.read(questsProvider.notifier).accept(c),
                    onSkip: () => setState(() => _skippedTitles.add(c.title)),
                  ),
                )),
          ],
          if (activeQuests.isEmpty && candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'Keep logging transactions — quest suggestions show up once '
                  'there\'s enough history to compare against.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
