import 'dart:io';
import 'package:astra_lawnchair/src/models/fleet_stats_snapshot.dart';
import 'package:astra_lawnchair/src/services/fleet_log_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FleetStatsSnapshot and FleetStatsDelta Tests', () {
    test('FleetStatsSnapshot serializes to and from JSON', () {
      final now = DateTime.now();
      final snapshot = FleetStatsSnapshot(
        timestamp: now,
        sessionId: 'session_test_1',
        runningBots: 3,
        totalAccounts: 5,
        totalUridium: 250000,
        totalCredits: 12000000,
        totalExperience: 4500000,
        totalHonor: 85000,
        totalDeaths: 2,
        uridiumPerHour: 55000.5,
        experiencePerHour: 320000.0,
        honorPerHour: 12000.0,
        accountBreakdowns: {
          'AlphaBot': const AccountStatsSnapshotSummary(
            accountName: 'AlphaBot',
            uridium: 150000,
            experience: 2500000,
            honor: 50000,
            deaths: 1,
            uptimeSeconds: 3600,
            currentMap: '5-3',
            botState: 'Running',
          ),
        },
      );

      final json = snapshot.toJson();
      final restored = FleetStatsSnapshot.fromJson(json);

      expect(restored.sessionId, equals('session_test_1'));
      expect(restored.runningBots, equals(3));
      expect(restored.totalAccounts, equals(5));
      expect(restored.totalUridium, equals(250000));
      expect(restored.totalExperience, equals(4500000));
      expect(restored.totalHonor, equals(85000));
      expect(restored.totalDeaths, equals(2));
      expect(restored.accountBreakdowns.containsKey('AlphaBot'), isTrue);
      expect(restored.accountBreakdowns['AlphaBot']!.currentMap, equals('5-3'));
    });

    test('calculateDelta computes accurate gains, deaths, and effective rates', () {
      final t0 = DateTime(2026, 10, 23, 10, 0, 0);
      final t1 = DateTime(2026, 10, 23, 11, 0, 0); // 1 hour elapsed (3600s)

      final baseline = FleetStatsSnapshot(
        timestamp: t0,
        sessionId: 'session_delta_test',
        runningBots: 2,
        totalAccounts: 2,
        totalUridium: 100000,
        totalCredits: 5000000,
        totalExperience: 1000000,
        totalHonor: 20000,
        totalDeaths: 1,
        accountBreakdowns: {
          'Alpha': const AccountStatsSnapshotSummary(accountName: 'Alpha', uridium: 60000),
          'Beta': const AccountStatsSnapshotSummary(accountName: 'Beta', uridium: 40000),
        },
      );

      final current = FleetStatsSnapshot(
        timestamp: t1,
        sessionId: 'session_delta_test',
        runningBots: 2,
        totalAccounts: 2,
        totalUridium: 172000, // +72,000 uri
        totalCredits: 6200000, // +1,200,000 credits
        totalExperience: 1500000, // +500,000 exp
        totalHonor: 35000, // +15,000 honor
        totalDeaths: 3, // +2 deaths
        accountBreakdowns: {
          'Alpha': const AccountStatsSnapshotSummary(accountName: 'Alpha', uridium: 100000), // +40,000
          'Beta': const AccountStatsSnapshotSummary(accountName: 'Beta', uridium: 72000), // +32,000
        },
      );

      final delta = baseline.calculateDelta(current);

      expect(delta.duration.inSeconds, equals(3600));
      expect(delta.formattedDuration, equals('1h 0m 0s'));
      expect(delta.uridiumDelta, equals(72000));
      expect(delta.creditsDelta, equals(1200000));
      expect(delta.experienceDelta, equals(500000));
      expect(delta.honorDelta, equals(15000));
      expect(delta.deathsDelta, equals(2));
      // Effective hourly rates: over 1 hour, rate equals the delta
      expect(delta.effectiveUridiumPerHour, closeTo(72000.0, 1.0));
      expect(delta.effectiveExperiencePerHour, closeTo(500000.0, 1.0));
      expect(delta.effectiveHonorPerHour, closeTo(15000.0, 1.0));

      // Per-account deltas
      expect(delta.accountUridiumDeltas['Alpha'], equals(40000));
      expect(delta.accountUridiumDeltas['Beta'], equals(32000));
    });
  });

  group('FleetLogService Persistence & API Tests', () {
    late Directory tempDir;
    late FleetLogService fleetLogService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fleet_log_test_');
      fleetLogService = FleetLogService(baseDir: tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('records snapshot, creates session baseline and persists to disk', () async {
      await fleetLogService.init();

      expect(fleetLogService.snapshots, isEmpty);
      expect(fleetLogService.sessionBaseline, isNull);

      final snap1 = FleetStatsSnapshot(
        timestamp: DateTime.now(),
        sessionId: fleetLogService.currentSessionId,
        runningBots: 1,
        totalAccounts: 2,
        totalUridium: 10000,
      );

      await fleetLogService.recordSnapshot(snap1);

      expect(fleetLogService.snapshots.length, equals(1));
      expect(fleetLogService.sessionBaseline, isNotNull);
      expect(fleetLogService.sessionBaseline!.totalUridium, equals(10000));

      // Check file created
      final file = File(p.join(tempDir.path, 'configs', 'fleet_sessions.json'));
      expect(file.existsSync(), isTrue);

      // Create new service instance pointing to same dir to test restore
      final reloadedService = FleetLogService(baseDir: tempDir.path);
      await reloadedService.init();

      expect(reloadedService.snapshots.length, equals(1));
      expect(reloadedService.snapshots.first.totalUridium, equals(10000));
    });

    test('calculateSessionDelta uses baseline to compute live session progress', () async {
      await fleetLogService.init();

      final t0 = DateTime.now();
      final t1 = t0.add(const Duration(minutes: 30));

      final base = FleetStatsSnapshot(
        timestamp: t0,
        sessionId: fleetLogService.currentSessionId,
        totalUridium: 50000,
        totalExperience: 200000,
        totalHonor: 10000,
        totalDeaths: 0,
      );

      fleetLogService.setSessionBaseline(base);
      await fleetLogService.recordSnapshot(base);

      final current = FleetStatsSnapshot(
        timestamp: t1,
        sessionId: fleetLogService.currentSessionId,
        totalUridium: 85000, // +35,000
        totalExperience: 350000, // +150,000
        totalHonor: 18000, // +8,000
        totalDeaths: 1, // +1
      );

      final delta = fleetLogService.calculateSessionDelta(current);
      expect(delta, isNotNull);
      expect(delta!.uridiumDelta, equals(35000));
      expect(delta.experienceDelta, equals(150000));
      expect(delta.honorDelta, equals(8000));
      expect(delta.deathsDelta, equals(1));
      expect(delta.duration.inMinutes, equals(30));
    });

    test('clearHistory clears memory and deletes persistent storage file', () async {
      await fleetLogService.init();
      await fleetLogService.recordSnapshot(
        FleetStatsSnapshot(timestamp: DateTime.now(), sessionId: 'test', totalUridium: 100),
      );

      final file = File(p.join(tempDir.path, 'configs', 'fleet_sessions.json'));
      expect(file.existsSync(), isTrue);

      await fleetLogService.clearHistory();

      expect(fleetLogService.snapshots, isEmpty);
      expect(fleetLogService.sessionBaseline, isNull);
      expect(file.existsSync(), isFalse);
    });
  });
}
