import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
enum TransactionType {
  @HiveField(0)
  expense,
  @HiveField(1)
  income,
}

@HiveType(typeId: 1)
class Transaction extends HiveObject {
  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.note,
    required this.timestamp,
    required this.loggedAt,
    required this.isQuickLog,
    this.xpAwarded,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  TransactionType type;

  @HiveField(3)
  String category;

  @HiveField(4)
  String? note;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  DateTime loggedAt;

  @HiveField(7)
  bool isQuickLog;

  /// XP this transaction earned, as of the last gamification replay.
  ///
  /// Nullable so Hive records written before this field existed deserialize as
  /// null rather than throwing — same migration pattern as
  /// [UserProfile.remindersEnabled].
  ///
  /// This is a *cache* of what [replayGamification] computed, not an
  /// independent source of truth: the replay recomputes it from scratch on every
  /// mutation and writes back only the rows whose value actually changed. It
  /// exists so the history screen can show "+10 XP" per row without re-running
  /// the engine, and so there's an audit trail if XP is ever disputed.
  ///
  /// null means "never replayed" — render it as no XP chip, not as zero.
  @HiveField(8)
  int? xpAwarded;
}
