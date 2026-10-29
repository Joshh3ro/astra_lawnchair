import 'dart:convert';
import 'dart:io';
import 'package:astra_lawnchair/api/api.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late Directory configsDir;
  late Directory rootBotDir;
  late Directory account1Dir;
  late Directory account2Dir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('astra_api_test_');
    configsDir = Directory(p.join(tempDir.path, 'configs'))..createSync(recursive: true);
    rootBotDir = Directory(p.join(tempDir.path, 'AstraBot'))..createSync(recursive: true);

    // Create Account 1
    account1Dir = Directory(p.join(rootBotDir.path, 'AlphaBot'))..createSync();
    File(p.join(account1Dir.path, 'AstraBot.exe')).writeAsStringSync('dummy exe');
    File(p.join(account1Dir.path, 'AlphaBot.dat')).writeAsStringSync('dummy dat');
    final conf1Dir = Directory(p.join(account1Dir.path, 'configs'))..createSync();
    File(p.join(conf1Dir.path, 'Boxer.json')).writeAsStringSync(jsonEncode({'name': 'Boxer'}));
    File(p.join(conf1Dir.path, 'Palladium.json')).writeAsStringSync(jsonEncode({'name': 'Palladium'}));

    // Create Account 2
    account2Dir = Directory(p.join(rootBotDir.path, 'BetaBot'))..createSync();
    File(p.join(account2Dir.path, 'AstraBot.exe')).writeAsStringSync('dummy exe');
    File(p.join(account2Dir.path, 'BetaBot.dat')).writeAsStringSync('dummy dat');
    final conf2Dir = Directory(p.join(account2Dir.path, 'configs'))..createSync();
    File(p.join(conf2Dir.path, 'Gates.json')).writeAsStringSync(jsonEncode({'name': 'Gates'}));
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AstraApi End-to-End Suite', () {
    test('AstraApi initializes cleanly with all sub-APIs wired', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      expect(astra.accounts, isNotNull);
      expect(astra.bots, isNotNull);
      expect(astra.fleet, isNotNull);
      expect(astra.logs, isNotNull);
      expect(astra.config, isNotNull);

      final accounts = await astra.accounts.getAccounts();
      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.name), containsAll(['AlphaBot', 'BetaBot']));
    });

    test('AccountApi queries accounts, configs, and copies profiles', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      final alpha = astra.accounts.getAccountByName('AlphaBot');
      expect(alpha, isNotNull);
      expect(alpha!.name, equals('AlphaBot'));

      final configs = await astra.accounts.getConfigsForAccount('AlphaBot');
      expect(configs, containsAll(['Boxer', 'Palladium']));

      // Copy "Boxer" from AlphaBot to BetaBot
      final copySuccess = await astra.accounts.copyConfig(
        sourceAccountName: 'AlphaBot',
        targetAccountName: 'BetaBot',
        configName: 'Boxer',
      );
      expect(copySuccess, isTrue);

      final betaConfigs = await astra.accounts.getConfigsForAccount('BetaBot');
      expect(betaConfigs, contains('Boxer'));

      // Check on disk
      final copiedFile = File(p.join(account2Dir.path, 'configs', 'Boxer.json'));
      expect(copiedFile.existsSync(), isTrue);
    });

    test('BotApi launches dry-run sessions, tracks state, hot-swaps, and kills', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      final alpha = astra.accounts.getAccountByName('AlphaBot')!;
      expect(astra.bots.isRunning('AlphaBot'), isFalse);

      // Launch single
      final result = await astra.bots.launch(alpha, configName: 'Boxer');
      expect(result.success, isTrue);
      expect(result.pid, equals(99999));
      expect(astra.bots.isRunning('AlphaBot'), isTrue);

      final session = astra.bots.getSession('AlphaBot');
      expect(session, isNotNull);
      expect(session!.configName, equals('Boxer'));

      // Hot-swap
      final swapResult = await astra.bots.hotSwap(account: alpha, configName: 'Palladium');
      expect(swapResult.success, isTrue);
      expect(astra.bots.getSession('AlphaBot')?.configName, equals('Palladium'));

      // Kill
      final killed = await astra.bots.kill('AlphaBot');
      expect(killed, isTrue);
      expect(astra.bots.isRunning('AlphaBot'), isFalse);
    });

    test('FleetApi captures snapshots, computes deltas, and saves history', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      final snapshot = astra.fleet.captureSnapshot();
      expect(snapshot, isNotNull);
      expect(snapshot.timestamp, isNotNull);

      await astra.fleet.recordSnapshot(snapshot);
      final history = await astra.fleet.getSessionHistory();
      expect(history.length, equals(1));

      final delta = astra.fleet.calculateSessionDelta(snapshot);
      expect(delta, isNotNull);

      await astra.fleet.clearHistory();
      final historyAfterClear = await astra.fleet.getSessionHistory();
      expect(historyAfterClear.isEmpty, isTrue);
    });

    test('LogApi detects logs, counts files, and cleans stale logs', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      // Create dummy log files in AlphaBot
      final logsDir = Directory(p.join(account1Dir.path, 'logs'))..createSync();
      File(p.join(logsDir.path, '2026-08-01_10-00-00.txt')).writeAsStringSync('old log line');
      File(p.join(logsDir.path, '2026-08-02_10-00-00.txt')).writeAsStringSync('old log line 2');

      final alpha = astra.accounts.getAccountByName('AlphaBot')!;
      final alphaLogs = await astra.logs.getAccountLogs(alpha);
      expect(alphaLogs.length, equals(2));

      final totalCount = await astra.logs.getTotalLogCount();
      expect(totalCount, equals(2));

      final cleanResult = await astra.logs.cleanLogs();
      expect(cleanResult.filesDeleted, equals(2));
      expect(cleanResult.bytesFreed, greaterThan(0));

      final remainingCount = await astra.logs.getTotalLogCount();
      expect(remainingCount, equals(0));
    });

    test('ConfigApi reads, writes, and updates application configuration', () async {
      final astra = await AstraApi.initialize(
        rootPath: rootBotDir.path,
        configsDir: configsDir.path,
        isDryRun: true,
      );

      expect(astra.config.exists(), isFalse);

      await astra.config.save(AppConfig(
        rootPath: rootBotDir.path,
        clientName: 'Unity',
        staggerDelayMs: 600,
        obfuscateNames: true,
      ));

      expect(astra.config.exists(), isTrue);

      final loaded = await astra.config.load();
      expect(loaded?.staggerDelayMs, equals(600));
      expect(loaded?.obfuscateNames, isTrue);

      final updated = await astra.config.update(staggerDelayMs: 800);
      expect(updated.staggerDelayMs, equals(800));
      expect(updated.obfuscateNames, isTrue);
    });
  });
}
