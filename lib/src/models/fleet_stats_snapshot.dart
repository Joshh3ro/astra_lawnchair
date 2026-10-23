class AccountStatsSnapshotSummary {
  final String accountName;
  final int uridium;
  final int credits;
  final int experience;
  final int honor;
  final int deaths;
  final int uptimeSeconds;
  final String currentMap;
  final String botState;

  const AccountStatsSnapshotSummary({
    required this.accountName,
    this.uridium = 0,
    this.credits = 0,
    this.experience = 0,
    this.honor = 0,
    this.deaths = 0,
    this.uptimeSeconds = 0,
    this.currentMap = 'Unknown',
    this.botState = 'Offline',
  });

  Map<String, dynamic> toJson() => {
        'name': accountName,
        'u': uridium,
        'c': credits,
        'x': experience,
        'h': honor,
        'd': deaths,
        'up': uptimeSeconds,
        'map': currentMap,
        'state': botState,
      };

  factory AccountStatsSnapshotSummary.fromJson(Map<String, dynamic> json) =>
      AccountStatsSnapshotSummary(
        accountName: json['name'] as String? ?? 'Unknown',
        uridium: json['u'] as int? ?? 0,
        credits: json['c'] as int? ?? 0,
        experience: json['x'] as int? ?? 0,
        honor: json['h'] as int? ?? 0,
        deaths: json['d'] as int? ?? 0,
        uptimeSeconds: json['up'] as int? ?? 0,
        currentMap: json['map'] as String? ?? 'Unknown',
        botState: json['state'] as String? ?? 'Offline',
      );
}

class FleetStatsSnapshot {
  final DateTime timestamp;
  final String sessionId;
  final int runningBots;
  final int totalAccounts;
  final int totalUridium;
  final int totalCredits;
  final int totalExperience;
  final int totalHonor;
  final int totalDeaths;
  final double uridiumPerHour;
  final double experiencePerHour;
  final double honorPerHour;
  final Map<String, AccountStatsSnapshotSummary> accountBreakdowns;

  const FleetStatsSnapshot({
    required this.timestamp,
    required this.sessionId,
    this.runningBots = 0,
    this.totalAccounts = 0,
    this.totalUridium = 0,
    this.totalCredits = 0,
    this.totalExperience = 0,
    this.totalHonor = 0,
    this.totalDeaths = 0,
    this.uridiumPerHour = 0.0,
    this.experiencePerHour = 0.0,
    this.honorPerHour = 0.0,
    this.accountBreakdowns = const {},
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'sessionId': sessionId,
        'runningBots': runningBots,
        'totalAccounts': totalAccounts,
        'totalUridium': totalUridium,
        'totalCredits': totalCredits,
        'totalExperience': totalExperience,
        'totalHonor': totalHonor,
        'totalDeaths': totalDeaths,
        'uridiumPerHour': uridiumPerHour,
        'experiencePerHour': experiencePerHour,
        'honorPerHour': honorPerHour,
        'accountBreakdowns': accountBreakdowns.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory FleetStatsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accountBreakdowns'] as Map<String, dynamic>? ?? {};
    final breakdowns = rawAccounts.map(
      (k, v) => MapEntry(k, AccountStatsSnapshotSummary.fromJson(v as Map<String, dynamic>)),
    );

    return FleetStatsSnapshot(
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      sessionId: json['sessionId'] as String? ?? '',
      runningBots: json['runningBots'] as int? ?? 0,
      totalAccounts: json['totalAccounts'] as int? ?? 0,
      totalUridium: json['totalUridium'] as int? ?? 0,
      totalCredits: json['totalCredits'] as int? ?? 0,
      totalExperience: json['totalExperience'] as int? ?? 0,
      totalHonor: json['totalHonor'] as int? ?? 0,
      totalDeaths: json['totalDeaths'] as int? ?? 0,
      uridiumPerHour: (json['uridiumPerHour'] as num?)?.toDouble() ?? 0.0,
      experiencePerHour: (json['experiencePerHour'] as num?)?.toDouble() ?? 0.0,
      honorPerHour: (json['honorPerHour'] as num?)?.toDouble() ?? 0.0,
      accountBreakdowns: breakdowns,
    );
  }

  /// Calculates the delta change between this baseline snapshot and a [newer] snapshot.
  FleetStatsDelta calculateDelta(FleetStatsSnapshot newer) {
    final duration = newer.timestamp.difference(timestamp);
    final durationSec = duration.inSeconds;

    final uDelta = newer.totalUridium - totalUridium;
    final cDelta = newer.totalCredits - totalCredits;
    final xDelta = newer.totalExperience - totalExperience;
    final hDelta = newer.totalHonor - totalHonor;
    final dDelta = newer.totalDeaths - totalDeaths;

    final double effectiveURate = durationSec > 5 ? (uDelta / durationSec) * 3600 : 0.0;
    final double effectiveXRate = durationSec > 5 ? (xDelta / durationSec) * 3600 : 0.0;
    final double effectiveHRate = durationSec > 5 ? (hDelta / durationSec) * 3600 : 0.0;

    // Per-account uridium deltas
    final accountUriDeltas = <String, int>{};
    for (final entry in newer.accountBreakdowns.entries) {
      final baseAcc = accountBreakdowns[entry.key];
      final baseUri = baseAcc?.uridium ?? 0;
      accountUriDeltas[entry.key] = entry.value.uridium - baseUri;
    }

    return FleetStatsDelta(
      fromTimestamp: timestamp,
      toTimestamp: newer.timestamp,
      duration: duration,
      uridiumDelta: uDelta,
      creditsDelta: cDelta,
      experienceDelta: xDelta,
      honorDelta: hDelta,
      deathsDelta: dDelta,
      effectiveUridiumPerHour: effectiveURate,
      effectiveExperiencePerHour: effectiveXRate,
      effectiveHonorPerHour: effectiveHRate,
      accountUridiumDeltas: accountUriDeltas,
    );
  }
}

class FleetStatsDelta {
  final DateTime fromTimestamp;
  final DateTime toTimestamp;
  final Duration duration;
  final int uridiumDelta;
  final int creditsDelta;
  final int experienceDelta;
  final int honorDelta;
  final int deathsDelta;
  final double effectiveUridiumPerHour;
  final double effectiveExperiencePerHour;
  final double effectiveHonorPerHour;
  final Map<String, int> accountUridiumDeltas;

  const FleetStatsDelta({
    required this.fromTimestamp,
    required this.toTimestamp,
    required this.duration,
    required this.uridiumDelta,
    required this.creditsDelta,
    required this.experienceDelta,
    required this.honorDelta,
    required this.deathsDelta,
    required this.effectiveUridiumPerHour,
    required this.effectiveExperiencePerHour,
    required this.effectiveHonorPerHour,
    this.accountUridiumDeltas = const {},
  });

  Map<String, dynamic> toJson() => {
        'from': fromTimestamp.toIso8601String(),
        'to': toTimestamp.toIso8601String(),
        'durationSec': duration.inSeconds,
        'uridiumDelta': uridiumDelta,
        'creditsDelta': creditsDelta,
        'experienceDelta': experienceDelta,
        'honorDelta': honorDelta,
        'deathsDelta': deathsDelta,
        'effectiveUridiumPerHour': effectiveUridiumPerHour,
        'effectiveExperiencePerHour': effectiveExperiencePerHour,
        'effectiveHonorPerHour': effectiveHonorPerHour,
        'accountUridiumDeltas': accountUridiumDeltas,
      };

  factory FleetStatsDelta.fromJson(Map<String, dynamic> json) => FleetStatsDelta(
        fromTimestamp: DateTime.tryParse(json['from'] as String? ?? '') ?? DateTime.now(),
        toTimestamp: DateTime.tryParse(json['to'] as String? ?? '') ?? DateTime.now(),
        duration: Duration(seconds: json['durationSec'] as int? ?? 0),
        uridiumDelta: json['uridiumDelta'] as int? ?? 0,
        creditsDelta: json['creditsDelta'] as int? ?? 0,
        experienceDelta: json['experienceDelta'] as int? ?? 0,
        honorDelta: json['honorDelta'] as int? ?? 0,
        deathsDelta: json['deathsDelta'] as int? ?? 0,
        effectiveUridiumPerHour: (json['effectiveUridiumPerHour'] as num?)?.toDouble() ?? 0.0,
        effectiveExperiencePerHour: (json['effectiveExperiencePerHour'] as num?)?.toDouble() ?? 0.0,
        effectiveHonorPerHour: (json['effectiveHonorPerHour'] as num?)?.toDouble() ?? 0.0,
        accountUridiumDeltas: (json['accountUridiumDeltas'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int? ?? 0)) ??
            const {},
      );

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }
}
