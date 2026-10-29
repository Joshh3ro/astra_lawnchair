import '../src/models/account_stats.dart';
import '../src/models/fleet_stats_snapshot.dart';
import '../src/services/fleet_log_service.dart';
import '../src/services/stat_tracker_service.dart';

/// High-level API for monitoring fleet telemetry, capturing session stats, and computing rate changes.
class FleetApi {
  final StatTrackerService _statTracker;
  final FleetLogService _fleetLogService;

  FleetApi({
    required this._statTracker,
    required this._fleetLogService,
  });

  /// The underlying [StatTrackerService].
  StatTrackerService get statTracker => _statTracker;

  /// The underlying [FleetLogService].
  FleetLogService get logService => _fleetLogService;

  /// Returns current in-memory [AccountStats] list for all tracked accounts.
  List<AccountStats> get cachedStats => _statTracker.allStats;

  /// Reads and parses the latest telemetry for all accounts.
  Future<List<AccountStats>> getLiveStats({bool refresh = false}) async {
    return _statTracker.allStats;
  }

  /// Retrieves live statistics for a single account.
  AccountStats? getAccountStats(String accountName) => _statTracker.getStats(accountName);

  /// Captures an immutable [FleetStatsSnapshot] of all currently active bots.
  FleetStatsSnapshot captureSnapshot({List<AccountStats>? stats, String? sessionId}) {
    final effectiveStats = stats ?? _statTracker.allStats;
    final now = DateTime.now();

    int totalUri = 0;
    int totalEp = 0;
    int totalHonor = 0;
    int totalCredits = 0;
    int totalDeaths = 0;
    double totalUriRate = 0;
    double totalEpRate = 0;
    double totalHonorRate = 0;
    int runningCount = 0;
    final accountBreakdowns = <String, AccountStatsSnapshotSummary>{};

    for (final s in effectiveStats) {
      final isRunning = s.sessionStart != null || s.botState.toLowerCase() != 'offline';
      if (isRunning) {
        runningCount++;
        totalUri += s.uridium;
        totalEp += s.experience;
        totalHonor += s.honor;
        totalCredits += s.credits;
        totalDeaths += s.deathCount;

        totalUriRate += s.uridiumPerHour;
        totalEpRate += s.experiencePerHour;
        totalHonorRate += s.honorPerHour;

        accountBreakdowns[s.accountName] = AccountStatsSnapshotSummary(
          accountName: s.accountName,
          uridium: s.uridium,
          credits: s.credits,
          experience: s.experience,
          honor: s.honor,
          deaths: s.deathCount,
          currentMap: s.currentMap,
          botState: s.botState,
          uptimeSeconds: s.uptimeSeconds,
        );
      }
    }

    return FleetStatsSnapshot(
      timestamp: now,
      sessionId: sessionId ?? _fleetLogService.currentSessionId,
      runningBots: runningCount,
      totalAccounts: effectiveStats.length,
      totalUridium: totalUri,
      totalCredits: totalCredits,
      totalExperience: totalEp,
      totalHonor: totalHonor,
      totalDeaths: totalDeaths,
      uridiumPerHour: totalUriRate,
      experiencePerHour: totalEpRate,
      honorPerHour: totalHonorRate,
      accountBreakdowns: accountBreakdowns,
    );
  }

  /// Calculates net changes and rates between [current] snapshot and the initial session baseline.
  FleetStatsDelta? calculateSessionDelta(FleetStatsSnapshot current) {
    return _fleetLogService.calculateSessionDelta(current);
  }

  /// Records a snapshot into rolling disk history.
  Future<void> recordSnapshot(FleetStatsSnapshot snapshot) {
    return _fleetLogService.recordSnapshot(snapshot);
  }

  /// Retrieves the recorded session snapshots from disk or memory.
  Future<List<FleetStatsSnapshot>> getSessionHistory({String? sessionId, int? limit}) async {
    return _fleetLogService.getHistory(sessionId: sessionId, limit: limit);
  }

  /// Clears stored session snapshot history.
  Future<void> clearHistory() {
    return _fleetLogService.clearHistory();
  }
}
