/// Pure date helpers with no Flutter dependency, used across the XP engine,
/// repositories and UI so "day" comparisons are consistent everywhere.
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Whole calendar days between [from] and [to] (ignoring time-of-day),
/// positive when [to] is later.
int daysBetween(DateTime from, DateTime to) {
  return startOfDay(to).difference(startOfDay(from)).inDays;
}

bool isWithinMinutesOf(DateTime a, DateTime b, int minutes) {
  return a.difference(b).abs().inMinutes <= minutes;
}
