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
        expect(tester.terminalState, containsText('Joshh3ro | v0.1.1'));
        expect(tester.terminalState, containsText('(GitHub)'));
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

    test('MainScreen navigates top menu, drills into configs, toggles queue, and pops back', () async {
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

        // Verify Top-Level Menu is displayed first
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, containsText('Accounts (2 accounts)'));
        expect(tester.terminalState, containsText('Hotkeys'));
        expect(tester.terminalState, containsText('Settings'));
        expect(tester.terminalState, containsText('Quit'));

        // Press Enter on Accounts to enter accounts list
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Accounts [2]'));
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
        expect(tester.terminalState, containsText('MENU: Accounts [2]'));
        expect(tester.terminalState, containsText('(2 queued)'));

        // The staged launch queue remains visible on the right pane
        expect(tester.terminalState, containsText('AccountAlpha — "PvP"'));
        expect(tester.terminalState, containsText('AccountAlpha — "Farming"'));

        // Press Backspace again to return to top-level menu
        await tester.sendKey(LogicalKey.backspace);
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, containsText('Accounts (2 accounts, 2 queued)'));
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

    test('MainScreen Settings allows toggling client, cycling stagger, and editing root path', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final initialConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
      );
      await configService.saveConfig(initialConfig);

      await testNocterm('settings editor test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: initialConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            initialAccounts: const [],
          ),
        );

        // Move down to Settings in Top Menu (index 2: Accounts -> Hotkeys -> Settings)
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.arrowDown);
        expect(tester.terminalState, containsText('Settings'));

        // Press Enter to open Settings editor
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Settings'));
        expect(tester.terminalState, containsText('Client Parameter'));
        expect(tester.terminalState, containsText('Active: Unity'));

        // Toggle Client mode (Unity -> Flash)
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Active: Flash'));

        // Verify persisted to disk
        var reloaded = await configService.loadConfig();
        expect(reloaded!.clientName, 'Flash');

        // Move down to Launch Stagger Delay
        await tester.sendKey(LogicalKey.arrowDown);
        expect(tester.terminalState, containsText('Active: 400 ms'));

        // Cycle Stagger Delay (400 -> 500 ms)
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Active: 500 ms'));
        reloaded = await configService.loadConfig();
        expect(reloaded!.staggerDelayMs, 500);

        // Move down to Back and press Enter to return to Top Menu
        await tester.sendKey(LogicalKey.arrowDown); // Root Path
        await tester.sendKey(LogicalKey.arrowDown); // Back
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
      });
    });

    test('MainScreen displays running bot badge and terminates via K hotkey', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final processTracker = ProcessTrackerService(baseDir: tempDir.path);
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
      );

      const runningAccount = Account(
        name: 'ActiveBotAccount',
        folderPath: 'C:\\bots\\ActiveBotAccount',
        exePath: 'C:\\bots\\ActiveBotAccount\\AstraBot.exe',
        datPath: '',
        configs: ['PvP', 'Farming'],
      );

      // Pre-register a running bot session (mock PID 95555)
      await processTracker.registerLaunch(
        const LaunchTarget(account: runningAccount, configName: 'PvP'),
        95555,
      );

      await testNocterm('running bot badge and kill test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            initialAccounts: [runningAccount],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Enter Accounts menu
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Accounts [1]'));

        // Verify running badge is visible in Accounts list
        expect(tester.terminalState, containsText('RUNNING'));
        expect(tester.terminalState, containsText('95555'));

        // Right pane displays running bot status inspector
        expect(tester.terminalState, containsText('RUNNING BOT STATUS [PID: 95555]'));
        expect(tester.terminalState, containsText('Config Name:'));
        expect(tester.terminalState, containsText('PvP'));

        // Press 'K' to terminate the running bot
        await tester.sendKey(LogicalKey.keyK);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify status message updates and session is terminated
        expect(tester.terminalState, containsText('Terminated bot for "ActiveBotAccount"'));
        expect(processTracker.isRunning('ActiveBotAccount'), isFalse);
      });
    });
  });
}

String tempRootPath(Directory dir) => dir.path;
