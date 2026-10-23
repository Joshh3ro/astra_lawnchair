import 'dart:io';
import 'package:astra_lawnchair/src/models/account.dart';
import 'package:astra_lawnchair/src/models/app_config.dart';
import 'package:astra_lawnchair/src/models/launch_target.dart';
import 'package:astra_lawnchair/src/services/launcher_service.dart';
import 'package:astra_lawnchair/src/services/process_tracker_service.dart';
import 'package:astra_lawnchair/src/services/scanner_service.dart';
import 'package:astra_lawnchair/src/services/stat_tracker_service.dart';
import 'package:astra_lawnchair/src/ui/screens/main_screen.dart';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Fleet Command Matrix Tests', () {
    late Directory tempDir;
    late Directory acc1Dir;
    late Directory acc2Dir;
    late ProcessTrackerService processTracker;
    late StatTrackerService statTracker;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fleet_matrix_test_');
      acc1Dir = Directory(p.join(tempDir.path, 'AlphaBot'))..createSync(recursive: true);
      acc2Dir = Directory(p.join(tempDir.path, 'BetaBot'))..createSync(recursive: true);

      // Write sample ingame, death, and console logs for AlphaBot
      final ingameFile1 = File(p.join(acc1Dir.path, 'ingameLogs_2026.txt'));
      await ingameFile1.writeAsString('''
[20:21:07] You received 150000 uridium.
[20:21:08] You received 500000 experience points.
[20:21:09] You received 25000 honor points.
''');
      final deathsFile1 = File(p.join(acc1Dir.path, 'deaths_2026.txt'));
      await deathsFile1.writeAsString('''
[20:25:00] You have been destroyed by EnemyShip | Map: 5-3
[20:30:00] You have been destroyed by AlienBoss | Map: 5-3
''');
      final consoleFile1 = File(p.join(acc1Dir.path, '2026-09-10_11-00-00.txt'));
      await consoleFile1.writeAsString('''
[20:00:27] pois ready 5-3
''');

      // Write sample ingame log for BetaBot
      final ingameFile2 = File(p.join(acc2Dir.path, 'ingameLogs_2026.txt'));
      await ingameFile2.writeAsString('''
[20:21:07] You received 50000 uridium.
''');

      processTracker = ProcessTrackerService(baseDir: tempDir.path);
      statTracker = StatTrackerService();

      // Register running session for AlphaBot
      await processTracker.registerLaunch(
        LaunchTarget(
          account: Account(
            name: 'AlphaBot',
            folderPath: acc1Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Palladium'],
          ),
          configName: 'Palladium',
        ),
        12345,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('G hotkey toggles into Fleet Command Matrix and renders table & aggregates', () async {
      await testNocterm('fleet matrix G toggle and table rendering', size: const Size(120, 30), (tester) async {
        final accounts = [
          Account(
            name: 'AlphaBot',
            folderPath: acc1Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Palladium', 'PvP'],
          ),
          Account(
            name: 'BetaBot',
            folderPath: acc2Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Collector'],
          ),
        ];

        await tester.pumpComponent(
          MainScreen(
            config: AppConfig(rootPath: tempDir.path),
            scannerService: ScannerService(baseDir: tempDir.path),
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            statTrackerService: statTracker,
            initialAccounts: accounts,
          ),
        );

        // Verify Top Menu is initially shown
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, containsText('G:fleet'));

        // Press 'G' to open Fleet Command Matrix
        await tester.sendKey(LogicalKey.keyG);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify Fleet Matrix title and headers
        expect(tester.terminalState, containsText('FLEET TELEMETRY & STATS [2 ACCOUNTS]'));
        expect(tester.terminalState, containsText('FLEET BOTS'));
        expect(tester.terminalState, containsText('1/2 Running'));
        expect(tester.terminalState, containsText('TOTAL URIDIUM'));
        expect(tester.terminalState, containsText('+200.000'));
        expect(tester.terminalState, containsText('TOTAL EXP (EP)'));
        expect(tester.terminalState, containsText('+500.000'));
        expect(tester.terminalState, containsText('TOTAL HONOR'));
        expect(tester.terminalState, containsText('+25.000'));
        expect(tester.terminalState, containsText('TOTAL DEATHS'));
        expect(tester.terminalState, containsText('2'));

        // Verify Table Column Headers
        expect(tester.terminalState, containsText('STATUS'));
        expect(tester.terminalState, containsText('ACCOUNT'));
        expect(tester.terminalState, containsText('CONFIG'));
        expect(tester.terminalState, containsText('UPTIME'));
        expect(tester.terminalState, containsText('MAP'));
        expect(tester.terminalState, containsText('URI'));
        expect(tester.terminalState, containsText('URI/HR'));
        expect(tester.terminalState, containsText('EP'));
        expect(tester.terminalState, containsText('HONOR'));
        expect(tester.terminalState, containsText('DEATHS'));

        // Verify AlphaBot row
        expect(tester.terminalState, containsText('● RUNNING'));
        expect(tester.terminalState, containsText('AlphaBot'));
        expect(tester.terminalState, containsText('Palladium'));
        expect(tester.terminalState, containsText('5-3'));
        expect(tester.terminalState, containsText('+150.000'));
        expect(tester.terminalState, containsText('+500.000'));
        expect(tester.terminalState, containsText('+25.000'));

        // Verify BetaBot row
        expect(tester.terminalState, containsText('○ IDLE'));
        expect(tester.terminalState, containsText('BetaBot'));
        expect(tester.terminalState, containsText('Collector'));

        // Verify Footer Bar updated for Fleet Matrix
        expect(tester.terminalState, containsText('Enter:inspect'));
        expect(tester.terminalState, containsText('Space:queue'));
        expect(tester.terminalState, containsText('G:close'));

        // Press 'G' again to return to Top Menu
        await tester.sendKey(LogicalKey.keyG);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
      });
    });

    test('Fleet Matrix arrow navigation, queue toggle, obfuscation and drill-down', () async {
      await testNocterm('fleet matrix interactions', size: const Size(120, 30), (tester) async {
        final accounts = [
          Account(
            name: 'AlphaBot',
            folderPath: acc1Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Palladium'],
          ),
          Account(
            name: 'BetaBot',
            folderPath: acc2Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Collector'],
          ),
        ];

        await tester.pumpComponent(
          MainScreen(
            config: AppConfig(rootPath: tempDir.path),
            scannerService: ScannerService(baseDir: tempDir.path),
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            statTrackerService: statTracker,
            initialAccounts: accounts,
          ),
        );

        // Enter Fleet Matrix via G
        await tester.sendKey(LogicalKey.keyG);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // 1. Move cursor down to BetaBot
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.pump();

        // 2. Queue BetaBot using Space
        await tester.sendKey(LogicalKey.space);
        await tester.pump();

        // BetaBot should now be queued
        expect(tester.terminalState, containsText('QUEUED'));
        expect(tester.terminalState, containsText('(1 Queued)'));

        // 3. Toggle Obfuscation using O
        await tester.sendKey(LogicalKey.keyO);
        await tester.pump();

        // Names should now be obfuscated
        expect(tester.terminalState, containsText('Account #1'));
        expect(tester.terminalState, containsText('Account #2'));
        expect(tester.terminalState, isNot(containsText('AlphaBot')));
        expect(tester.terminalState, isNot(containsText('BetaBot')));

        // 4. Press Enter to drill down into BetaBot's Expanded Stats
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Should now be in expanded telemetry view
        expect(tester.terminalState, containsText('EXPANDED TELEMETRY & LIVE CHARTS: Account #2'));
        expect(tester.terminalState, containsText('COLLECTED REWARDS & MATERIALS:'));

        // 5. Press Backspace to return to Fleet Matrix
        await tester.sendKey(LogicalKey.backspace);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify back in Fleet Matrix
        expect(tester.terminalState, containsText('FLEET TELEMETRY & STATS [2 ACCOUNTS]'));

        // Press Backspace again to return to Top Menu
        await tester.sendKey(LogicalKey.backspace);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
      });
    });

    test('Fleet Matrix top menu navigation and right pane preview', () async {
      await testNocterm('fleet matrix top menu entry', size: const Size(120, 30), (tester) async {
        final accounts = [
          Account(
            name: 'AlphaBot',
            folderPath: acc1Dir.path,
            exePath: '',
            datPath: '',
            configs: const ['Palladium'],
          ),
        ];

        await tester.pumpComponent(
          MainScreen(
            config: AppConfig(rootPath: tempDir.path),
            scannerService: ScannerService(baseDir: tempDir.path),
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            statTrackerService: statTracker,
            initialAccounts: accounts,
          ),
        );

        // Move cursor down to Stats & Fleet Matrix in Top Menu (index 1: Accounts -> Stats & Fleet Matrix)
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.pump();

        // Verify Right Pane shows Fleet Matrix preview
        expect(tester.terminalState, containsText('FLEET MATRIX PREVIEW'));
        expect(tester.terminalState, containsText('FLEET OVERVIEW AT A GLANCE'));
        expect(tester.terminalState, containsText('Total Accounts'));
        expect(tester.terminalState, containsText('Experience (EP)'));
        expect(tester.terminalState, containsText('Honor Points'));
        expect(tester.terminalState, containsText('1'));

        // Press Enter to open Fleet Matrix from Top Menu
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('FLEET TELEMETRY & STATS [1 ACCOUNTS]'));
        expect(tester.terminalState, containsText('AlphaBot'));
      });
    });

    test('Fleet Matrix handles long map names and cleans markdown tags without wrapping', () async {
      await testNocterm('fleet matrix long map name test', size: const Size(120, 30), (tester) async {
          final gammaDir = Directory(p.join(tempDir.path, 'GammaBot'))..createSync(recursive: true);
          final gammaConsole = File(p.join(gammaDir.path, '2026-09-10_12-00-00.txt'));
          await gammaConsole.writeAsString('''
[20:00:27] pois ready Trial of Terror **7**
''');

          final accounts = [
            Account(
              name: 'GammaBot',
              folderPath: gammaDir.path,
              exePath: '',
              datPath: '',
              configs: const ['Event-Farm'],
            ),
          ];

          await tester.pumpComponent(
            MainScreen(
              config: AppConfig(rootPath: tempDir.path),
              scannerService: ScannerService(baseDir: tempDir.path),
              launcherService: const LauncherService(isDryRun: true),
              processTrackerService: processTracker,
              statTrackerService: statTracker,
              initialAccounts: accounts,
            ),
          );

          // Open Fleet Matrix
          await tester.sendKey(LogicalKey.keyG);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          // Verify sanitized map name without markdown asterisks is rendered cleanly with full 20-char column
          expect(tester.terminalState, containsText('Trial of Terror 7'));
          expect(tester.terminalState, isNot(containsText('**7**')));
        });
      });
    });
}
