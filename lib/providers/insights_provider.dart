import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_helpers.dart';
import '../core/utils/recurrence_engine.dart';
import '../models/transaction.dart';
import 'recurring_transaction_provider.dart';
import 'transaction_provider.dart';

/// Selectable time window for Insights. "7 days" used to be hardcoded in
/// three places with no way to look at anything else.
enum InsightsRange {
  week('Week'),
  month('Month'),
  all('All'),
  custom('Custom');

  const InsightsRange(this.label);

  final String label;
}

/// The user-picked window for [InsightsRange.custom] — null until they've
/// actually chosen one via the date-range picker. Session-only, like the
/// range selection itself; there's no need to persist an arbitrary picked
/// range across app restarts.
class CustomInsightsRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void set(DateTimeRange range) => state = range;
}

final customInsightsRangeProvider =
    NotifierProvider<CustomInsightsRangeNotifier, DateTimeRange?>(
      CustomInsightsRangeNotifier.new,
    );

/// A bounded time window plus the transactions inside it, split by type.
class InsightsWindow {
  const InsightsWindow({
    required this.start,
    required this.end,
    required this.expenses,
    required this.income,
  });

  final DateTime start;
  final DateTime end;
  final List<Transaction> expenses;
  final List<Transaction> income;

  double get total => expenses.fold<double>(0, (sum, t) => sum + t.amount);
  double get incomeTotal => income.fold<double>(0, (sum, t) => sum + t.amount);
  double get net => incomeTotal - total;

  int get dayCount => daysBetween(start, end) + 1;
}

List<Transaction> _within(
  List<Transaction> transactions,
  DateTime start,
  DateTime end,
) {
  return transactions
      .where((t) {
        final day = startOfDay(t.timestamp);
        return !day.isBefore(start) && !day.isAfter(end);
      })
      .toList(growable: false);
}

InsightsWindow _windowFromRange(
  List<Transaction> transactions,
  DateTime start,
  DateTime end,
) {
  final inWindow = _within(transactions, start, end);
  return InsightsWindow(
    start: start,
    end: end,
    expenses: inWindow
        .where((t) => t.type == TransactionType.expense)
        .toList(growable: false),
    income: inWindow
        .where((t) => t.type == TransactionType.income)
        .toList(growable: false),
  );
}

/// "Month" used to mean a rolling 30 days, which doesn't match how anyone
/// thinks about a monthly budget ("this month" means the 1st to today) and
/// disagreed with `dailyBudgetFor`'s own calendar-month proration used
/// elsewhere in the app. Now it's the actual calendar month to date.
(DateTime start, DateTime end) _currentBounds(
  InsightsRange range,
  DateTime today,
  List<Transaction> transactions,
) {
  final end = startOfDay(today);
  switch (range) {
    case InsightsRange.week:
      return (end.subtract(const Duration(days: 6)), end);
    case InsightsRange.month:
      return (DateTime(end.year, end.month), end);
    case InsightsRange.all:
      if (transactions.isEmpty) return (end, end);
      final earliest = transactions
          .map((t) => startOfDay(t.timestamp))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      return (earliest, end);
    case InsightsRange.custom:
      // Handled directly in currentInsightsWindowProvider, which has
      // access to customInsightsRangeProvider — this pure function has no
      // way to reach it.
      return (end, end);
  }
}

/// The immediately preceding window of the same shape — the full previous
/// calendar month for "Month", the 7 days before for "Week". Null means "no
/// meaningful previous period" ("All" has nothing before its own start).
(DateTime start, DateTime end)? _previousBounds(
  InsightsRange range,
  InsightsWindow current,
) {
  switch (range) {
    case InsightsRange.week:
      final end = current.start.subtract(const Duration(days: 1));
      return (end.subtract(const Duration(days: 6)), end);
    case InsightsRange.month:
      final lastMonthEnd = current.start.subtract(const Duration(days: 1));
      return (DateTime(lastMonthEnd.year, lastMonthEnd.month), lastMonthEnd);
    case InsightsRange.all:
    case InsightsRange.custom:
      // Neither has a meaningful "previous period" of the same shape — an
      // arbitrary custom span has no natural predecessor to compare against.
      return null;
  }
}

/// The selected window's transactions, bounded on both ends — an unbounded
/// upper end let a future-dated transaction inflate a category past the
/// denominator and render as ">100%", "NaN%" or "Infinity%".
///
/// Cached per [InsightsRange] by Riverpod, so switching ranges or an
/// unrelated rebuild doesn't re-scan the full transaction list — only an
/// actual transaction mutation or a genuine range change does.
final currentInsightsWindowProvider =
    Provider.family<InsightsWindow, InsightsRange>((ref, range) {
      final transactions = ref.watch(transactionsProvider);
      if (range == InsightsRange.custom) {
        final custom = ref.watch(customInsightsRangeProvider);
        final today = startOfDay(DateTime.now());
        final start = custom == null ? today : startOfDay(custom.start);
        final end = custom == null ? today : startOfDay(custom.end);
        return _windowFromRange(transactions, start, end);
      }
      final (start, end) = _currentBounds(range, DateTime.now(), transactions);
      return _windowFromRange(transactions, start, end);
    });

/// The window immediately preceding [currentInsightsWindowProvider]'s, for
/// the "N% more/less than last period" comparison. "All" has no meaningful
/// previous period.
final previousInsightsWindowProvider =
    Provider.family<InsightsWindow, InsightsRange>((ref, range) {
      final current = ref.watch(currentInsightsWindowProvider(range));
      final bounds = _previousBounds(range, current);
      if (bounds == null) {
        return InsightsWindow(
          start: current.start,
          end: current.start,
          expenses: const [],
          income: const [],
        );
      }
      final transactions = ref.watch(transactionsProvider);
      final (start, end) = bounds;
      return _windowFromRange(transactions, start, end);
    });

/// Expense totals per category within the selected window.
final categoryTotalsProvider =
    Provider.family<Map<String, double>, InsightsRange>((ref, range) {
      final window = ref.watch(currentInsightsWindowProvider(range));
      final totals = <String, double>{};
      for (final t in window.expenses) {
        totals[t.category] = (totals[t.category] ?? 0) + t.amount;
      }
      return totals;
    });

/// Expense totals per category for the current calendar month — deliberately
/// independent of the range selector, matching `dailyBudgetFor`'s own
/// calendar-month proration: switching to "Week" shouldn't make a category's
/// monthly budget look unspent.
final monthToDateByCategoryProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final now = DateTime.now();
  final totals = <String, double>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    if (t.timestamp.year != now.year || t.timestamp.month != now.month) {
      continue;
    }
    totals[t.category] = (totals[t.category] ?? 0) + t.amount;
  }
  return totals;
});

/// "At this pace you'll spend X by month end" — the current calendar
/// month's spend-to-date extrapolated at its own daily average. Null once
/// the month is over (nothing left to project) or before anything's been
/// logged (a projection from zero days is meaningless, not zero).
final monthBurnRateProjectionProvider = Provider<double?>((ref) {
  final window = ref.watch(currentInsightsWindowProvider(InsightsRange.month));
  final daysInMonth = DateTime(
    window.start.year,
    window.start.month + 1,
    0,
  ).day;
  final daysElapsed = window.dayCount;
  if (window.total <= 0 || daysElapsed >= daysInMonth) return null;
  return (window.total / daysElapsed) * daysInMonth;
});

/// Total of every active recurring *expense* rule's remaining occurrences
/// this calendar month — recurring rules were entirely invisible to
/// Insights before this, so a known-upcoming rent payment didn't factor
/// into "how much room is left" at all.
final recurringCommitmentForecastProvider = Provider<double>((ref) {
  final rules = ref.watch(recurringTransactionsProvider);
  final today = startOfDay(DateTime.now());
  final monthEnd = DateTime(today.year, today.month + 1, 0);

  var total = 0.0;
  for (final rule in rules) {
    if (!rule.isActive || rule.type != TransactionType.expense) continue;
    final occurrences = forecastOccurrences(
      nextDueDate: rule.nextDueDate,
      frequency: rule.frequency,
      rangeStart: today,
      rangeEnd: monthEnd,
      endDate: rule.endDate,
    );
    total += occurrences.length * rule.amount;
  }
  return total;
});
