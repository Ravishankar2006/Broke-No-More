import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../models/quest.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/quest_card.dart';

/// Every finished quest (completed, expired or failed) — the Quests screen
/// itself only ever showed the 5 most recent, with no way to reach anything
/// older than that.
class QuestHistoryScreen extends StatelessWidget {
  const QuestHistoryScreen({super.key, required this.quests});

  /// Pre-sorted, most recent first — the caller already has this from the
  /// same list the Quests screen's own preview slices.
  final List<Quest> quests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quest history')),
      body: quests.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'Nothing finished yet',
              message: 'Completed, expired and failed quests show up here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.xxxl,
              ),
              itemCount: quests.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: QuestCard(quest: quests[index]),
              ),
            ),
    );
  }
}
