import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/date_helpers.dart';
import '../models/transaction.dart';

/// Shows the last 7 days as dots, filled when at least one transaction was
/// logged that day — a lightweight visual of the current streak.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.transactions,
    this.daysToShow = 7,
  });

  final List<Transaction> transactions;
  final int daysToShow;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final today = DateTime.now();
    final loggedDays = transactions.map((t) => startOfDay(t.timestamp)).toSet();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(daysToShow, (i) {
        final day = startOfDay(today).subtract(Duration(days: daysToShow - 1 - i));
        final logged = loggedDays.contains(day);
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: logged
                    ? semantics.streak
                    : semantics.streakTrack,
                border: !logged
                    ? Border.all(
                        color: semantics.streak.withValues(alpha: 0.35),
                        width: 1,
                      )
                    : null,
              ),
              child: logged
                  ? Icon(Icons.local_fire_department,
                      color: semantics.onGold, size: 16)
                  : null,
            ),
            SizedBox(height: Spacing.xs),
            Text(
              _weekdayLabel(day.weekday),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        );
      }),
    );
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[weekday - 1];
  }
}
