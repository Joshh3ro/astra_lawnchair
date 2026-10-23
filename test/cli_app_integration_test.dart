import 'dart:io';
import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:astra_lawnchair/src/cli/cli_options.dart';
import 'package:nocterm/nocterm.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AstraLawnchairApp CLI Integration Tests', () {
    late Directory tempDir;
    late Directory accDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cli_app_test_');
      accDir = Directory(p.join(tempDir.path, 'AlphaBot'))..createSync(recursive: true);
      final ingameLog = File(p.join(accDir.path, 'ingameLogs_2026.txt'));
      await ingameLog.writeAsString('[10:00:00] You received 5000 uridium.\n');
    });

    tearDown(() async {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('App launches directly into Fleet Matrix when -g/--fleet is passed', () async {
      await testNocterm('launch in fleet matrix', size: const Size(120, 30), (tester) async {
        final configService = ConfigService(baseDir: tempDir.path);
        await configService.saveConfig(AppConfig(rootPath: tempDir.path));

        const cli = CliOptions(startInFleet: true, dryRun: true);

        await tester.pumpComponent(
          AstraLawnchairApp(
            configService: configService,
            scannerService: ScannerService(baseDir: tempDir.path),
            cliOptions: cli,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Verify direct launch into Fleet Command Matrix
        expect(tester.terminalState, containsText('FLEET TELEMETRY & STATS'));
        expect(tester.terminalState, containsText('FLEET BOTS'));
        expect(tester.terminalState, containsText('TOTAL URIDIUM'));
      });
    });

    test('App launches with Streamer Mode enabled when -o is passed', () async {
      await testNocterm('launch in streamer mode', size: const Size(120, 30), (tester) async {
        final configService = ConfigService(baseDir: tempDir.path);
        await configService.saveConfig(AppConfig(rootPath: tempDir.path));

        const cli = CliOptions(streamerMode: true, dryRun: true);

        await tester.pumpComponent(
          AstraLawnchairApp(
            configService: configService,
            scannerService: ScannerService(baseDir: tempDir.path),
            cliOptions: cli,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Go to accounts
        await tester.sendKey(LogicalKey.enter);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        // Verify account name is masked to Account #1
        expect(tester.terminalState, containsText('Account #1'));
        expect(tester.terminalState, isNot(containsText('AlphaBot')));
      });
    });
  });
}
