import 'package:broke_no_more/core/utils/recurrence_engine.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('materializeOccurrences', () {
    test('nothing due yet returns no dates and an unmoved cursor', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 9, 1),
        frequency: RecurrenceFrequency.monthly,
        now: DateTime(2026, 8, 15),
      );
      expect(result.dueDates, isEmpty);
      expect(result.nextDueDate, DateTime(2026, 9, 1));
    });

    test('a single day exactly due today is included', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 8, 15),
        frequency: RecurrenceFrequency.monthly,
        now: DateTime(2026, 8, 15),
      );
      expect(result.dueDates, [DateTime(2026, 8, 15)]);
      expect(result.nextDueDate, DateTime(2026, 9, 15));
    });

    test('daily catches up every missed day, oldest first', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 8, 1),
        frequency: RecurrenceFrequency.daily,
        now: DateTime(2026, 8, 5),
      );
      expect(result.dueDates, [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 2),
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 5),
      ]);
      expect(result.nextDueDate, DateTime(2026, 8, 6));
    });

    test('weekly advances by exactly 7 days per occurrence', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 8, 1),
        frequency: RecurrenceFrequency.weekly,
        now: DateTime(2026, 8, 22),
      );
      expect(result.dueDates, [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 8),
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 22),
      ]);
      expect(result.nextDueDate, DateTime(2026, 8, 29));
    });

    test('monthly rolls year over correctly', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 12, 1),
        frequency: RecurrenceFrequency.monthly,
        now: DateTime(2027, 1, 1),
      );
      expect(result.dueDates, [DateTime(2026, 12, 1), DateTime(2027, 1, 1)]);
      expect(result.nextDueDate, DateTime(2027, 2, 1));
    });

    test('an endDate before now cuts occurrences off there, inclusive', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 8, 1),
        frequency: RecurrenceFrequency.weekly,
        now: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 8, 15),
      );
      // 8/15 falls exactly on the end date, so it's the rule's last
      // occurrence — endDate is inclusive, not exclusive.
      expect(result.dueDates, [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 8),
        DateTime(2026, 8, 15),
      ]);
      // The cursor still moves past the last generated occurrence (not just
      // up to endDate), so a caller can tell the rule has nothing left.
      expect(result.nextDueDate, DateTime(2026, 8, 22));
    });

    test('an endDate after now has no effect', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 8, 1),
        frequency: RecurrenceFrequency.monthly,
        now: DateTime(2026, 8, 1),
        endDate: DateTime(2030, 1, 1),
      );
      expect(result.dueDates, [DateTime(2026, 8, 1)]);
    });

    test('a long-dormant daily rule is capped, but the cursor still advances '
        'past everything, not just the capped dates', () {
      final result = materializeOccurrences(
        nextDueDate: DateTime(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        now: DateTime(2026, 8, 23), // well over a year of daily backlog
      );
      expect(result.dueDates, hasLength(kMaxCatchUpOccurrences));
      // The most recent occurrences are kept, not the oldest.
      expect(result.dueDates.last, DateTime(2026, 8, 23));
      expect(
        result.dueDates.first,
        DateTime(
          2026,
          8,
          23,
        ).subtract(const Duration(days: kMaxCatchUpOccurrences - 1)),
      );
      // Cursor is one day past "now", not one day past the last kept date
      // — nothing between the dropped backlog and today gets regenerated
      // on the next call.
      expect(result.nextDueDate, DateTime(2026, 8, 24));
    });
  });

  group('forecastOccurrences', () {
    test('a monthly rule due once within the range returns that one date', () {
      final result = forecastOccurrences(
        nextDueDate: DateTime(2026, 8, 15),
        frequency: RecurrenceFrequency.monthly,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      expect(result, [DateTime(2026, 8, 15)]);
    });

    test('a rule due after the range returns nothing', () {
      final result = forecastOccurrences(
        nextDueDate: DateTime(2026, 9, 1),
        frequency: RecurrenceFrequency.monthly,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      expect(result, isEmpty);
    });

    test('a daily rule lists every remaining day in the range', () {
      final result = forecastOccurrences(
        nextDueDate: DateTime(2026, 8, 28),
        frequency: RecurrenceFrequency.daily,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      expect(result, [
        DateTime(2026, 8, 28),
        DateTime(2026, 8, 29),
        DateTime(2026, 8, 30),
        DateTime(2026, 8, 31),
      ]);
    });

    test('a weekly rule only lists occurrences that land within the range', () {
      final result = forecastOccurrences(
        nextDueDate: DateTime(2026, 8, 20),
        frequency: RecurrenceFrequency.weekly,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      expect(result, [DateTime(2026, 8, 20), DateTime(2026, 8, 27)]);
    });

    test('stops at an end date that falls before the range end', () {
      final result = forecastOccurrences(
        nextDueDate: DateTime(2026, 8, 1),
        frequency: RecurrenceFrequency.weekly,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
        endDate: DateTime(2026, 8, 10),
      );
      expect(result, [DateTime(2026, 8, 1), DateTime(2026, 8, 8)]);
    });

    test(
      'skips forward past a nextDueDate that already sits before rangeStart',
      () {
        final result = forecastOccurrences(
          nextDueDate: DateTime(2026, 7, 15),
          frequency: RecurrenceFrequency.monthly,
          rangeStart: DateTime(2026, 8, 1),
          rangeEnd: DateTime(2026, 8, 31),
        );
        expect(result, [DateTime(2026, 8, 15)]);
      },
    );

    test('does not mutate its inputs — purely computes a return value', () {
      const frequency = RecurrenceFrequency.monthly;
      final nextDueDate = DateTime(2026, 8, 15);
      forecastOccurrences(
        nextDueDate: nextDueDate,
        frequency: frequency,
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 8, 31),
      );
      expect(nextDueDate, DateTime(2026, 8, 15));
    });
  });
}
