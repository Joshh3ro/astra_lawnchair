import 'dart:io';
import 'package:astra_lawnchair/src/models/account.dart';
import 'package:astra_lawnchair/src/models/launch_target.dart';
import 'package:astra_lawnchair/src/models/running_session.dart';
import 'package:astra_lawnchair/src/services/process_tracker_service.dart';
import 'package:test/test.dart';

void main() {
  group('RunningSession Model', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final session = RunningSession(
        accountName: 'BotAccount1',
        configName: 'GalaxyGates',
        pid: 12345,
        startTime: now,
      );

      final json = session.toJson();
      expect(json['accountName'], 'BotAccount1');
      expect(json['configName'], 'GalaxyGates');
      expect(json['pid'], 12345);

      final restored = RunningSession.fromJson(json);
      expect(restored.accountName, 'BotAccount1');
      expect(restored.configName, 'GalaxyGates');
      expect(restored.pid, 12345);
    });

    test('formats uptime correctly', () {
      final now = DateTime.now();

      final sessionSec = RunningSession(
        accountName: 'Acc',
        configName: 'Cfg',
        pid: 1,
        startTime: now.subtract(const Duration(seconds: 45)),
      );
      expect(sessionSec.formattedUptime, '45s');

      final sessionMin = RunningSession(
        accountName: 'Acc',
        configName: 'Cfg',
        pid: 1,
        startTime: now.subtract(const Duration(minutes: 15, seconds: 10)),
      );
      expect(sessionMin.formattedUptime, '15m');

      final sessionHours = RunningSession(
        accountName: 'Acc',
        configName: 'Cfg',
        pid: 1,
        startTime: now.subtract(const Duration(hours: 3, minutes: 20)),
      );
      expect(sessionHours.formattedUptime, '3h 20m');

      final sessionDays = RunningSession(
        accountName: 'Acc',
        configName: 'Cfg',
        pid: 1,
        startTime: now.subtract(const Duration(days: 2, hours: 5)),
      );
      expect(sessionDays.formattedUptime, '2d 5h');
    });
  });

  group('ProcessTrackerService', () {
    late Directory tempDir;
    late ProcessTrackerService tracker;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('astra_tracker_test_');
      tracker = ProcessTrackerService(baseDir: tempDir.path);
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('registers, persists, and restores sessions', () async {
      const account = Account(
        name: 'Account1',
        folderPath: 'C:\\bots\\Account1',
        exePath: 'C:\\bots\\Account1\\AstraBot.exe',
        datPath: 'C:\\bots\\Account1\\account.dat',
      );
      const target = LaunchTarget(account: account, configName: 'Paladium');

      final session = await tracker.registerLaunch(target, 95555);
      expect(session.accountName, 'Account1');
      expect(tracker.isRunning('Account1'), isTrue);
      expect(tracker.getSession('Account1')?.pid, 95555);

      // Create a fresh tracker instance pointing to same dir
      final tracker2 = ProcessTrackerService(baseDir: tempDir.path);
      await tracker2.loadSessions();

      expect(tracker2.isRunning('Account1'), isTrue);
      expect(tracker2.getSession('Account1')?.configName, 'Paladium');
      expect(tracker2.getSession('Account1')?.pid, 95555);
    });

    test('prunes dead processes', () async {
      const account1 = Account(name: 'Acc1', folderPath: '', exePath: '', datPath: '');
      const account2 = Account(name: 'Acc2', folderPath: '', exePath: '', datPath: '');

      // PID 95000 is considered mock alive in isProcessAlive
      await tracker.registerLaunch(const LaunchTarget(account: account1, configName: 'c1'), 95000);
      // PID -1 or invalid PID is dead
      await tracker.registerLaunch(const LaunchTarget(account: account2, configName: 'c2'), -1);

      expect(tracker.activeSessions.length, 2);

      final pruned = await tracker.pruneStaleSessions();
      expect(pruned, contains('Acc2'));
      expect(tracker.isRunning('Acc1'), isTrue);
      expect(tracker.isRunning('Acc2'), isFalse);
    });

    test('kills session by account name', () async {
      const account = Account(name: 'KillMe', folderPath: '', exePath: '', datPath: '');
      await tracker.registerLaunch(const LaunchTarget(account: account, configName: 'c1'), 95001);
      expect(tracker.isRunning('KillMe'), isTrue);

      final killed = await tracker.killSession('KillMe');
      expect(killed, isTrue);
      expect(tracker.isRunning('KillMe'), isFalse);
    });
  });
}
