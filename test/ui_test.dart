import 'dart:io';
import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('UI Components', () {
    test('PaneBox renders title and border', () async {
      await testNocterm('renders PaneBox', (tester) async {
        await tester.pumpComponent(
          const PaneBox(
            title: 'TEST PANE',
            isFocused: true,
            child: Text('Content inside pane'),
          ),
        );

        expect(tester.terminalState, containsText('TEST PANE'));
        expect(tester.terminalState, containsText('Content inside pane'));
      });
    });

    test('ListItemRow renders prefix and title', () async {
      await testNocterm('renders normal and focused items', (tester) async {
        await tester.pumpComponent(
          const Column(
            children: [
              ListItemRow(
                title: 'AccountOne',
                isFocused: true,
                isSelected: false,
                showCheckbox: true,
              ),
              ListItemRow(
                title: 'AccountTwo',
                isFocused: false,
                isSelected: true,
                showCheckbox: true,
              ),
            ],
          ),
        );

        expect(tester.terminalState, containsText('> [ ] AccountOne'));
        expect(tester.terminalState, containsText('  [x] AccountTwo'));
      });
    });

    test('FooterBar renders hotkeys and status', () async {
      await testNocterm('renders footer bar', (tester) async {
        await tester.pumpComponent(
          const FooterBar(
            statusMessage: 'Ready to launch',
            runHotkey: 'R',
          ),
        );

        expect(tester.terminalState, containsText('Ready to launch'));
        expect(tester.terminalState, containsText('Space'));
        expect(tester.terminalState, containsText('select'));
        expect(tester.terminalState, containsText('Shift+R'));
        expect(tester.terminalState, containsText('Astra Lawnchair v0.1.0'));
      });
    });
  });

  group('MainScreen Navigation', () {
    late Directory tempDir;
    late ScannerService scannerService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lawnchair_ui_test_');
      scannerService = ScannerService(baseDir: tempDir.path);
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('MainScreen drills into configs, toggles queue, and pops back', () async {
      const account1 = Account(
        name: 'AccountAlpha',
        folderPath: '/fake/alpha',
        exePath: '/fake/alpha/AstraBot.exe',
        datPath: '/fake/alpha/alpha.dat',
        configs: ['PvP', 'Farming'],
      );
      const account2 = Account(
        name: 'AccountBeta',
        folderPath: '/fake/beta',
        exePath: '/fake/beta/AstraBot.exe',
        datPath: '/fake/beta/beta.dat',
        configs: ['Galaxy Gates'],
      );

      final config = const AppConfig(rootPath: '/fake/root');
      final launcher = const LauncherService(isDryRun: true);

      await testNocterm('navigation test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: config,
            scannerService: scannerService,
            launcherService: launcher,
            initialAccounts: const [account1, account2],
          ),
        );

        // Verify accounts are visible
        expect(tester.terminalState, containsText('AccountAlpha'));
        expect(tester.terminalState, containsText('AccountBeta'));
        expect(tester.terminalState, containsText('Launch queue is empty'));

        // Press Enter to drill into AccountAlpha
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: AccountAlpha'));
        expect(tester.terminalState, containsText('PvP'));
        expect(tester.terminalState, containsText('Farming'));

        // Press Space on focused config ('PvP') to queue it
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('AccountAlpha — "PvP"'));

        // Move down and queue 'Farming' as well (multi-selection)
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('AccountAlpha — "Farming"'));

        // Press Backspace to return to accounts list
        await tester.sendKey(LogicalKey.backspace);
        expect(tester.terminalState, containsText('MENU (Accounts) [2]'));
        expect(tester.terminalState, containsText('(2 queued)'));

        // The staged launch queue remains visible on the right pane
        expect(tester.terminalState, containsText('AccountAlpha — "PvP"'));
        expect(tester.terminalState, containsText('AccountAlpha — "Farming"'));
      });
    });

    test('SetupScreen text field receives typed text and validates', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final scannerService = ScannerService(baseDir: tempDir.path);
      AppConfig? completedConfig;

      await testNocterm('setup screen text input test', (tester) async {
        await tester.pumpComponent(
          SetupScreen(
            configService: configService,
            scannerService: scannerService,
            onSetupComplete: (cfg) => completedConfig = cfg,
          ),
        );

        expect(tester.terminalState, containsText('Astra Lawnchair — Initial Setup'));

        // Type into the text field
        await tester.enterText(tempDir.path);
        expect(tester.terminalState, containsText(tempDir.path));

        // Submit with Enter
        await tester.sendEnter();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(completedConfig, isNotNull);
        expect(completedConfig!.rootPath, tempDir.path);
      });
    });
  });
}
