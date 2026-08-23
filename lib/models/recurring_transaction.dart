import 'package:hive/hive.dart';

import 'transaction.dart';

part 'recurring_transaction.g.dart';

/// How often a [RecurringTransaction] repeats.
@HiveType(typeId: 8)
enum RecurrenceFrequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
}

/// A standing rule ("Rent, ₹15000, expense, monthly") that materializes into
/// real [Transaction] rows over time, rather than one the user re-logs by
/// hand every period.
///
/// There is no backend to run this on a schedule, so materialization only
/// ever happens at app startup (`RecurringTransactionRepository.materializeDue`,
/// called from `main.dart` alongside `QuestRepository.expireOverdueQuests`) —
/// same constraint, same checkpoint.
@HiveType(typeId: 9)
class RecurringTransaction extends HiveObject {
  RecurringTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.note,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.endDate,
    this.isActive = true,
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
  RecurrenceFrequency frequency;

  @HiveField(6)
  DateTime startDate;

  /// Cursor: the next date materialization is due. Starts equal to
  /// [startDate] and only ever advances forward — this rule never re-derives
  /// it from history, unlike the transaction-derived gamification state,
  /// because nothing about a recurring rule's own schedule can be
  /// retroactively invalidated the way editing a transaction invalidates XP.
  @HiveField(7)
  DateTime nextDueDate;

  /// Null means "no end — repeats indefinitely".
  @HiveField(8)
  DateTime? endDate;

  /// Pausing keeps the rule (and its schedule position) without deleting it
  /// or generating anything while off. Also flipped automatically once
  /// [nextDueDate] passes [endDate].
  @HiveField(9)
  bool isActive;
}
