import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
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
  void initState() {
    super.initState();
    // Also check on screen open, not just app startup, so a quest that
    // expires mid-session doesn't linger as "active" until next launch.
    Future.microtask(() async {
      await ref.read(questRepositoryProvider).expireOverdueQuests();
      if (mounted) ref.read(questsProvider.notifier).refresh();
    });
  }

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
        padding: EdgeInsets.all(Spacing.lg),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: StreakCalendar(transactions: transactions),
            ),
          ),
          SizedBox(height: Spacing.xl),
          Text('Badges',
              style: Theme.of(context).textTheme.titleMedium!
                  .copyWith(color: Theme.of(context).colorScheme.primary)),
          SizedBox(height: Spacing.sm),
          BadgeShelf(unlockedBadges: unlockedBadges),
          SizedBox(height: Spacing.xl),
          if (activeQuests.isNotEmpty) ...[
            Text('Active',
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(color: Theme.of(context).colorScheme.primary)),
            SizedBox(height: Spacing.sm),
            ...activeQuests.map((q) => Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: QuestCard(quest: q),
                )),
            SizedBox(height: Spacing.xl),
          ],
          if (candidates.isNotEmpty) ...[
            Text('Suggested for you',
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(color: Theme.of(context).colorScheme.primary)),
            SizedBox(height: Spacing.sm),
            ...candidates.map((c) => Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: QuestCandidateCard(
                    candidate: c,
                    onAccept: () => ref.read(questsProvider.notifier).accept(c),
                    onSkip: () => setState(() => _skippedTitles.add(c.title)),
                  ),
                )),
          ],
          if (activeQuests.isEmpty && candidates.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: Spacing.xxxl),
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
