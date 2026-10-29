import '../src/models/app_config.dart';
import '../src/services/config_service.dart';
import '../src/services/fleet_log_service.dart';
import '../src/services/launcher_service.dart';
import '../src/services/log_cleaner_service.dart';
import '../src/services/process_tracker_service.dart';
import '../src/services/scanner_service.dart';
import '../src/services/stat_tracker_service.dart';
import 'account_api.dart';
import 'bot_api.dart';
import 'config_api.dart';
import 'fleet_api.dart';
import 'log_api.dart';

/// The central entrypoint and facade for programmatic control of Astra Lawnchair.
///
/// Designed for user expandability, external scripts, Discord bots, automation jobs,
/// and headless operations.
class AstraApi {
  /// Account and configuration discovery API.
  final AccountApi accounts;

  /// Bot launching, tracking, hot-swapping, and termination API.
  final BotApi bots;

  /// Fleet telemetry, rate statistics, and session delta calculation API.
  final FleetApi fleet;

  /// Log cleanup and storage maintenance API.
  final LogApi logs;

  /// Application configuration read/write API.
  final ConfigApi config;

  // Underlying services for direct low-level access when needed
  final ScannerService scannerService;
  final LauncherService launcherService;
  final ProcessTrackerService processTracker;
  final StatTrackerService statTracker;
  final FleetLogService fleetLogService;
  final LogCleanerService logCleaner;
  final ConfigService configService;

  AstraApi({
    required this.accounts,
    required this.bots,
    required this.fleet,
    required this.logs,
    required this.config,
    required this.scannerService,
    required this.launcherService,
    required this.processTracker,
    required this.statTracker,
    required this.fleetLogService,
    required this.logCleaner,
    required this.configService,
  });

  /// Factory method to bootstrap and initialize a fully-configured [AstraApi] instance.
  ///
  /// Any omitted parameter falls back to the persisted [AppConfig] or project defaults.
  static Future<AstraApi> initialize({
    String? rootPath,
    String? configsDir,
    String? clientName,
    int? staggerDelayMs,
    bool isDryRun = false,
    bool autoStart = true,
  }) async {
    final cfgService = ConfigService(baseDir: configsDir);
    final storedConfig = await cfgService.loadConfig();

    final effectiveStorageDir = configsDir ?? ConfigService.defaultStorageDir();
    final effectiveRoot = rootPath ?? storedConfig?.rootPath ?? '';
    final effectiveClient = clientName ?? storedConfig?.clientName ?? 'Unity';
    final effectiveStagger = staggerDelayMs ?? storedConfig?.staggerDelayMs ?? 400;

    final scnService = ScannerService(baseDir: effectiveStorageDir);
    final prcTracker = ProcessTrackerService(baseDir: effectiveStorageDir);
    final stTracker = StatTrackerService();
    final fltLogService = FleetLogService(baseDir: effectiveStorageDir);
    final lgCleaner = LogCleanerService(processTracker: prcTracker, statTracker: stTracker);

    final lnchService = LauncherService(
      staggerDelayMs: effectiveStagger,
      clientName: effectiveClient,
      isDryRun: isDryRun,
      autoStart: autoStart,
    );

    // Initial background discovery & pruning
    await prcTracker.initAndPrune();
    await fltLogService.init();

    final cfgApi = ConfigApi(cfgService);
    final accApi = AccountApi(
      scnService,
      rootPathResolver: () => effectiveRoot,
    );

    // Populate initial accounts
    if (effectiveRoot.isNotEmpty) {
      await accApi.getAccounts(rootPath: effectiveRoot);
    } else {
      await accApi.getAccounts();
    }

    final botApi = BotApi(
      launcherService: lnchService,
      processTracker: prcTracker,
      statTracker: stTracker,
    );

    final fltApi = FleetApi(
      statTracker: stTracker,
      fleetLogService: fltLogService,
    );

    final logApi = LogApi(
      lgCleaner,
      accountsProvider: () => accApi.getAccounts(),
    );

    return AstraApi(
      accounts: accApi,
      bots: botApi,
      fleet: fltApi,
      logs: logApi,
      config: cfgApi,
      scannerService: scnService,
      launcherService: lnchService,
      processTracker: prcTracker,
      statTracker: stTracker,
      fleetLogService: fltLogService,
      logCleaner: lgCleaner,
      configService: cfgService,
    );
  }

  /// Reloads accounts, prunes dead bot sessions, and polls fresh fleet stats.
  Future<void> reload({bool fullRescan = false}) async {
    await accounts.getAccounts(refresh: fullRescan);
    await bots.getRunningSessions(refresh: true);
    await fleet.getLiveStats(refresh: true);
  }
}
