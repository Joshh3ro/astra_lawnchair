import 'dart:io';
import 'package:test/test.dart';
import 'package:astra_lawnchair/src/models/account.dart';
import 'package:astra_lawnchair/src/models/running_session.dart';
import 'package:astra_lawnchair/src/services/stat_tracker_service.dart';

void main() {
  group('StatTrackerService', () {
    late Directory tempDir;
    late Directory accountDir;
    late StatTrackerService service;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('stat_tracker_test_');
      accountDir = Directory('${tempDir.path}\\TestAccount')..createSync();
      service = StatTrackerService();
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Parses ingameLogs_ file for currencies and custom loot items', () async {
      final ingameFile = File('${accountDir.path}\\ingameLogs_2026-09-11.txt');
      await ingameFile.writeAsString('''
[20:21:07] You received 6 uridium.
[20:21:13] You received 2674 experience.
[20:21:13] You received 27 honour.
[20:21:13] You received 12288 credits.
[20:21:13] You received 6 uridium.
[20:21:45] You received 21 Quantum Prism
[20:21:45] You received 3 Xyralith
[20:21:45] You received 1 MR-T03
''');

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final session = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 1234,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      final stats = await service.updateAccount(account, session: session);

      expect(stats.uridium, 12);
      expect(stats.experience, 2674);
      expect(stats.honor, 27);
      expect(stats.credits, 12288);
      expect(stats.itemsGained['Quantum Prism'], 21);
      expect(stats.itemsGained['Xyralith'], 3);
      expect(stats.itemsGained['MR-T03'], 1);
      expect(stats.botState, 'Running');

      // 12 URI in 30 minutes (1800s) -> 24 URI/hr
      expect(stats.uridiumPerHour, closeTo(24.0, 1.0));
    });

    test('Parses deaths_ file for death count, killer, and map', () async {
      final deathFile = File('${accountDir.path}\\deaths_2026-09-11.txt');
      await deathFile.writeAsString('''
[20:22:33] You have been destroyed by ..::{ Boss StreuneR }::.. | Map: 1-8
''');

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final stats = await service.updateAccount(account);

      expect(stats.deathCount, 1);
      expect(stats.lastKiller, '..::{ Boss StreuneR }::..');
      expect(stats.lastDeathMap, '1-8');
      expect(stats.lastDeathTime, isNotNull);
    });

    test('Parses console log for proxy, map, and error states', () async {
      final consoleFile = File('${accountDir.path}\\2026-09-11_20-00-00.txt');
      await consoleFile.writeAsString('''
[19:58:43.640] Proxy test succeed. IP: 192.186.186.236
[20:00:27.748] pois ready Hellfire III
[20:00:28.363] LoginStatus{status=0}
[20:00:44.590] particle null ammunition_slug_ths-c02
[20:25:40.031] Tick error: No packet found in last 30 seconds
''');

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final stats = await service.updateAccount(account);

      expect(stats.activeProxyIp, '192.186.186.236');
      expect(stats.currentMap, 'Hellfire III');
      expect(stats.botState, 'Reconnecting');
      expect(stats.lastError, contains('No packet found in last 30 seconds'));
    });

    test('Byte-offset seek: only newly appended lines are read on second update', () async {
      final ingameFile = File('${accountDir.path}\\ingameLogs_2026-09-11.txt');
      await ingameFile.writeAsString('[20:21:07] You received 10 uridium.\n');

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      var stats = await service.updateAccount(account);
      expect(stats.uridium, 10);

      // Append another line
      await ingameFile.writeAsString('[20:21:20] You received 5 uridium.\n', mode: FileMode.append);

      stats = await service.updateAccount(account);
      expect(stats.uridium, 15); // Correctly added 5, not re-added 10
    });

    test('Ignores stale log files modified before session start time', () async {
      final oldDeathFile = File('${accountDir.path}\\deaths_2026-09-01.txt');
      await oldDeathFile.writeAsString('[10:00:00] You have been destroyed by ..::{ Old Killer }::.. | Map: 1-1\n');
      oldDeathFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      // Session started just now, long after oldDeathFile was modified
      final session = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 95555,
        startTime: DateTime.now(),
      );

      final stats = await service.updateAccount(account, session: session);

      // Death from 10 days ago must be completely ignored for the active session
      expect(stats.deathCount, 0);
      expect(stats.lastKiller, isNull);
    });

    test('Detects newly created session log file mid-session and streams data', () async {
      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final sessionStart = DateTime.now();
      final session = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 95555,
        startTime: sessionStart,
      );

      // Initial check: no log files exist yet for this session
      var stats = await service.updateAccount(account, session: session);
      expect(stats.uridium, 0);

      // Bot receives loot and creates new session log file
      final newIngameFile = File('${accountDir.path}\\ingameLogs_current_session.txt');
      await newIngameFile.writeAsString('[20:30:00] You received 50 uridium.\n');

      stats = await service.updateAccount(account, session: session);
      expect(stats.uridium, 50);
    });

    test('Resets stats and offsets when new session starts with new PID', () async {
      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final session1File = File('${accountDir.path}\\ingameLogs_session1.txt');
      await session1File.writeAsString('[20:00:00] You received 200 uridium.\n');

      final session1 = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 91111,
        startTime: DateTime.now(),
      );

      var stats = await service.updateAccount(account, session: session1);
      expect(stats.uridium, 200);

      // New session started with new PID 92222
      final session2File = File('${accountDir.path}\\ingameLogs_session2.txt');
      await session2File.writeAsString('[21:00:00] You received 30 uridium.\n');

      final session2 = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 92222,
        startTime: DateTime.now(),
      );

      stats = await service.updateAccount(account, session: session2);
      expect(stats.uridium, 30); // Clean reset to session2, not 230!
    });

    test('Discovers and parses logs inside logs/ subdirectory using filename timestamps', () async {
      final logsDir = Directory('${accountDir.path}\\logs')..createSync();
      final ingameFile = File('${logsDir.path}\\ingameLogs_2026-09-12_00-13-02.txt');
      await ingameFile.writeAsString('''
[00:14:00] You received 100 uridium.
[00:14:05] You received 5000 credits.
''');

      final deathFile = File('${logsDir.path}\\deaths_2026-09-12_00-13-02.txt');
      await deathFile.writeAsString('''
[00:15:00] You have been destroyed by ..::{ Boss Kristallon }::.. | Map: 4-5
''');

      final account = Account(
        name: 'TestAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['Config1'],
      );

      final session = RunningSession(
        accountName: account.name,
        configName: 'Config1',
        pid: 77777,
        startTime: DateTime.parse('2026-09-12T00:13:02'),
      );

      final stats = await service.updateAccount(account, session: session);
      expect(stats.uridium, 100);
      expect(stats.credits, 5000);
      expect(stats.deathCount, 1);
      expect(stats.lastKiller, '..::{ Boss Kristallon }::..');
      expect(stats.lastDeathMap, '4-5');
    });
  });
}
