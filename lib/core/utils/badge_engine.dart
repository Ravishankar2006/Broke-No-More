/// Badge catalog and pure unlock evaluation — no Flutter/Riverpod
/// dependency, same reasoning as xp_engine.dart and quest_engine.dart.
/// PRD section 11 leaves "exact badge list and unlock conditions" open;
/// this is the concrete answer.
library;

enum BadgeCriteriaType {
  transactionCount,
  streak,
  level,
  questsCompleted,
  daysUnderBudget,
}

class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.iconId,
    required this.criteriaType,
    required this.threshold,
  });

  final String id;
  final String name;
  final String description;

  /// Looked up against an icon map in the UI layer — kept as a string so
  /// the catalog itself (and the persisted Badge model) has no Flutter
  /// dependency.
  final String iconId;
  final BadgeCriteriaType criteriaType;
  final int threshold;
}

const List<BadgeDefinition> kBadgeCatalog = [
  BadgeDefinition(
    id: 'first_log',
    name: 'First Step',
    description: 'Log your first transaction',
    iconId: 'flag',
    criteriaType: BadgeCriteriaType.transactionCount,
    threshold: 1,
  ),
  BadgeDefinition(
    id: 'logs_10',
    name: 'Getting the Hang of It',
    description: 'Log 10 transactions',
    iconId: 'edit_note',
    criteriaType: BadgeCriteriaType.transactionCount,
    threshold: 10,
  ),
  BadgeDefinition(
    id: 'logs_50',
    name: 'Logging Pro',
    description: 'Log 50 transactions',
    iconId: 'auto_awesome',
    criteriaType: BadgeCriteriaType.transactionCount,
    threshold: 50,
  ),
  BadgeDefinition(
    id: 'logs_100',
    name: 'Century Logger',
    description: 'Log 100 transactions',
    iconId: 'military_tech',
    criteriaType: BadgeCriteriaType.transactionCount,
    threshold: 100,
  ),
  BadgeDefinition(
    id: 'streak_3',
    name: 'Warming Up',
    description: 'Reach a 3-day streak',
    iconId: 'local_fire_department',
    criteriaType: BadgeCriteriaType.streak,
    threshold: 3,
  ),
  BadgeDefinition(
    id: 'streak_7',
    name: 'One Week Strong',
    description: 'Reach a 7-day streak',
    iconId: 'whatshot',
    criteriaType: BadgeCriteriaType.streak,
    threshold: 7,
  ),
  BadgeDefinition(
    id: 'streak_30',
    name: 'Habit Formed',
    description: 'Reach a 30-day streak',
    iconId: 'emoji_events',
    criteriaType: BadgeCriteriaType.streak,
    threshold: 30,
  ),
  BadgeDefinition(
    id: 'streak_100',
    name: 'Centurion',
    description: 'Reach a 100-day streak',
    iconId: 'workspace_premium',
    criteriaType: BadgeCriteriaType.streak,
    threshold: 100,
  ),
  BadgeDefinition(
    id: 'level_5',
    name: 'Rising Star',
    description: 'Reach level 5',
    iconId: 'star',
    criteriaType: BadgeCriteriaType.level,
    threshold: 5,
  ),
  BadgeDefinition(
    id: 'level_10',
    name: 'Money Master',
    description: 'Reach level 10',
    iconId: 'diamond',
    criteriaType: BadgeCriteriaType.level,
    threshold: 10,
  ),
  BadgeDefinition(
    id: 'quest_first',
    name: 'Quest Accepted',
    description: 'Complete your first quest',
    iconId: 'flag_circle',
    criteriaType: BadgeCriteriaType.questsCompleted,
    threshold: 1,
  ),
  BadgeDefinition(
    id: 'quest_5',
    name: 'Quest Champion',
    description: 'Complete 5 quests',
    iconId: 'shield',
    criteriaType: BadgeCriteriaType.questsCompleted,
    threshold: 5,
  ),
  BadgeDefinition(
    id: 'budget_week',
    name: 'Budget Boss',
    description: 'Stay under your daily budget on 7 different days',
    iconId: 'savings',
    criteriaType: BadgeCriteriaType.daysUnderBudget,
    threshold: 7,
  ),
];

/// Given the user's current stats and which badge ids are already unlocked,
/// returns the catalog entries that just became eligible. Pure — callers
/// own persistence and ordering (catalog order is used as unlock order).
List<BadgeDefinition> evaluateNewlyUnlockedBadges({
  required int transactionCount,
  required int currentStreak,
  required int level,
  required int questsCompleted,
  required int daysUnderBudget,
  required Set<String> alreadyUnlockedIds,
}) {
  final newlyUnlocked = <BadgeDefinition>[];
  for (final def in kBadgeCatalog) {
    if (alreadyUnlockedIds.contains(def.id)) continue;
    final value = switch (def.criteriaType) {
      BadgeCriteriaType.transactionCount => transactionCount,
      BadgeCriteriaType.streak => currentStreak,
      BadgeCriteriaType.level => level,
      BadgeCriteriaType.questsCompleted => questsCompleted,
      BadgeCriteriaType.daysUnderBudget => daysUnderBudget,
    };
    if (value >= def.threshold) {
      newlyUnlocked.add(def);
    }
  }
  return newlyUnlocked;
}
