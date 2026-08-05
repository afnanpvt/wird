class StreakState {
  final int currentStreak;
  final bool graceAvailable;
  final int daysSinceGraceEarned;
  final int consecutiveMissedDays;

  const StreakState({
    this.currentStreak = 0,
    this.graceAvailable = false,
    this.daysSinceGraceEarned = 0,
    this.consecutiveMissedDays = 0,
  });

  StreakState copyWith({
    int? currentStreak,
    bool? graceAvailable,
    int? daysSinceGraceEarned,
    int? consecutiveMissedDays,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      graceAvailable: graceAvailable ?? this.graceAvailable,
      daysSinceGraceEarned: daysSinceGraceEarned ?? this.daysSinceGraceEarned,
      consecutiveMissedDays: consecutiveMissedDays ?? this.consecutiveMissedDays,
    );
  }

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'graceAvailable': graceAvailable,
        'daysSinceGraceEarned': daysSinceGraceEarned,
        'consecutiveMissedDays': consecutiveMissedDays,
      };

  factory StreakState.fromMap(Map<dynamic, dynamic> map) => StreakState(
        currentStreak: map['currentStreak'] as int? ?? 0,
        graceAvailable: map['graceAvailable'] as bool? ?? false,
        daysSinceGraceEarned: map['daysSinceGraceEarned'] as int? ?? 0,
        consecutiveMissedDays: map['consecutiveMissedDays'] as int? ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      other.currentStreak == currentStreak &&
      other.graceAvailable == graceAvailable &&
      other.daysSinceGraceEarned == daysSinceGraceEarned &&
      other.consecutiveMissedDays == consecutiveMissedDays;

  @override
  int get hashCode =>
      Object.hash(currentStreak, graceAvailable, daysSinceGraceEarned, consecutiveMissedDays);

  @override
  String toString() =>
      'StreakState(currentStreak: $currentStreak, graceAvailable: $graceAvailable, '
      'daysSinceGraceEarned: $daysSinceGraceEarned, consecutiveMissedDays: $consecutiveMissedDays)';
}
