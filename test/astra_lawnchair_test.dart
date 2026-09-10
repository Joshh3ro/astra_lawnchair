import 'dart:convert';
import 'dart:io';
import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:nocterm/nocterm_test.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Astra Lawnchair App E2E Flow', () {
    late Directory tempRoot;
    late Directory appBaseDir;
    late ConfigService configService;
    late ScannerService scannerService;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('astrabot_e2e_root_');
      appBaseDir = Directory.systemTemp.createTempSync('lawnchair_e2e_app_');

      configService = ConfigService(baseDir: appBaseDir.path);
      scannerService = ScannerService(baseDir: appBaseDir.path);

      // Create a mock AstraBot account
      final accDir = Directory(p.join(tempRoot.path, 'AccountBravo'))..createSync();
      File(p.join(accDir.path, 'AstraBot.exe')).writeAsStringSync('dummy');
      File(p.join(accDir.path, 'AccountBravo.dat')).writeAsStringSync('dummy');
      final configsDir = Directory(p.join(accDir.path, 'configs'))..createSync();
      File(p.join(configsDir.path, 'default.json')).writeAsStringSync(
        jsonEncode({'name': 'DefaultConfig'}),
      );
    });

    tearDown(() {
      try {
        tempRoot.deleteSync(recursive: true);
      } catch (_) {}
      try {
        appBaseDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Loads SetupScreen when no config exists, then transitions to MainScreen', () async {
      await testNocterm('app setup and boot test', (tester) async {
        await tester.pumpComponent(
          AstraLawnchairApp(
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify SetupScreen renders because config does not exist
        expect(tester.terminalState, containsText('Astra Lawnchair — Initial Setup'));
        expect(tester.terminalState, containsText('Where are your AstraBot account folders?'));

        // Save a valid configuration directly and trigger scan
        final config = AppConfig(rootPath: tempRoot.path);
        await configService.saveConfig(config);
        final accounts = await scannerService.scanAndCache(tempRoot.path);
        expect(accounts.length, 1);

        // Re-pump component with existing config
        await tester.pumpComponent(
          AstraLawnchairApp(
            configService: configService,
            scannerService: scannerService,
            launcherService: const LauncherService(isDryRun: true),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // Verify MainScreen is now loaded with discovered account
        expect(tester.terminalState, containsText('Astra Lawnchair'));
        expect(tester.terminalState, containsText('AccountBravo'));
        expect(tester.terminalState, containsText('SELECTED (queued to launch)'));
      });
    });
  });
}
