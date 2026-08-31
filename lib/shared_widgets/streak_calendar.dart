import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/date_helpers.dart';

/// How a day in the calendar should be drawn.
enum _DayState { logged, frozen, missed, today, future }

/// The last N days as dots, filled when at least one transaction was logged.
///
/// Three things the previous version couldn't express:
///  - **today**, which had no distinct treatment, so the most actionable day
///    looked identical to a missed one;
///  - **a frozen day** — the engine has had streak freezes since day one, but
///    the calendar had no way to show one, so a covered gap looked like a
///    broken streak;
///  - **unambiguous weekdays**: the old single-letter labels gave two `T`s and
///    two `S`s.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.loggedDays,
    this.daysToShow = 7,
    this.onGold = false,
  });

  /// Calendar days (midnight-truncated) with at least one logged
  /// transaction — see `loggedDaysProvider`. Taking the pre-computed set
  /// rather than the raw transaction list means this widget never rescans
  /// the whole history just to answer a handful of day-membership checks.
  final Set<DateTime> loggedDays;
  final int daysToShow;

  /// Set when the calendar sits on a gold hero surface, where the normal
  /// gold-on-gold treatment would vanish.
  final bool onGold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final today = startOfDay(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(daysToShow, (i) {
        final day = today.subtract(Duration(days: daysToShow - 1 - i));
        final state = _stateFor(day, today, loggedDays);
        final isToday = day == today;

        return Expanded(
          child: Semantics(
            // The dot's colour/icon are the only way this state is
            // conveyed, so a screen reader gets nothing without a label.
            label:
                '${_weekdayLabel(day.weekday)}${isToday ? ', today' : ''}, '
                '${_stateLabel(state)}',
            excludeSemantics: true,
            child: Column(
              children: [
                _DayDot(
                  state: state,
                  isToday: isToday,
                  onGold: onGold,
                  // Stagger the fill so the row assembles left-to-right
                  // rather than appearing all at once.
                  delay: AppMotion.staggerDelay(i),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _weekdayLabel(day.weekday),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onGold
                        ? semantics.onGold.withValues(alpha: isToday ? 1 : 0.65)
                        : isToday
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// A day with no logs whose immediate neighbours both have logs was a
  /// single-day gap the streak survived — i.e. a freeze covered it.
  ///
  /// Derived rather than stored: freezes are consumed against day gaps and
  /// nothing records which specific day was covered. Adjacency reconstructs it
  /// exactly for the case that matters, without plumbing replay state into the
  /// widget tree.
  _DayState _stateFor(DateTime day, DateTime today, Set<DateTime> logged) {
    if (logged.contains(day)) return _DayState.logged;
    if (day.isAfter(today)) return _DayState.future;
    if (day == today) return _DayState.today;

    final before = logged.contains(day.subtract(const Duration(days: 1)));
    final after = logged.contains(day.add(const Duration(days: 1)));
    if (before && after) return _DayState.frozen;

    return _DayState.missed;
  }

  static String _weekdayLabel(int weekday) {
    // Two letters: single letters collided on Tue/Thu and Sat/Sun.
    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return labels[weekday - 1];
  }

  static String _stateLabel(_DayState state) => switch (state) {
    _DayState.logged => 'logged',
    _DayState.frozen => 'covered by a streak freeze',
    _DayState.today => 'not logged yet',
    _DayState.missed => 'missed',
    _DayState.future => 'upcoming',
  };
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.state,
    required this.isToday,
    required this.onGold,
    required this.delay,
  });

  final _DayState state;
  final bool isToday;
  final bool onGold;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final cs = Theme.of(context).colorScheme;

    final fill = switch (state) {
      _DayState.logged => onGold ? semantics.onGold : semantics.streak,
      _DayState.frozen =>
        onGold
            ? semantics.onGold.withValues(alpha: 0.25)
            : cs.primary.withValues(alpha: 0.18),
      _DayState.today || _DayState.missed || _DayState.future =>
        onGold
            ? semantics.onGold.withValues(alpha: 0.12)
            : semantics.streakTrack,
    };

    final borderColor = switch (state) {
      _DayState.logged => null,
      _DayState.frozen => onGold ? semantics.onGold : cs.primary,
      _DayState.today => onGold ? semantics.onGold : semantics.streak,
      _ =>
        onGold
            ? semantics.onGold.withValues(alpha: 0.3)
            : semantics.streakDotBorder,
    };

    final icon = switch (state) {
      _DayState.logged => Icons.local_fire_department,
      // A snowflake is the conventional read for a streak freeze.
      _DayState.frozen => Icons.ac_unit,
      _ => null,
    };

    final iconColor = switch (state) {
      _DayState.logged => onGold ? semantics.streak : semantics.onGold,
      _DayState.frozen => onGold ? semantics.onGold : cs.primary,
      _ => null,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: AppMotion.standard,
      curve: AppMotion.emphasized,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: MedallionSize.dayDot,
        height: MedallionSize.dayDot,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: borderColor == null
              ? null
              : Border.all(
                  color: borderColor,
                  // Today gets a thicker ring so the actionable day stands out.
                  width: isToday ? 2 : 1,
                ),
        ),
        child: icon == null
            ? null
            : Icon(icon, color: iconColor, size: IconSize.sm),
      ),
    );
  }
}
