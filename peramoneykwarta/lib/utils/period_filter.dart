/// Pure period logic for the expenses filter.
///
/// Scales: Day, Week (Monday-start), Month, All.
/// No side effects, no Flutter dependencies — safe to unit test.
enum PeriodScale { day, week, month, all }

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Truncates [date] to midnight.
DateTime _truncate(DateTime date) => DateTime(date.year, date.month, date.day);

/// Monday-start week containing [date].
DateTime startOfWeek(DateTime date) {
  final day = _truncate(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Inclusive-start / exclusive-end bounds for [anchor] on [scale].
/// Returns `null` for [PeriodScale.all] (unbounded).
({DateTime start, DateTime end})? periodRange(PeriodScale scale, DateTime anchor) {
  final day = _truncate(anchor);
  switch (scale) {
    case PeriodScale.day:
      return (start: day, end: day.add(const Duration(days: 1)));
    case PeriodScale.week:
      final start = startOfWeek(day);
      return (start: start, end: start.add(const Duration(days: 7)));
    case PeriodScale.month:
      return (
        start: DateTime(day.year, day.month, 1),
        end: DateTime(day.year, day.month + 1, 1),
      );
    case PeriodScale.all:
      return null;
  }
}

/// Moves [anchor] exactly one period in [direction] (+1 forward, -1 back).
DateTime shiftPeriod(PeriodScale scale, DateTime anchor, int direction) {
  final day = _truncate(anchor);
  switch (scale) {
    case PeriodScale.day:
      return day.add(Duration(days: direction));
    case PeriodScale.week:
      return day.add(Duration(days: 7 * direction));
    case PeriodScale.month:
      return DateTime(day.year, day.month + direction, 1);
    case PeriodScale.all:
      return day;
  }
}

/// Whether navigating [direction] (+1) keeps the period starting today or
/// earlier — i.e. the future is unreachable. Back navigation is always allowed.
bool canShiftPeriod(PeriodScale scale, DateTime anchor, DateTime now, int direction) {
  if (direction <= 0) return true;
  if (scale == PeriodScale.all) return false;
  final next = periodRange(scale, shiftPeriod(scale, anchor, direction))!;
  return !next.start.isAfter(_truncate(now));
}

/// Human label for the period, e.g. "October 2026", "Sep 28 – Oct 4".
String formatPeriodLabel(PeriodScale scale, DateTime anchor) {
  final day = _truncate(anchor);
  switch (scale) {
    case PeriodScale.day:
      return '${_monthsShort[day.month - 1]} ${day.day}, ${day.year}';
    case PeriodScale.week:
      final start = startOfWeek(day);
      final end = start.add(const Duration(days: 6));
      return '${_monthsShort[start.month - 1]} ${start.day}'
          ' – ${_monthsShort[end.month - 1]} ${end.day}';
    case PeriodScale.month:
      return '${_months[day.month - 1]} ${day.year}';
    case PeriodScale.all:
      return 'All time';
  }
}
