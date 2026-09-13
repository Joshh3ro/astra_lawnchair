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
            isObfuscated: false,
          ),
        );

        expect(tester.terminalState, containsText('Ready to launch'));
        expect(tester.terminalState, containsText('Space'));
        expect(tester.terminalState, containsText('select'));
        expect(tester.terminalState, containsText('O'));
        expect(tester.terminalState, containsText('hide'));
        expect(tester.terminalState, containsText('Shift+R'));
        expect(tester.terminalState, containsText('Joshh3ro | v0.1.4'));
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
        expect(tester.terminalState, containsText('Stats'));
        expect(tester.terminalState, containsText('Hotkeys'));
        expect(tester.terminalState, containsText('Settings'));

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

      await testNocterm(
        'settings editor test',
        size: const Size(80, 30),
        (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: initialConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            initialAccounts: const [],
          ),
        );

        // Move down to Settings in Top Menu (index 3: Accounts -> Stats -> Hotkeys -> Settings)
        await tester.sendKey(LogicalKey.arrowDown);
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

        // Move down through Root Path and Obfuscate to Auto-Start Config
        await tester.sendKey(LogicalKey.arrowDown); // Root Path
        await tester.sendKey(LogicalKey.arrowDown); // Obfuscate
        await tester.sendKey(LogicalKey.arrowDown); // Auto-Start Config
        expect(tester.terminalState, containsText('Auto-Start Config'));
        expect(tester.terminalState, containsText('Active: ON (--auto-start enabled'));

        // Toggle Auto-Start (ON -> OFF)
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Active: OFF (--auto-start'));
        reloaded = await configService.loadConfig();
        expect(reloaded!.autoStart, isFalse);

        // Toggle back (OFF -> ON)
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Active: ON (--auto-start'));
        reloaded = await configService.loadConfig();
        expect(reloaded!.autoStart, isTrue);

        // Move down to Back and press Enter to return to Top Menu
        await tester.sendKey(LogicalKey.arrowDown); // Back
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
      });
    });

    test('MainScreen navigates to Stats view and renders telemetry metrics', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final statTracker = StatTrackerService();
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
      );

      final accountDir = Directory('${tempDir.path}\\StatsBotAccount')..createSync();
      final ingameFile = File('${accountDir.path}\\ingameLogs_2026.txt');
      await ingameFile.writeAsString('''
[20:21:07] You received 100 uridium.
[20:21:13] You received 5000 credits.
[20:21:45] You received 5 Quantum Prism
''');

      final statsAccount = Account(
        name: 'StatsBotAccount',
        folderPath: accountDir.path,
        exePath: '${accountDir.path}\\AstraBot.exe',
        datPath: '',
        configs: const ['DefaultConfig'],
      );

      await testNocterm(
        'stats view navigation and metrics test',
        size: const Size(80, 30),
        (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            statTrackerService: statTracker,
            initialAccounts: [statsAccount],
          ),
        );

        // Move down to Stats in Top Menu (index 1: Accounts -> Stats)
        await tester.sendKey(LogicalKey.arrowDown);
        expect(tester.terminalState, containsText('Stats'));

        // Enter Stats view
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(tester.terminalState, containsText('TELEMETRY & STATS'));
        expect(tester.terminalState, containsText('StatsBotAccount'));

        // Right pane displays stat card metrics
        expect(tester.terminalState, containsText('ACCOUNT STATS: StatsBotAccount'));
        expect(tester.terminalState, containsText('Uridium:'));
        expect(tester.terminalState, containsText('+100'));
        expect(tester.terminalState, containsText('Quantum Prism:'));
        expect(tester.terminalState, containsText('+5'));

        // Backspace returns to Top Menu
        await tester.sendKey(LogicalKey.backspace);
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

    test('Hotkey O toggles Obfuscate / Streamer Mode across views', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
        obfuscateNames: false,
      );

      const testAccount = Account(
        name: 'SuperSecretAccount',
        folderPath: 'C:\\bots\\SuperSecretAccount',
        exePath: 'C:\\bots\\SuperSecretAccount\\AstraBot.exe',
        datPath: '',
        configs: ['PvP'],
      );

      await testNocterm('obfuscation toggle test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            initialAccounts: const [testAccount],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Initially in Top Menu, drill into Accounts
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('SuperSecretAccount'));
        expect(tester.terminalState, isNot(containsText('[STREAMER MODE]')));

        // Press 'O' to enable Obfuscation
        await tester.sendKey(LogicalKey.keyO);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Account name should now be masked to Account #1 and [STREAMER MODE] visible
        expect(tester.terminalState, containsText('[STREAMER MODE]'));
        expect(tester.terminalState, containsText('Account #1'));
        expect(tester.terminalState, isNot(containsText('SuperSecretAccount')));

        // Press 'O' again to disable Obfuscation
        await tester.sendKey(LogicalKey.keyO);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('SuperSecretAccount'));
        expect(tester.terminalState, isNot(containsText('[STREAMER MODE]')));
      });
    });

    test('Running session details and badges remain fully visible when Obfuscation is enabled', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final processTracker = ProcessTrackerService(baseDir: tempDir.path);
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
        obfuscateNames: true, // Obfuscated by default
      );

      const runningAccount = Account(
        name: 'PrivateStreamerAccount',
        folderPath: 'C:\\bots\\PrivateStreamerAccount',
        exePath: 'C:\\bots\\PrivateStreamerAccount\\AstraBot.exe',
        datPath: '',
        configs: ['StealthPvP'],
      );

      // Register active running session
      await processTracker.registerLaunch(
        const LaunchTarget(account: runningAccount, configName: 'StealthPvP'),
        77889,
      );

      await testNocterm('running session obfuscation test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            initialAccounts: const [runningAccount],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // 1. Enter Accounts menu
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Accounts [1]'));

        // Account name is obfuscated
        expect(tester.terminalState, containsText('Account #1'));
        expect(tester.terminalState, isNot(containsText('PrivateStreamerAccount')));

        // Running session badge is fully visible in left pane
        expect(tester.terminalState, containsText('RUNNING:'));
        expect(tester.terminalState, containsText('77889'));

        // Right pane displays running bot status with masked account name but visible session metrics
        expect(tester.terminalState, containsText('RUNNING BOT STATUS [PID: 77889]'));
        expect(tester.terminalState, containsText('Active Process Information:'));
        expect(tester.terminalState, containsText('Config Name:'));
        expect(tester.terminalState, containsText('StealthPvP'));
        expect(tester.terminalState, containsText('Process ID (PID):'));
        expect(tester.terminalState, containsText('77889'));
        expect(tester.terminalState, containsText('Uptime:'));

        // 2. Drill into configs
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Account #1 (1 configs)'));
        expect(tester.terminalState, containsText('StealthPvP'));
        expect(tester.terminalState, containsText('RUNNING:'));
        expect(tester.terminalState, containsText('77889'));

        // Pop back to Accounts, then Top Menu
        await tester.sendKey(LogicalKey.backspace);
        await tester.sendKey(LogicalKey.backspace);

        // 3. Move to Stats view
        await tester.sendKey(LogicalKey.arrowDown); // index 1: Stats
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Stats left pane badge has RUNNING and PID
        expect(tester.terminalState, containsText('TELEMETRY & STATS'));
        expect(tester.terminalState, containsText('Account #1'));
        expect(tester.terminalState, containsText('RUNNING:'));
        expect(tester.terminalState, containsText('77889'));

        // Stats right pane details has RUNNING status and PID
        expect(tester.terminalState, containsText('ACCOUNT STATS: Account #1'));
        expect(tester.terminalState, containsText('RUNNING (PID: 77889)'));
      });
    });

    test('MainScreen ignores already-running bots when launching queue', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final processTracker = ProcessTrackerService(baseDir: tempDir.path);
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 200,
      );

      const runningAccount = Account(
        name: 'RunningBot',
        folderPath: 'C:\\bots\\RunningBot',
        exePath: 'C:\\bots\\RunningBot\\AstraBot.exe',
        datPath: '',
        configs: ['PvP'],
      );

      const idleAccount = Account(
        name: 'IdleBot',
        folderPath: 'C:\\bots\\IdleBot',
        exePath: 'C:\\bots\\IdleBot\\AstraBot.exe',
        datPath: '',
        configs: ['Farming'],
      );

      // Register RunningBot as active
      await processTracker.registerLaunch(
        const LaunchTarget(account: runningAccount, configName: 'PvP'),
        12345,
      );

      await testNocterm('skip already running bots test', (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            processTrackerService: processTracker,
            initialAccounts: const [runningAccount, idleAccount],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // 1. Enter Accounts menu
        await tester.sendKey(LogicalKey.enter);
        expect(tester.terminalState, containsText('MENU: Accounts [2]'));

        // Drill into RunningBot and queue 'PvP'
        await tester.sendKey(LogicalKey.enter);
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Added "RunningBot — "PvP"" to launch queue.'));

        // Pop back to Accounts
        await tester.sendKey(LogicalKey.backspace);

        // Move down to IdleBot, drill in, and queue 'Farming'
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.enter);
        await tester.sendKey(LogicalKey.space);
        expect(tester.terminalState, containsText('Added "IdleBot — "Farming"" to launch queue.'));

        // Pop back to Accounts
        await tester.sendKey(LogicalKey.backspace);

        // Press 'R' to run selected queue
        await tester.sendKey(LogicalKey.keyR);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Verify status states that 1 instance was launched and 1 already running was skipped
        expect(tester.terminalState, containsText('Successfully launched 1 bot instance(s) (1 already running skipped)!'));

        // IdleBot should now also be running
        expect(processTracker.isRunning('IdleBot'), isTrue);
        expect(processTracker.isRunning('RunningBot'), isTrue);

        // 2. Now queue RunningBot again and trigger 'R' when ALL queued accounts are running
        await tester.sendKey(LogicalKey.arrowUp); // Focus RunningBot
        await tester.sendKey(LogicalKey.enter); // Drill in
        await tester.sendKey(LogicalKey.space); // Queue PvP
        await tester.sendKey(LogicalKey.backspace); // Pop back

        await tester.sendKey(LogicalKey.keyR);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Should report that all selected accounts are already running and skip launch
        expect(tester.terminalState, containsText('All 1 selected account(s) are already running. Skipped launch.'));
      });
    });

    test('MainScreen navigates to About tab and renders centered changelog', () async {
      final configService = ConfigService(baseDir: tempDir.path);
      final testConfig = AppConfig(
        rootPath: tempRootPath(tempDir),
        clientName: 'Unity',
        staggerDelayMs: 400,
      );

      await testNocterm(
        'about tab navigation and changelog test',
        size: const Size(80, 30),
        (tester) async {
        await tester.pumpComponent(
          MainScreen(
            config: testConfig,
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
            initialAccounts: const [],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // 1. Verify Top Menu header
        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));

        // Navigate down to About (Accounts -> Stats -> Hotkeys -> Settings -> About)
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.sendKey(LogicalKey.arrowDown);
        await tester.pump();

        // Verify About is now visible and focused
        expect(tester.terminalState, containsText('About'));

        // Open About tab
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // 2. Verify single PaneBox renders About header & changelog content
        expect(tester.terminalState, containsText('ABOUT & CHANGELOG'));
        expect(tester.terminalState, containsText('A S T R A   L A W N C H A I R'));
        expect(tester.terminalState, containsText('Version 0.1.4'));
        expect(tester.terminalState, containsText('Joshh3ro'));
        expect(tester.terminalState, containsText('UPDATE CHANGELOG & RELEASE NOTES'));
        expect(tester.terminalState, containsText('• V0.1.4 A (Latest Update) •'));

        // 3. Press Backspace to return to Top Menu
        await tester.sendKey(LogicalKey.backspace);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(tester.terminalState, containsText('MENU: Astra Lawnchair'));
        expect(tester.terminalState, containsText('Accounts (0 accounts)'));
      });
    });
  });
}

String tempRootPath(Directory dir) => dir.path;
