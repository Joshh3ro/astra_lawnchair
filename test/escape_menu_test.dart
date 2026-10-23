import 'dart:io';
import 'package:astra_lawnchair/src/models/account.dart';
import 'package:astra_lawnchair/src/models/app_config.dart';
import 'package:astra_lawnchair/src/services/launcher_service.dart';
import 'package:astra_lawnchair/src/services/process_tracker_service.dart';
import 'package:astra_lawnchair/src/services/scanner_service.dart';
import 'package:astra_lawnchair/src/services/stat_tracker_service.dart';
import 'package:astra_lawnchair/src/ui/screens/main_screen.dart';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Escape Quick Menu & Hotkey Cheatsheet Tests', () {
    late Directory tempDir;
    late Directory acc1Dir;
    late ProcessTrackerService processTracker;
    late StatTrackerService statTracker;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('escape_menu_test_');
      acc1Dir = Directory(p.join(tempDir.path, 'AlphaBot'))..createSync(recursive: true);

      processTracker = ProcessTrackerService(baseDir: tempDir.path);
      statTracker = StatTrackerService();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Escape hotkey toggles Quick Menu and displays cheatsheet and quick actions', () async {
      await testNocterm('escape hotkey open and close', size: const Size(120, 30), (tester) async {
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

        // Initial screen: Top Menu
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, containsText('Esc:menu'));

        // Press Escape to open Quick Menu
        await tester.sendKey(LogicalKey.escape);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify Quick Menu modal header and content
        expect(tester.terminalState, containsText('QUICK MENU & HOTKEY CHEATSHEET [ESC]'));
        expect(tester.terminalState, containsText('Settings & Preferences'));
        expect(tester.terminalState, containsText('Stats & Fleet Matrix'));
        expect(tester.terminalState, containsText('Accounts & Launch Queue'));
        expect(tester.terminalState, containsText('Streamer Mode [OFF]'));
        expect(tester.terminalState, containsText('Resume Session'));

        // Verify Cheatsheet columns
        expect(tester.terminalState, containsText('Navigation & Views:'));
        expect(tester.terminalState, containsText('Bot Management:'));
        expect(tester.terminalState, containsText('System & Privacy:'));

        // Verify Escape menu footer
        expect(tester.terminalState, containsText('Esc:close'));
        expect(tester.terminalState, containsText('Enter:select'));
        expect(tester.terminalState, containsText('S:settings'));

        // Press Escape again to close and resume
        await tester.sendKey(LogicalKey.escape);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify back in Top Menu
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, isNot(containsText('QUICK MENU & HOTKEY CHEATSHEET [ESC]')));
      });
    });

    test('Pressing S from Escape Quick Menu navigates directly to Settings screen', () async {
      await testNocterm('escape quick action to settings', size: const Size(120, 30), (tester) async {
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

        // Open Escape Menu
        await tester.sendKey(LogicalKey.escape);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(tester.terminalState, containsText('QUICK MENU & HOTKEY CHEATSHEET [ESC]'));

        // Press 'S' to jump to Settings
        await tester.sendKey(LogicalKey.keyS);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify transitioned to Settings screen
        expect(tester.terminalState, containsText('MENU: Settings'));
        expect(tester.terminalState, containsText('Client Parameter'));
        expect(tester.terminalState, containsText('Launch Stagger Delay'));
        expect(tester.terminalState, isNot(containsText('QUICK MENU & HOTKEY CHEATSHEET [ESC]')));
      });
    });

    test('Navigating quick actions with arrows and pressing Enter triggers action', () async {
      await testNocterm('arrow navigate quick action', size: const Size(120, 30), (tester) async {
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

        // Open Escape Menu
        await tester.sendKey(LogicalKey.escape);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // First item is Settings & Preferences. Press Enter to select
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Should be in Settings
        expect(tester.terminalState, containsText('MENU: Settings'));
      });
    });

    test('Toggling streamer mode O inside Escape Menu updates state and item text', () async {
      await testNocterm('toggle streamer mode in escape menu', size: const Size(120, 30), (tester) async {
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

        // Open Escape Menu
        await tester.sendKey(LogicalKey.escape);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('Streamer Mode [OFF]'));

        // Press 'O' to toggle Streamer Mode
        await tester.sendKey(LogicalKey.keyO);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify updated to [ON]
        expect(tester.terminalState, containsText('Streamer Mode [ON]'));
      });
    });
  });
}
