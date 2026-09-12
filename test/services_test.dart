import 'dart:convert';
import 'dart:io';
import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Models & Serialization', () {
    test('AppConfig toJson and fromJson', () {
      final config = const AppConfig(
        rootPath: r'E:\darkorbit\AstraBot',
        staggerDelayMs: 500,
        clientName: 'Unity',
        runHotkey: 'R',
        obfuscateNames: true,
      );

      final json = config.toJson();
      final loaded = AppConfig.fromJson(json);

      expect(loaded.rootPath, r'E:\darkorbit\AstraBot');
      expect(loaded.staggerDelayMs, 500);
      expect(loaded.clientName, 'Unity');
      expect(loaded.runHotkey, 'R');
      expect(loaded.obfuscateNames, isTrue);
    });

    test('Obfuscator masks account names and IP addresses correctly', () {
      Obfuscator.clearCache();

      // Disabled mode returns original values
      expect(Obfuscator.obfuscateAccountName('AstraBot - Main', enabled: false), 'AstraBot - Main');
      expect(Obfuscator.obfuscateIp('192.186.186.236', enabled: false), '192.186.186.236');

      // Enabled mode with index
      expect(Obfuscator.obfuscateAccountName('AstraBot - Main', index: 0, enabled: true), 'Account #1');
      expect(Obfuscator.obfuscateAccountName('AstraBot - Alt', index: 1, enabled: true), 'Account #2');

      // Consistent lookup from cache
      expect(Obfuscator.obfuscateAccountName('AstraBot - Main', enabled: true), 'Account #1');

      // IP masking (entire IP masked)
      expect(Obfuscator.obfuscateIp('192.186.186.236', enabled: true), '***.***.***.***');
      expect(Obfuscator.obfuscateIp('10.0.0.1:8080', enabled: true), '***.***.***.***:8080');
      expect(Obfuscator.obfuscateIp(null, enabled: true), isNull);
    });

    test('Account and LaunchTarget equality', () {
      const account1 = Account(
        name: 'Account1',
        folderPath: '/path/to/acc1',
        exePath: '/path/to/acc1/AstraBot.exe',
        datPath: '/path/to/acc1/acc1.dat',
        configs: ['Config A', 'Config B'],
      );

      const account2 = Account(
        name: 'Account1',
        folderPath: '/path/to/acc1',
        exePath: '/path/to/acc1/AstraBot.exe',
        datPath: '/path/to/acc1/acc1.dat',
        configs: ['Config A'],
      );

      expect(account1, equals(account2));

      const target1 = LaunchTarget(account: account1, configName: 'Config A');
      const target2 = LaunchTarget(account: account2, configName: 'Config A');
      const target3 = LaunchTarget(account: account1, configName: 'Config B');

      expect(target1, equals(target2));
      expect(target1, isNot(equals(target3)));
      expect(target1.displayName, 'Account1 — "Config A"');
    });
  });

  group('ConfigService', () {
    late Directory tempDir;
    late ConfigService configService;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lawnchair_config_test_');
      configService = ConfigService(baseDir: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('saves and loads configuration', () async {
      expect(configService.configExists(), isFalse);

      final config = AppConfig(rootPath: tempDir.path, staggerDelayMs: 350);
      await configService.saveConfig(config);

      expect(configService.configExists(), isTrue);

      final loaded = await configService.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.rootPath, tempDir.path);
      expect(loaded.staggerDelayMs, 350);
    });
  });

  group('ScannerService', () {
    late Directory tempRoot;
    late Directory appCacheDir;
    late ScannerService scannerService;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('astrabot_root_');
      appCacheDir = Directory.systemTemp.createTempSync('lawnchair_cache_');
      scannerService = ScannerService(baseDir: appCacheDir.path);

      // Account 1
      final acc1 = Directory(p.join(tempRoot.path, 'AccountOne'))..createSync();
      File(p.join(acc1.path, 'AstraBot.exe')).writeAsStringSync('binary');
      File(p.join(acc1.path, 'AccountOne.dat')).writeAsStringSync('dat');
      final acc1Configs = Directory(p.join(acc1.path, 'configs'))..createSync();
      File(p.join(acc1Configs.path, 'c1.json')).writeAsStringSync(
        jsonEncode({'name': 'Trinity Trials'}),
      );
      File(p.join(acc1Configs.path, 'c2.json')).writeAsStringSync(
        jsonEncode({'name': 'PvP Fast'}),
      );

      // Account 2
      final acc2 = Directory(p.join(tempRoot.path, 'AccountTwo'))..createSync();
      File(p.join(acc2.path, 'bot.exe')).writeAsStringSync('binary');
      File(p.join(acc2.path, 'user.dat')).writeAsStringSync('dat');
      final acc2Configs = Directory(p.join(acc2.path, 'configs'))..createSync();
      File(p.join(acc2Configs.path, 'farm.json')).writeAsStringSync(
        jsonEncode({'name': 'Farm Route B'}),
      );
    });

    tearDown(() {
      tempRoot.deleteSync(recursive: true);
      appCacheDir.deleteSync(recursive: true);
    });

    test('scans root directory, discovers accounts, and writes cache', () async {
      final accounts = await scannerService.scanAndCache(tempRoot.path);

      expect(accounts.length, 2);
      expect(accounts[0].name, 'AccountOne');
      expect(accounts[0].configs, containsAll(['PvP Fast', 'Trinity Trials']));
      expect(accounts[0].exePath, endsWith('AstraBot.exe'));
      expect(accounts[0].datPath, endsWith('AccountOne.dat'));

      expect(accounts[1].name, 'AccountTwo');
      expect(accounts[1].configs, contains('Farm Route B'));
      expect(accounts[1].exePath, endsWith('bot.exe'));

      expect(scannerService.cacheExists(), isTrue);

      // Load from cache without scanning
      final cached = await scannerService.loadCachedAccounts();
      expect(cached.length, 2);
      expect(cached[0].name, 'AccountOne');
      expect(cached[0].configs, contains('Trinity Trials'));
    });

    test('automatically creates non-existent configs folder when scanning', () async {
      final nonExistentConfigsDir = p.join(appCacheDir.path, 'nested', 'configs');
      final service = ScannerService(baseDir: nonExistentConfigsDir);

      expect(Directory(nonExistentConfigsDir).existsSync(), isFalse);

      final accounts = await service.scanAndCache(tempRoot.path);
      expect(accounts.isNotEmpty, isTrue);

      expect(Directory(nonExistentConfigsDir).existsSync(), isTrue);
      expect(File(p.join(nonExistentConfigsDir, 'accounts.json')).existsSync(), isTrue);
      expect(File(p.join(nonExistentConfigsDir, 'AccountOne-Configs.json')).existsSync(), isTrue);
    });
  });

  group('LauncherService', () {
    test('dry-run execution formats arguments and fires callbacks', () async {
      const account = Account(
        name: 'AccountOne',
        folderPath: '/fake/folder',
        exePath: '/fake/folder/AstraBot.exe',
        datPath: '/fake/folder/AccountOne.dat',
        configs: ['Trinity Trials', 'PvP Fast'],
      );

      final targets = [
        const LaunchTarget(account: account, configName: 'Trinity Trials'),
        const LaunchTarget(account: account, configName: 'PvP Fast'),
      ];

      final launcher = const LauncherService(
        staggerDelayMs: 10,
        clientName: 'Unity',
        isDryRun: true,
      );

      final progressItems = <String>[];
      final results = await launcher.launchAll(
        targets,
        onProgress: (target, current, total) {
          progressItems.add('${target.configName} ($current/$total)');
        },
      );

      expect(results.length, 2);
      expect(results.every((r) => r.success), isTrue);
      expect(progressItems, ['Trinity Trials (1/2)', 'PvP Fast (2/2)']);
    });
  });

  group('ProcessTrackerService', () {
    late Directory tempDir;
    late ProcessTrackerService processTracker;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('process_tracker_test_');
      processTracker = ProcessTrackerService(baseDir: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('registers launch, updates stats, saves to disk and restores on init', () async {
      const account = Account(
        name: 'PersistAccount',
        folderPath: '/fake/folder',
        exePath: '/fake/folder/AstraBot.exe',
        datPath: '',
        configs: ['Config1'],
      );

      const target = LaunchTarget(account: account, configName: 'Config1');

      // Register with mock PID 96666 (within alive mock test range 90000-99999)
      await processTracker.registerLaunch(target, 96666);
      expect(processTracker.isRunning('PersistAccount'), isTrue);

      final stats = const AccountStats(
        accountName: 'PersistAccount',
        uridium: 1500,
        credits: 90000,
        deathCount: 2,
        currentMap: '3-1',
      );

      await processTracker.updateSessionStats('PersistAccount', stats.toJson());

      // Create a brand new instance simulating tool restart
      final restartedTracker = ProcessTrackerService(baseDir: tempDir.path);
      await restartedTracker.initAndPrune();

      expect(restartedTracker.isRunning('PersistAccount'), isTrue);
      final restoredSession = restartedTracker.getSession('PersistAccount');
      expect(restoredSession, isNotNull);
      expect(restoredSession!.pid, 96666);
      expect(restoredSession.lastStats, isNotNull);

      final restoredStats = AccountStats.fromJson(restoredSession.lastStats!);
      expect(restoredStats.uridium, 1500);
      expect(restoredStats.credits, 90000);
      expect(restoredStats.deathCount, 2);
      expect(restoredStats.currentMap, '3-1');
    });

    test('prunes dead process sessions on init', () async {
      const account = Account(
        name: 'DeadAccount',
        folderPath: '/fake/folder',
        exePath: '/fake/folder/AstraBot.exe',
        datPath: '',
        configs: ['Config1'],
      );

      const target = LaunchTarget(account: account, configName: 'Config1');

      // Register with PID 99999999 which is not in OS or mock range
      await processTracker.registerLaunch(target, 99999999);

      final restartedTracker = ProcessTrackerService(baseDir: tempDir.path);
      await restartedTracker.initAndPrune();

      // Dead session must be pruned!
      expect(restartedTracker.isRunning('DeadAccount'), isFalse);
    });
  });
}
