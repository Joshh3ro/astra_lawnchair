import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:astra_lawnchair/src/models/account.dart';
import 'package:astra_lawnchair/src/models/app_config.dart';
import 'package:astra_lawnchair/src/models/launch_target.dart';
import 'package:astra_lawnchair/src/services/launcher_service.dart';
import 'package:astra_lawnchair/src/services/log_cleaner_service.dart';
import 'package:astra_lawnchair/src/services/process_tracker_service.dart';
import 'package:astra_lawnchair/src/services/scanner_service.dart';
import 'package:astra_lawnchair/src/ui/screens/main_screen.dart';
import 'package:astra_lawnchair/src/utils/number_formatter.dart';

void main() {
  group('NumberFormatter.formatBytes Tests', () {
    test('formats byte quantities into clean units', () {
      expect(NumberFormatter.formatBytes(0), equals('0 B'));
      expect(NumberFormatter.formatBytes(-50), equals('0 B'));
      expect(NumberFormatter.formatBytes(512), equals('512 B'));
      expect(NumberFormatter.formatBytes(1024), equals('1 KB'));
      expect(NumberFormatter.formatBytes(1536), equals('1.5 KB'));
      expect(NumberFormatter.formatBytes(1048576), equals('1 MB'));
      expect(NumberFormatter.formatBytes(15728640), equals('15 MB'));
      expect(NumberFormatter.formatBytes(1073741824), equals('1 GB'));
      expect(NumberFormatter.formatBytes(2684354560), equals('2.5 GB'));
    });
  });

  group('LogCleanerService Tests', () {
    late Directory tempDir;
    late Directory acc1Dir;
    late Directory acc2Dir;
    late ProcessTrackerService tracker;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('log_cleaner_test_');

      // Acc1 (Inactive bot)
      acc1Dir = Directory(p.join(tempDir.path, 'Account1'))..createSync(recursive: true);
      final acc1Logs = Directory(p.join(acc1Dir.path, 'logs'))..createSync(recursive: true);
      File(p.join(acc1Logs.path, 'ingameLogs_2026-09-10_12-00-00.txt')).writeAsStringSync('ingame logs data');
      File(p.join(acc1Logs.path, 'deaths_2026-09-10_12-00-00.txt')).writeAsStringSync('deaths data');
      File(p.join(acc1Logs.path, '2026-09-10_12-00-00.txt')).writeAsStringSync('stdout data');
      File(p.join(acc1Logs.path, 'debug.log')).writeAsStringSync('debug data');
      File(p.join(acc1Dir.path, 'ingameLogs_2026-09-10_11-00-00.txt')).writeAsStringSync('loose log data');
      // Non-log critical assets
      File(p.join(acc1Dir.path, 'astrabot.exe')).writeAsStringSync('binary');
      File(p.join(acc1Dir.path, 'Account1.dat')).writeAsStringSync('license');
      final acc1Configs = Directory(p.join(acc1Dir.path, 'configs'))..createSync(recursive: true);
      File(p.join(acc1Configs.path, 'default.json')).writeAsStringSync('{}');

      // Acc2 (Active running bot)
      acc2Dir = Directory(p.join(tempDir.path, 'Account2'))..createSync(recursive: true);
      final acc2Logs = Directory(p.join(acc2Dir.path, 'logs'))..createSync(recursive: true);
      // Stale log from 3 days ago
      File(p.join(acc2Logs.path, 'ingameLogs_2026-09-01_10-00-00.txt')).writeAsStringSync('old log');
      // Active log from now
      final nowStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      File(p.join(acc2Logs.path, 'ingameLogs_$nowStr.txt')).writeAsStringSync('active running log');

      tracker = ProcessTrackerService(baseDir: tempDir.path);
      // Register Acc2 as running
      final acc2 = Account(
        name: 'Account2',
        folderPath: acc2Dir.path,
        exePath: p.join(acc2Dir.path, 'astrabot.exe'),
        datPath: p.join(acc2Dir.path, 'Account2.dat'),
      );
      await tracker.registerLaunch(LaunchTarget(account: acc2, configName: 'default'), 99999);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('cleanAllLogs deletes stale logs while protecting active sessions and non-log assets', () async {
      final cleaner = LogCleanerService(processTracker: tracker);
      final accounts = [
        Account(
          name: 'Account1',
          folderPath: acc1Dir.path,
          exePath: p.join(acc1Dir.path, 'astrabot.exe'),
          datPath: p.join(acc1Dir.path, 'Account1.dat'),
        ),
        Account(
          name: 'Account2',
          folderPath: acc2Dir.path,
          exePath: p.join(acc2Dir.path, 'astrabot.exe'),
          datPath: p.join(acc2Dir.path, 'Account2.dat'),
        ),
      ];

      final result = await cleaner.cleanAllLogs(accounts);

      // Acc1: 4 in logs/ + 1 loose in root = 5 files deleted
      // Acc2: 1 stale file deleted, 1 active file protected
      // Total deleted = 6 files
      expect(result.filesDeleted, equals(6));
      expect(result.bytesFreed, greaterThan(0));
      expect(result.accountsScanned, equals(2));
      expect(result.runningBotsProtected, equals(1));

      // Verify critical files were preserved
      expect(File(p.join(acc1Dir.path, 'astrabot.exe')).existsSync(), isTrue);
      expect(File(p.join(acc1Dir.path, 'Account1.dat')).existsSync(), isTrue);
      expect(File(p.join(acc1Dir.path, 'configs', 'default.json')).existsSync(), isTrue);

      // Verify stale Acc1 logs are gone
      final acc1LogsDir = Directory(p.join(acc1Dir.path, 'logs'));
      expect(acc1LogsDir.listSync().isEmpty, isTrue);
      expect(File(p.join(acc1Dir.path, 'ingameLogs_2026-09-10_11-00-00.txt')).existsSync(), isFalse);

      // Verify active Acc2 log was preserved
      final acc2LogsDir = Directory(p.join(acc2Dir.path, 'logs'));
      final acc2Remaining = acc2LogsDir.listSync();
      expect(acc2Remaining.length, equals(1));
      expect(p.basename(acc2Remaining.first.path), contains('ingameLogs_'));
    });

    test('cleanAllLogs handles already clean directories cleanly', () async {
      final cleaner = LogCleanerService(processTracker: tracker);
      final accounts = [
        Account(
          name: 'Account1',
          folderPath: acc1Dir.path,
          exePath: '',
          datPath: '',
        ),
      ];

      // Clean first time
      await cleaner.cleanAllLogs(accounts);

      // Clean second time
      final result2 = await cleaner.cleanAllLogs(accounts);
      expect(result2.filesDeleted, equals(0));
      expect(result2.bytesFreed, equals(0));
      expect(result2.accountsScanned, equals(1));
    });
  });

  group('MainScreen Shift+L Hotkey Integration', () {
    late Directory tempDir;
    late Directory accDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('main_screen_log_cleaner_');
      accDir = Directory(p.join(tempDir.path, 'BotAccount'))..createSync(recursive: true);
      final logsDir = Directory(p.join(accDir.path, 'logs'))..createSync(recursive: true);
      File(p.join(logsDir.path, 'ingameLogs_2026-09-01_12-00-00.txt')).writeAsStringSync('old log data');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Shift+L triggers log cleaner and displays status message and footer key', () async {
      await testNocterm('triggers Shift+L log cleaner', size: const Size(120, 30), (tester) async {
        final account = Account(
          name: 'BotAccount',
          folderPath: accDir.path,
          exePath: '',
          datPath: '',
          configs: ['farm'],
        );

        await tester.pumpComponent(
          MainScreen(
            config: AppConfig(rootPath: tempDir.path),
            scannerService: ScannerService(baseDir: tempDir.path),
            launcherService: LauncherService(isDryRun: true),
            initialAccounts: [account],
          ),
        );

        // Verify footer bar displays Shift+L:clean
        expect(tester.terminalState, containsText('Shift+L:clean'));

        // Trigger Shift+L
        await tester.sendKeyEvent(
          const KeyboardEvent(
            logicalKey: LogicalKey.keyL,
            character: 'L',
            modifiers: ModifierKeys(shift: true),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();

        // Verify status feedback indicates cleaned files
        expect(tester.terminalState, containsText('Cleaned 1 log file(s)'));
        expect(File(p.join(accDir.path, 'logs', 'ingameLogs_2026-09-01_12-00-00.txt')).existsSync(), isFalse);
      });
    });
  });
}
