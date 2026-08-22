import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quest_repository.dart';
import '../models/quest.dart';
import 'profile_provider.dart';
import 'transaction_provider.dart';

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepository();
});

class QuestsNotifier extends Notifier<List<Quest>> {
  @override
  List<Quest> build() {
    return ref.watch(questRepositoryProvider).getAll();
  }

  void refresh() {
    state = ref.read(questRepositoryProvider).getAll();
  }

  Future<void> accept(QuestCandidate candidate) async {
    await ref.read(questRepositoryProvider).accept(candidate);
    refresh();
  }
}

final questsProvider =
    NotifierProvider<QuestsNotifier, List<Quest>>(QuestsNotifier.new);

final activeQuestsProvider = Provider<List<Quest>>((ref) {
  return ref
      .watch(questsProvider)
      .where((q) => q.status == QuestStatus.active)
      .toList();
});

/// Rule-engine candidates for the user to accept/skip, derived from all
/// logged transactions (PRD section 7). Also watches questsProvider so
/// accepting a candidate immediately excludes it from future suggestions.
final questCandidatesProvider = Provider<List<QuestCandidate>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final currentStreak = ref.watch(profileProvider)?.currentStreak ?? 0;
  ref.watch(questsProvider);
  return ref
      .watch(questRepositoryProvider)
      .generateCandidates(transactions, currentStreak: currentStreak);
});
