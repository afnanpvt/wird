/// Shared formatting for backup timestamps - used everywhere a
/// [BackupSnapshot]'s `backedUpAt` (an ISO date-time string) is shown, so it
/// always reads the same way. See stat_formatting.dart for the equivalent
/// convention on reading stats.
library;

String formatBackupDate(String? iso) {
  if (iso == null) return 'never';
  final d = DateTime.tryParse(iso);
  if (d == null) return 'never';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
