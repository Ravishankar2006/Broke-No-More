import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 2)
class UserProfile extends HiveObject {
  UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.joinDate,
    this.currentXP = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.longestStreak = 0,
    DateTime? lastLoggedDate,
    this.monthlyBudget,
    List<String>? badgeIds,
    this.streakFreezesLeft = 1,
    DateTime? lastFreezeResetDate,
    this.lastBudgetBonusDate,
    this.daysUnderBudgetCount = 0,
    bool? remindersEnabled,
  })  : lastLoggedDate = lastLoggedDate ?? joinDate,
        badgeIds = badgeIds ?? <String>[],
        lastFreezeResetDate = lastFreezeResetDate ?? joinDate,
        // Nullable here (unlike the other defaulted fields above) so Hive
        // records saved before this field existed deserialize as `false`
        // instead of throwing on a missing key.
        remindersEnabled = remindersEnabled ?? false;

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String avatarId;

  @HiveField(3)
  DateTime joinDate;

  @HiveField(4)
  int currentXP;

  @HiveField(5)
  int level;

  @HiveField(6)
  int currentStreak;

  @HiveField(7)
  int longestStreak;

  @HiveField(8)
  DateTime lastLoggedDate;

  @HiveField(9)
  double? monthlyBudget;

  @HiveField(10)
  List<String> badgeIds;

  /// Not in the original PRD data model, but required to implement the
  /// "1 free streak freeze per week" grace mechanic from section 6.
  @HiveField(11)
  int streakFreezesLeft;

  @HiveField(12)
  DateTime lastFreezeResetDate;

  /// Last calendar day the "stay under daily budget" XP bonus was awarded,
  /// so it can only be granted once per day.
  @HiveField(13)
  DateTime? lastBudgetBonusDate;

  /// Total number of distinct days the budget bonus has ever been awarded —
  /// drives the "Budget Boss" badge. Not a PRD field; added to make that
  /// badge's unlock condition checkable.
  @HiveField(14)
  int daysUnderBudgetCount;

  /// Opt-in for the local "keep your streak alive" reminder (PRD section
  /// 10 — optional v1.1). Off by default: requesting the OS notification
  /// permission unprompted at first launch is bad practice, so this only
  /// flips on when the user explicitly enables it from Profile.
  @HiveField(15)
  bool remindersEnabled;

  UserProfile copyWith({
    String? name,
    String? avatarId,
    int? currentXP,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLoggedDate,
    double? monthlyBudget,
    // `monthlyBudget: null` is indistinguishable from "not passed" under the
    // `??` fallback below, so clearing it needs its own explicit flag — same
    // pattern as TransactionRepository.update's `clearNote`.
    bool clearMonthlyBudget = false,
    List<String>? badgeIds,
    int? streakFreezesLeft,
    DateTime? lastFreezeResetDate,
    DateTime? lastBudgetBonusDate,
    int? daysUnderBudgetCount,
    bool? remindersEnabled,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      joinDate: joinDate,
      currentXP: currentXP ?? this.currentXP,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      monthlyBudget:
          clearMonthlyBudget ? null : (monthlyBudget ?? this.monthlyBudget),
      badgeIds: badgeIds ?? this.badgeIds,
      streakFreezesLeft: streakFreezesLeft ?? this.streakFreezesLeft,
      lastFreezeResetDate: lastFreezeResetDate ?? this.lastFreezeResetDate,
      lastBudgetBonusDate: lastBudgetBonusDate ?? this.lastBudgetBonusDate,
      daysUnderBudgetCount: daysUnderBudgetCount ?? this.daysUnderBudgetCount,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }
}
