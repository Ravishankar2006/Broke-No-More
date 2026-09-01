import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/currency_catalog.dart';
import '../data/quest_repository.dart';
import '../data/skipped_quest_repository.dart';
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

final questsProvider = NotifierProvider<QuestsNotifier, List<Quest>>(
  QuestsNotifier.new,
);

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
  final currencySymbol = currencyInfoFor(ref.watch(currentCurrencyCodeProvider))
      .symbol;
  ref.watch(questsProvider);
  return ref
      .watch(questRepositoryProvider)
      .generateCandidates(
        transactions,
        currentStreak: currentStreak,
        currencySymbol: currencySymbol,
      );
});

final skippedQuestRepositoryProvider = Provider<SkippedQuestRepository>((ref) {
  return SkippedQuestRepository();
});

/// Titles the user has dismissed. Persisted, so a skip survives a restart.
class SkippedQuestsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(skippedQuestRepositoryProvider).titles;

  Future<void> skip(String title) async {
    await ref.read(skippedQuestRepositoryProvider).skip(title);
    state = ref.read(skippedQuestRepositoryProvider).titles;
  }

  Future<void> unskip(String title) async {
    await ref.read(skippedQuestRepositoryProvider).unskip(title);
    state = ref.read(skippedQuestRepositoryProvider).titles;
  }
}

final skippedQuestsProvider =
    NotifierProvider<SkippedQuestsNotifier, Set<String>>(
      SkippedQuestsNotifier.new,
    );

/// Candidates with the user's dismissals already filtered out.
final visibleQuestCandidatesProvider = Provider<List<QuestCandidate>>((ref) {
  final skipped = ref.watch(skippedQuestsProvider);
  return ref
      .watch(questCandidatesProvider)
      .where((c) => !skipped.contains(c.title))
      .toList(growable: false);
});
