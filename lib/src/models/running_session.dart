class RunningSession {
  final String accountName;
  final String configName;
  final int pid;
  final DateTime startTime;

  const RunningSession({
    required this.accountName,
    required this.configName,
    required this.pid,
    required this.startTime,
  });

  Duration get uptime => DateTime.now().difference(startTime);

  String get formattedUptime {
    final diff = uptime;
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    }
    return '${diff.inSeconds}s';
  }

  Map<String, dynamic> toJson() => {
        'accountName': accountName,
        'configName': configName,
        'pid': pid,
        'startTime': startTime.toIso8601String(),
      };

  factory RunningSession.fromJson(Map<String, dynamic> json) {
    return RunningSession(
      accountName: json['accountName'] as String? ?? '',
      configName: json['configName'] as String? ?? '',
      pid: json['pid'] as int? ?? 0,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  RunningSession copyWith({
    String? accountName,
    String? configName,
    int? pid,
    DateTime? startTime,
  }) {
    return RunningSession(
      accountName: accountName ?? this.accountName,
      configName: configName ?? this.configName,
      pid: pid ?? this.pid,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunningSession &&
          runtimeType == other.runtimeType &&
          accountName == other.accountName &&
          pid == other.pid;

  @override
  int get hashCode => accountName.hashCode ^ pid.hashCode;
}
