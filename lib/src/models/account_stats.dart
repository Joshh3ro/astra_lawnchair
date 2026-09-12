class AccountStats {
  final String accountName;
  final DateTime? sessionStart;
  final int uptimeSeconds;
  final String currentMap;
  final String botState;
  final String? activeProxyIp;
  final String? lastError;
  final DateTime? lastErrorTime;

  // Currencies
  final int uridium;
  final int credits;
  final int experience;
  final int honor;

  // Deaths
  final int deathCount;
  final String? lastKiller;
  final String? lastDeathMap;
  final DateTime? lastDeathTime;

  // Loot items (e.g. Quantum Prism, Xyralith, etc.)
  final Map<String, int> itemsGained;

  const AccountStats({
    required this.accountName,
    this.sessionStart,
    this.uptimeSeconds = 0,
    this.currentMap = 'Unknown',
    this.botState = 'Offline',
    this.activeProxyIp,
    this.lastError,
    this.lastErrorTime,
    this.uridium = 0,
    this.credits = 0,
    this.experience = 0,
    this.honor = 0,
    this.deathCount = 0,
    this.lastKiller,
    this.lastDeathMap,
    this.lastDeathTime,
    this.itemsGained = const {},
  });

  // Dynamic rates per hour
  double get uridiumPerHour => _calcRate(uridium);
  double get creditsPerHour => _calcRate(credits);
  double get experiencePerHour => _calcRate(experience);
  double get honorPerHour => _calcRate(honor);

  double _calcRate(int amount) {
    if (uptimeSeconds <= 0 || amount <= 0) return 0.0;
    return (amount / uptimeSeconds) * 3600.0;
  }

  String get formattedUptime {
    if (uptimeSeconds <= 0) return '0s';
    final hours = uptimeSeconds ~/ 3600;
    final minutes = (uptimeSeconds % 3600) ~/ 60;
    final seconds = uptimeSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get formattedTimeSinceLastDeath {
    if (lastDeathTime == null) return 'None';
    final diff = DateTime.now().difference(lastDeathTime!);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inSeconds}s ago';
    }
  }

  AccountStats copyWith({
    String? accountName,
    DateTime? sessionStart,
    int? uptimeSeconds,
    String? currentMap,
    String? botState,
    String? activeProxyIp,
    String? lastError,
    DateTime? lastErrorTime,
    int? uridium,
    int? credits,
    int? experience,
    int? honor,
    int? deathCount,
    String? lastKiller,
    String? lastDeathMap,
    DateTime? lastDeathTime,
    Map<String, int>? itemsGained,
  }) {
    return AccountStats(
      accountName: accountName ?? this.accountName,
      sessionStart: sessionStart ?? this.sessionStart,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      currentMap: currentMap ?? this.currentMap,
      botState: botState ?? this.botState,
      activeProxyIp: activeProxyIp ?? this.activeProxyIp,
      lastError: lastError ?? this.lastError,
      lastErrorTime: lastErrorTime ?? this.lastErrorTime,
      uridium: uridium ?? this.uridium,
      credits: credits ?? this.credits,
      experience: experience ?? this.experience,
      honor: honor ?? this.honor,
      deathCount: deathCount ?? this.deathCount,
      lastKiller: lastKiller ?? this.lastKiller,
      lastDeathMap: lastDeathMap ?? this.lastDeathMap,
      lastDeathTime: lastDeathTime ?? this.lastDeathTime,
      itemsGained: itemsGained ?? this.itemsGained,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountName': accountName,
      'sessionStart': sessionStart?.toIso8601String(),
      'uptimeSeconds': uptimeSeconds,
      'currentMap': currentMap,
      'botState': botState,
      'activeProxyIp': activeProxyIp,
      'lastError': lastError,
      'lastErrorTime': lastErrorTime?.toIso8601String(),
      'uridium': uridium,
      'credits': credits,
      'experience': experience,
      'honor': honor,
      'deathCount': deathCount,
      'lastKiller': lastKiller,
      'lastDeathMap': lastDeathMap,
      'lastDeathTime': lastDeathTime?.toIso8601String(),
      'itemsGained': itemsGained,
    };
  }

  factory AccountStats.fromJson(Map<String, dynamic> json) {
    return AccountStats(
      accountName: json['accountName'] as String? ?? '',
      sessionStart: json['sessionStart'] != null ? DateTime.tryParse(json['sessionStart'] as String) : null,
      uptimeSeconds: json['uptimeSeconds'] as int? ?? 0,
      currentMap: json['currentMap'] as String? ?? 'Unknown',
      botState: json['botState'] as String? ?? 'Offline',
      activeProxyIp: json['activeProxyIp'] as String?,
      lastError: json['lastError'] as String?,
      lastErrorTime: json['lastErrorTime'] != null ? DateTime.tryParse(json['lastErrorTime'] as String) : null,
      uridium: json['uridium'] as int? ?? 0,
      credits: json['credits'] as int? ?? 0,
      experience: json['experience'] as int? ?? 0,
      honor: json['honor'] as int? ?? 0,
      deathCount: json['deathCount'] as int? ?? 0,
      lastKiller: json['lastKiller'] as String?,
      lastDeathMap: json['lastDeathMap'] as String?,
      lastDeathTime: json['lastDeathTime'] != null ? DateTime.tryParse(json['lastDeathTime'] as String) : null,
      itemsGained: (json['itemsGained'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          const {},
    );
  }
}
