import 'package:nocterm/nocterm.dart';
import '../models/account.dart';
import '../models/account_stats.dart';
import '../models/app_config.dart';
import '../services/config_service.dart';
import '../services/launcher_service.dart';
import '../services/process_tracker_service.dart';
import '../services/scanner_service.dart';
import '../services/stat_tracker_service.dart';
import 'screens/main_screen.dart';
import 'screens/setup_screen.dart';
import 'theme.dart';

class AstraLawnchairApp extends StatefulComponent {
  final ConfigService? configService;
  final ScannerService? scannerService;
  final LauncherService? launcherService;
  final ProcessTrackerService? processTrackerService;
  final StatTrackerService? statTrackerService;

  const AstraLawnchairApp({
    super.key,
    this.configService,
    this.scannerService,
    this.launcherService,
    this.processTrackerService,
    this.statTrackerService,
  });

  @override
  State<AstraLawnchairApp> createState() => _AstraLawnchairAppState();
}

class _AstraLawnchairAppState extends State<AstraLawnchairApp> {
  late final ConfigService _configService;
  late final ScannerService _scannerService;
  late final LauncherService _launcherService;
  late final ProcessTrackerService _processTrackerService;
  late final StatTrackerService _statTrackerService;

  bool _isLoading = true;
  AppConfig? _config;
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _configService = component.configService ?? ConfigService();
    _scannerService = component.scannerService ?? ScannerService();
    _launcherService = component.launcherService ?? const LauncherService();
    _processTrackerService = component.processTrackerService ??
        ProcessTrackerService(baseDir: _configService.baseDir);
    _statTrackerService = component.statTrackerService ?? StatTrackerService();

    _initialize();
  }

  Future<void> _initialize() async {
    final loadedConfig = await _configService.loadConfig();
    if (loadedConfig != null && loadedConfig.rootPath.isNotEmpty) {
      // Load cached accounts
      var accounts = await _scannerService.loadCachedAccounts();
      if (accounts.isEmpty) {
        // If cache is missing or empty, perform initial scan
        accounts = await _scannerService.scanAndCache(loadedConfig.rootPath);
      }

      // Initialize active sessions and check OS liveness
      await _processTrackerService.initAndPrune();
      for (final session in _processTrackerService.activeSessions.values) {
        if (session.lastStats != null) {
          _statTrackerService.restoreStats(
            session.accountName,
            AccountStats.fromJson(session.lastStats!),
          );
        }
      }

      setState(() {
        _config = loadedConfig;
        _accounts = accounts;
        _isLoading = false;
      });
    } else {
      setState(() {
        _config = null;
        _isLoading = false;
      });
    }
  }

  void _onSetupComplete(AppConfig config) async {
    final accounts = await _scannerService.loadCachedAccounts();
    setState(() {
      _config = config;
      _accounts = accounts;
    });
  }

  @override
  Component build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Text(
          'Loading Astra Lawnchair...',
          style: LawnchairTheme.statusInfo,
        ),
      );
    }

    final currentConfig = _config;
    if (currentConfig == null || currentConfig.rootPath.isEmpty) {
      return SetupScreen(
        configService: _configService,
        scannerService: _scannerService,
        onSetupComplete: _onSetupComplete,
      );
    }

    return MainScreen(
      config: currentConfig,
      configService: _configService,
      scannerService: _scannerService,
      launcherService: _launcherService,
      processTrackerService: _processTrackerService,
      statTrackerService: _statTrackerService,
      initialAccounts: _accounts,
    );
  }
}
