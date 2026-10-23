import 'dart:io';
import 'package:nocterm/nocterm.dart';
import 'package:astra_lawnchair/astra_lawnchair.dart';
import 'package:astra_lawnchair/src/cli/cli_options.dart';

Future<void> main(List<String> args) async {
  final options = CliOptions.parse(args);

  if (options.showHelp) {
    stdout.writeln(CliOptions.getHelpText());
    exit(0);
  }

  if (options.showVersion) {
    stdout.writeln('Astra Lawnchair (astral) v0.1.8');
    exit(0);
  }

  if (options.cleanLogs) {
    stdout.writeln('[astral] Running log cleaner...');
    final configService = ConfigService();
    final config = await configService.loadConfig();
    final rootPath = options.rootPath ?? config?.rootPath;
    if (rootPath == null || rootPath.isEmpty || !Directory(rootPath).existsSync()) {
      stderr.writeln('[astral] Error: No valid root path configured. Use -r <path>.');
      exit(1);
    }
    final scanner = ScannerService(baseDir: rootPath);
    final accounts = await scanner.loadCachedAccounts();
    final processTracker = ProcessTrackerService(baseDir: rootPath);
    await processTracker.initAndPrune();
    final statTracker = StatTrackerService();

    final cleaner = LogCleanerService(
      processTracker: processTracker,
      statTracker: statTracker,
    );
    final result = await cleaner.cleanAllLogs(accounts);
    stdout.writeln(
      '[astral] Cleaned ${result.filesDeleted} stale logs across ${result.accountsScanned} accounts '
      '(${result.formattedBytes} recovered). Active bots protected: ${result.runningBotsProtected}.',
    );
    exit(0);
  }

  if (options.printFleetStats) {
    final configService = ConfigService();
    final config = await configService.loadConfig();
    final rootPath = options.rootPath ?? config?.rootPath;
    if (rootPath == null || rootPath.isEmpty) {
      stderr.writeln('[astral] Error: No root path configured. Run astral first or use -r <path>.');
      exit(1);
    }
    final fleetLog = FleetLogService(baseDir: configService.baseDir);
    await fleetLog.init();
    final latest = fleetLog.latestSnapshot;
    if (latest == null) {
      stdout.writeln('[astral] No recorded fleet telemetry snapshots found in ${configService.baseDir}.');
    } else {
      stdout.writeln('=== FLEET TELEMETRY SNAPSHOT (${latest.timestamp.toLocal()}) ===');
      stdout.writeln('Session:     ${latest.sessionId}');
      stdout.writeln('Bots:        ${latest.runningBots} / ${latest.totalAccounts} running');
      stdout.writeln('Uridium:     +${NumberFormatter.formatNumber(latest.totalUridium)} (+${NumberFormatter.formatRate(latest.uridiumPerHour)}/h)');
      stdout.writeln('Experience:  +${NumberFormatter.formatNumber(latest.totalExperience)} (+${NumberFormatter.formatRate(latest.experiencePerHour)}/h)');
      stdout.writeln('Honor:       +${NumberFormatter.formatNumber(latest.totalHonor)} (+${NumberFormatter.formatRate(latest.honorPerHour)}/h)');
      stdout.writeln('Credits:     +${NumberFormatter.formatNumber(latest.totalCredits)}');
      stdout.writeln('Deaths:      ${latest.totalDeaths}');
    }
    exit(0);
  }

  runApp(AstraLawnchairApp(cliOptions: options));
}
