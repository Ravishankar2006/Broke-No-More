import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/quest_provider.dart';
import '../../shared_widgets/quest_card.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
