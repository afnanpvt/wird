/// Shared formatting for the app's honest, real (never invented) reading
/// stats - used by both the home screen's stats card and the day-level
/// stats screen, so a given number always reads the same way everywhere.
library;

String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m';
  return '${totalSeconds}s';
}

/// Compact so a growing lifetime hasanat total never overflows its column -
/// full-precision numbers show up in smaller-magnitude spots instead (a
/// single day's total, the live reading-session chip).
String formatCompactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}
