import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:nocterm/nocterm.dart';
import '../../models/account.dart';
import '../../models/app_config.dart';
import '../../models/launch_target.dart';
import '../../models/running_session.dart';
import '../../services/config_service.dart';
import '../../services/launcher_service.dart';
import '../../services/process_tracker_service.dart';
import '../../services/scanner_service.dart';
import '../../services/stat_tracker_service.dart';
import '../../utils/item_classifier.dart';
import '../../utils/number_formatter.dart';
import '../../utils/obfuscator.dart';
import '../theme.dart';
import '../widgets/ascii_chart.dart';
import '../widgets/footer_bar.dart';
import '../widgets/list_item_row.dart';
import '../widgets/pane_box.dart';

enum NavigationLevel { topMenu, accounts, configs, stats, expandedStats, settings, editingRootPath, about }

enum TopMenuItem {
  accounts('Accounts', 'Manage accounts and queue bots'),
  stats('Stats', 'Live account telemetry, currency rates & logs'),
  hotkeys('Hotkeys', 'Keyboard shortcuts & navigation'),
  settings('Settings', 'App preferences & launch parameters'),
  about('About', 'Project info & update changelog'),
  quit('Quit', 'Exit Astra Lawnchair');

  final String label;
  final String description;
  const TopMenuItem(this.label, this.description);
}

enum SettingsItem {
  client('Client Parameter', 'Toggle between Unity and Flash client mode'),
  stagger('Launch Stagger Delay', 'Pause duration between bot launches'),
  rootPath('Root Folder Path', 'Base directory containing AstraBot accounts'),
  obfuscate('Obfuscate / Streamer Mode', 'Mask account names & IP addresses for screenshots'),
  autoStart('Auto-Start Config', 'Automatically start bot execution on launch'),
  back('[< Back to Top Menu]', 'Return to top-level menu');

  final String label;
  final String description;
  const SettingsItem(this.label, this.description);
}

class MainScreen extends StatefulComponent {
  final AppConfig config;
  final ConfigService? configService;
  final ScannerService scannerService;
  final LauncherService launcherService;
  final ProcessTrackerService? processTrackerService;
  final StatTrackerService? statTrackerService;
  final List<Account> initialAccounts;

  const MainScreen({
    super.key,
    required this.config,
    this.configService,
    required this.scannerService,
    required this.launcherService,
    this.processTrackerService,
    this.statTrackerService,
    required this.initialAccounts,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AppConfig _currentConfig;
  late List<Account> _accounts;
  final List<LaunchTarget> _selectedQueue = [];

  NavigationLevel _navLevel = NavigationLevel.topMenu;
  Account? _activeAccount;

  int _focusedTopMenuIndex = 0;
  int _focusedAccountIndex = 0;
  int _focusedConfigIndex = 0;
  int _focusedSettingsIndex = 0;
  int _focusedStatsAccountIndex = 0;

  final _rootPathController = TextEditingController();
  String _settingsErrorMessage = '';

  String _statusMessage = '';
  TextStyle? _statusStyle;
  bool _isBusy = false;

  late final ProcessTrackerService _processTracker;
  late final StatTrackerService _statTracker;
  Timer? _statsPollTimer;

  bool _isObfuscated = false;

  // Chart series visibility toggles in expanded telemetry view
  bool _showChartUridium = true;
  bool _showChartCredits = true;
  bool _showChartXp = true;
  bool _showChartHonor = true;

  static const List<int> _staggerPresets = [200, 300, 400, 500, 750, 1000];

  @override
  void initState() {
    super.initState();
    _currentConfig = component.config;
    _isObfuscated = _currentConfig.obfuscateNames;
    _accounts = List.from(component.initialAccounts);
    _processTracker = component.processTrackerService ??
        ProcessTrackerService(
          baseDir: component.configService?.baseDir ?? ConfigService.defaultStorageDir(),
        );
    _statTracker = component.statTrackerService ?? StatTrackerService();
    _initProcessTracker();
    _startStatsPolling();
  }

  void _toggleObfuscation() async {
    final nextState = !_isObfuscated;
    setState(() {
      _isObfuscated = nextState;
    });
    final updated = _currentConfig.copyWith(obfuscateNames: nextState);
    await _persistConfig(updated);
    _setStatus(
      nextState
          ? 'Obfuscation: ENABLED (Account names & IP addresses masked).'
          : 'Obfuscation: DISABLED (Original names & IPs visible).',
      nextState ? LawnchairTheme.statusRunning : LawnchairTheme.statusInfo,
    );
  }

  void _toggleAutoStart() async {
    final nextState = !_currentConfig.autoStart;
    final updated = _currentConfig.copyWith(autoStart: nextState);
    await _persistConfig(updated);
    _setStatus(
      nextState
          ? 'Auto-Start: ENABLED (--auto-start will be passed on launch).'
          : 'Auto-Start: DISABLED (--auto-start omitted on launch).',
      nextState ? LawnchairTheme.statusSuccess : LawnchairTheme.statusInfo,
    );
  }

  Future<void> _initProcessTracker() async {
    await _processTracker.initAndPrune();
    if (mounted) {
      setState(() {});
    }
  }

  void _startStatsPolling() {
    _pollStats();
    _statsPollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _pollStats();
    });
  }

  int _pollCount = 0;

  Future<void> _pollStats() async {
    if (!mounted || _accounts.isEmpty) return;

    _pollCount++;
    // Periodically verify OS process liveness every ~5 poll cycles (approx 9 seconds)
    if (_pollCount % 5 == 0) {
      await _processTracker.pruneStaleSessions();
    }

    // Check stats for all accounts (especially running ones)
    for (final acc in _accounts) {
      final session = _processTracker.getSession(acc.name);
      final updatedStats = await _statTracker.updateAccount(acc, session: session);
      if (session != null) {
        await _processTracker.updateSessionStats(acc.name, updatedStats.toJson());
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _statsPollTimer?.cancel();
    _rootPathController.dispose();
    super.dispose();
  }

  void _setStatus(String msg, [TextStyle? style]) {
    setState(() {
      _statusMessage = msg;
      _statusStyle = style;
    });
  }

  void _moveFocusUp() {
    setState(() {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          if (_focusedTopMenuIndex > 0) {
            _focusedTopMenuIndex--;
          }
          break;
        case NavigationLevel.accounts:
          if (_focusedAccountIndex > 0) {
            _focusedAccountIndex--;
          }
          break;
        case NavigationLevel.configs:
          if (_focusedConfigIndex > 0) {
            _focusedConfigIndex--;
          }
          break;
        case NavigationLevel.stats:
          if (_focusedStatsAccountIndex > 0) {
            _focusedStatsAccountIndex--;
          }
          break;
        case NavigationLevel.settings:
          if (_focusedSettingsIndex > 0) {
            _focusedSettingsIndex--;
          }
          break;
        case NavigationLevel.editingRootPath:
        case NavigationLevel.about:
        case NavigationLevel.expandedStats:
          break;
      }
    });
  }

  void _moveFocusDown() {
    setState(() {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          if (_focusedTopMenuIndex < TopMenuItem.values.length - 1) {
            _focusedTopMenuIndex++;
          }
          break;
        case NavigationLevel.accounts:
          if (_focusedAccountIndex < _accounts.length - 1) {
            _focusedAccountIndex++;
          }
          break;
        case NavigationLevel.configs:
          final configs = _activeAccount?.configs ?? [];
          if (_focusedConfigIndex < configs.length - 1) {
            _focusedConfigIndex++;
          }
          break;
        case NavigationLevel.stats:
          if (_focusedStatsAccountIndex < _accounts.length - 1) {
            _focusedStatsAccountIndex++;
          }
          break;
        case NavigationLevel.settings:
          if (_focusedSettingsIndex < SettingsItem.values.length - 1) {
            _focusedSettingsIndex++;
          }
          break;
        case NavigationLevel.editingRootPath:
        case NavigationLevel.about:
        case NavigationLevel.expandedStats:
          break;
      }
    });
  }

  void _activateTopMenuItem(TopMenuItem item) {
    switch (item) {
      case TopMenuItem.accounts:
        setState(() {
          _navLevel = NavigationLevel.accounts;
          _setStatus('Accounts Menu: Press Enter to view configs, Backspace to return to Top Menu.');
        });
        break;
      case TopMenuItem.stats:
        setState(() {
          _navLevel = NavigationLevel.stats;
          _focusedStatsAccountIndex = 0;
          _pollStats();
          _setStatus('Account Stats: Press ↑/↓ to browse, Enter to expand dashboard & graphs, Backspace to return.');
        });
        break;
      case TopMenuItem.hotkeys:
        _setStatus('Viewing Hotkeys reference in right panel.');
        break;
      case TopMenuItem.settings:
        setState(() {
          _navLevel = NavigationLevel.settings;
          _focusedSettingsIndex = 0;
          _setStatus('Settings: Press Enter/Space to adjust or edit options, Backspace to go back.');
        });
        break;
      case TopMenuItem.about:
        setState(() {
          _navLevel = NavigationLevel.about;
          _setStatus('About & Changelog: Press Backspace to return to Top Menu.');
        });
        break;
      case TopMenuItem.quit:
        shutdownApp();
    }
  }

  String _getAccountDisplayName(String accountName) {
    final idx = _accounts.indexWhere((a) => a.name == accountName);
    return Obfuscator.obfuscateAccountName(
      accountName,
      index: idx >= 0 ? idx : null,
      enabled: _isObfuscated,
    );
  }

  String _getTargetDisplayName(LaunchTarget target) {
    final idx = _accounts.indexWhere((a) => a.name == target.account.name);
    return target.getDisplayName(
      obfuscated: _isObfuscated,
      accountIndex: idx >= 0 ? idx : null,
    );
  }

  void _digIntoAccount(Account account) {
    setState(() {
      _activeAccount = account;
      _navLevel = NavigationLevel.configs;
      _focusedConfigIndex = 0;
      _setStatus('Viewing configs for "${_getAccountDisplayName(account.name)}". Press Space to toggle, S to switch/reload, Backspace to return.');
    });
  }

  void _digIntoExpandedStats(Account account) {
    setState(() {
      _activeAccount = account;
      _navLevel = NavigationLevel.expandedStats;
      _pollStats();
      _setStatus('Expanded Telemetry: "${_getAccountDisplayName(account.name)}". Press Backspace to return.');
    });
  }

  void _popNavigation() {
    setState(() {
      if (_navLevel == NavigationLevel.editingRootPath) {
        _navLevel = NavigationLevel.settings;
        _settingsErrorMessage = '';
        _setStatus('Cancelled path editing.');
      } else if (_navLevel == NavigationLevel.configs) {
        _navLevel = NavigationLevel.accounts;
        _activeAccount = null;
        _setStatus('Returned to Accounts list.');
      } else if (_navLevel == NavigationLevel.expandedStats) {
        _navLevel = NavigationLevel.stats;
        _setStatus('Returned to Account Stats view.');
      } else if (_navLevel == NavigationLevel.accounts ||
          _navLevel == NavigationLevel.stats ||
          _navLevel == NavigationLevel.settings ||
          _navLevel == NavigationLevel.about) {
        _navLevel = NavigationLevel.topMenu;
        _setStatus('Returned to Top Menu.');
      }
    });
  }

  Future<void> _persistConfig(AppConfig newConfig) async {
    setState(() {
      _currentConfig = newConfig;
    });
    if (component.configService != null) {
      await component.configService!.saveConfig(newConfig);
    }
  }

  void _toggleClientMode() async {
    final nextClient = _currentConfig.clientName.toLowerCase() == 'unity' ? 'Flash' : 'Unity';
    final updated = _currentConfig.copyWith(clientName: nextClient);
    await _persistConfig(updated);
    _setStatus('Client parameter set to: $nextClient', LawnchairTheme.statusSuccess);
  }

  void _cycleStaggerDelay() async {
    final current = _currentConfig.staggerDelayMs;
    int nextDelay = _staggerPresets.first;
    for (int i = 0; i < _staggerPresets.length; i++) {
      if (_staggerPresets[i] == current) {
        nextDelay = _staggerPresets[(i + 1) % _staggerPresets.length];
        break;
      }
    }
    final updated = _currentConfig.copyWith(staggerDelayMs: nextDelay);
    await _persistConfig(updated);
    _setStatus('Launch stagger delay set to: $nextDelay ms', LawnchairTheme.statusSuccess);
  }

  void _startEditingRootPath() {
    setState(() {
      _navLevel = NavigationLevel.editingRootPath;
      _rootPathController.text = _currentConfig.rootPath;
      _settingsErrorMessage = '';
      _setStatus('Type new root directory path and press Enter to save.');
    });
  }

  Future<void> _submitRootPath() async {
    final rawPath = _rootPathController.text.trim();
    if (rawPath.isEmpty) {
      setState(() {
        _settingsErrorMessage = 'Path cannot be empty.';
      });
      return;
    }

    final dir = Directory(rawPath);
    if (!dir.existsSync()) {
      setState(() {
        _settingsErrorMessage = 'Folder does not exist: $rawPath';
      });
      return;
    }

    setState(() {
      _settingsErrorMessage = '';
      _navLevel = NavigationLevel.settings;
    });

    final updated = _currentConfig.copyWith(rootPath: dir.path);
    await _persistConfig(updated);
    _setStatus('Root path updated to: ${dir.path}', LawnchairTheme.statusSuccess);
    await _refreshFromDisk();
  }

  void _handleSettingsAction(SettingsItem item) {
    switch (item) {
      case SettingsItem.client:
        _toggleClientMode();
        break;
      case SettingsItem.stagger:
        _cycleStaggerDelay();
        break;
      case SettingsItem.rootPath:
        _startEditingRootPath();
        break;
      case SettingsItem.obfuscate:
        _toggleObfuscation();
        break;
      case SettingsItem.autoStart:
        _toggleAutoStart();
        break;
      case SettingsItem.back:
        _popNavigation();
        break;
    }
  }

  bool _isConfigSelected(Account account, String configName) {
    final target = LaunchTarget(account: account, configName: configName);
    return _selectedQueue.contains(target);
  }

  void _toggleConfigSelection(Account account, String configName) {
    final target = LaunchTarget(account: account, configName: configName);
    setState(() {
      if (_selectedQueue.contains(target)) {
        _selectedQueue.remove(target);
        _setStatus('Removed "${_getTargetDisplayName(target)}" from launch queue.');
      } else {
        _selectedQueue.add(target);
        _setStatus('Added "${_getTargetDisplayName(target)}" to launch queue.');
      }
    });
  }

  Future<void> _switchOrReloadConfig(Account account, String configName) async {
    if (_isBusy) return;

    final target = LaunchTarget(account: account, configName: configName);
    final accountDisplayName = _getAccountDisplayName(account.name);
    final existingSession = _processTracker.getSession(account.name);
    final wasRunning = existingSession != null;
    final isSameConfig = wasRunning && existingSession.configName == configName;

    setState(() {
      _isBusy = true;
      if (isSameConfig) {
        _setStatus('Reloading "$accountDisplayName" with config "$configName" (restarting bot)...', LawnchairTheme.statusInfo);
      } else if (wasRunning) {
        _setStatus('Switching "$accountDisplayName" to config "$configName" (restarting bot)...', LawnchairTheme.statusInfo);
      } else {
        _setStatus('Launching "$accountDisplayName" with config "$configName"...', LawnchairTheme.statusInfo);
      }
    });

    try {
      if (wasRunning) {
        final oldPid = existingSession.pid;
        await _processTracker.killSession(account.name);
        _statTracker.resetAccount(account.name);

        // Wait until old bot process is confirmed dead before relaunching
        int waitedMs = 0;
        while (waitedMs < 3000) {
          final alive = await _processTracker.isProcessAlive(oldPid);
          if (!alive) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          waitedMs += 100;
        }
      }

      // Sync targeted config file to config.json in account root directory
      try {
        final sourceConfigFile = File(p.join(account.folderPath, 'configs', '$configName.json'));
        if (sourceConfigFile.existsSync()) {
          final destConfigFile = File(p.join(account.folderPath, 'config.json'));
          destConfigFile.writeAsBytesSync(sourceConfigFile.readAsBytesSync());
        }
      } catch (_) {}

      final launcher = LauncherService(
        staggerDelayMs: _currentConfig.staggerDelayMs,
        clientName: _currentConfig.clientName,
        isDryRun: component.launcherService.isDryRun,
        autoStart: _currentConfig.autoStart,
      );

      final result = await launcher.launchSingle(target);

      if (result.success && result.pid != null) {
        _statTracker.resetAccount(account.name);
        await _processTracker.registerLaunch(target, result.pid!);

        setState(() {
          _isBusy = false;
          _selectedQueue.remove(target);

          if (isSameConfig) {
            _setStatus('Reloaded "$accountDisplayName" with config "$configName" (PID: ${result.pid}).', LawnchairTheme.statusSuccess);
          } else if (wasRunning) {
            _setStatus('Switched "$accountDisplayName" to config "$configName" (PID: ${result.pid}).', LawnchairTheme.statusSuccess);
          } else {
            _setStatus('Launched "$accountDisplayName" with config "$configName" (PID: ${result.pid}).', LawnchairTheme.statusSuccess);
          }
        });
      } else {
        setState(() {
          _isBusy = false;
          _setStatus('Failed to launch "$configName": ${result.errorMessage ?? "Unknown error"}', LawnchairTheme.statusError);
        });
      }
    } catch (e) {
      setState(() {
        _isBusy = false;
        _setStatus('Hot-swap failed: $e', LawnchairTheme.statusError);
      });
    }
  }

  Future<void> _refreshFromDisk() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _setStatus('Refreshing accounts and configs from disk...', LawnchairTheme.statusInfo);
    });

    try {
      final updatedAccounts = await component.scannerService.scanAndCache(_currentConfig.rootPath);
      await _processTracker.pruneStaleSessions();
      setState(() {
        _accounts = updatedAccounts;
        if (_focusedAccountIndex >= _accounts.length) {
          _focusedAccountIndex = _accounts.isEmpty ? 0 : _accounts.length - 1;
        }

        // If currently dug into an account, re-bind active account
        if (_activeAccount != null) {
          final found = _accounts.where((a) => a.name == _activeAccount!.name);
          if (found.isNotEmpty) {
            _activeAccount = found.first;
            if (_focusedConfigIndex >= _activeAccount!.configs.length) {
              _focusedConfigIndex =
                  _activeAccount!.configs.isEmpty ? 0 : _activeAccount!.configs.length - 1;
            }
          } else {
            _navLevel = NavigationLevel.accounts;
            _activeAccount = null;
          }
        }
        _isBusy = false;
        _setStatus('Refreshed ${_accounts.length} accounts from disk.', LawnchairTheme.statusSuccess);
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _setStatus('Refresh failed: $e', LawnchairTheme.statusError);
      });
    }
  }

  Future<void> _runSelected() async {
    if (_isBusy) return;
    if (_selectedQueue.isEmpty) {
      _setStatus(
        'No accounts/configs selected to run. Select configs with Space first.',
        LawnchairTheme.statusInfo,
      );
      return;
    }

    // Check which targets are already running and partition the queue
    final alreadyRunning = _selectedQueue
        .where((target) => _processTracker.isRunning(target.account.name))
        .toList();
    final toLaunch = _selectedQueue
        .where((target) => !_processTracker.isRunning(target.account.name))
        .toList();

    if (toLaunch.isEmpty) {
      setState(() {
        _selectedQueue.clear();
        _setStatus(
          'All ${alreadyRunning.length} selected account(s) are already running. Skipped launch.',
          LawnchairTheme.statusInfo,
        );
      });
      return;
    }

    setState(() {
      _isBusy = true;
      final skipNote = alreadyRunning.isNotEmpty ? ' (${alreadyRunning.length} already running skipped)' : '';
      _setStatus('Preparing to launch ${toLaunch.length} instance(s)$skipNote...', LawnchairTheme.statusInfo);
    });

    try {
      final launcher = LauncherService(
        staggerDelayMs: _currentConfig.staggerDelayMs,
        clientName: _currentConfig.clientName,
        isDryRun: component.launcherService.isDryRun,
        autoStart: _currentConfig.autoStart,
      );

      final results = await launcher.launchAll(
        toLaunch,
        onProgress: (target, current, total) {
          _setStatus('Launching [$current/$total]: "${_getTargetDisplayName(target)}"...', LawnchairTheme.statusInfo);
        },
      );

      // Register successfully launched PIDs with tracker and reset session stats
      for (final res in results) {
        if (res.success && res.pid != null) {
          _statTracker.resetAccount(res.target.account.name);
          await _processTracker.registerLaunch(res.target, res.pid!);
        }
      }

      final successCount = results.where((r) => r.success).length;
      final failCount = results.where((r) => !r.success).length;

      setState(() {
        _isBusy = false;
        // Remove successfully launched and already running targets from the queue
        final completedTargets = results.where((r) => r.success).map((r) => r.target).toSet();
        _selectedQueue.removeWhere((t) => completedTargets.contains(t) || alreadyRunning.contains(t));

        final skippedMsg = alreadyRunning.isNotEmpty ? ' (${alreadyRunning.length} already running skipped)' : '';
        if (failCount == 0) {
          _setStatus('Successfully launched $successCount bot instance(s)$skippedMsg!', LawnchairTheme.statusSuccess);
        } else {
          final firstError = results.firstWhere((r) => !r.success).errorMessage ?? 'Unknown error';
          _setStatus('Launched $successCount bots ($failCount failed)$skippedMsg. Error: $firstError', LawnchairTheme.statusError);
        }
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _setStatus('Launch process failed: $e', LawnchairTheme.statusError);
      });
    }
  }

  Future<void> _killFocusedBot() async {
    if (_isBusy) return;

    String? targetAccountName;
    if (_navLevel == NavigationLevel.accounts) {
      if (_accounts.isNotEmpty && _focusedAccountIndex < _accounts.length) {
        targetAccountName = _accounts[_focusedAccountIndex].name;
      }
    } else if (_navLevel == NavigationLevel.configs) {
      targetAccountName = _activeAccount?.name;
    }

    if (targetAccountName == null) {
      _setStatus('No account focused to terminate.', LawnchairTheme.statusInfo);
      return;
    }

    final targetDisplayName = _getAccountDisplayName(targetAccountName);
    final session = _processTracker.getSession(targetAccountName);
    if (session == null) {
      _setStatus('Account "$targetDisplayName" is not currently running.', LawnchairTheme.statusInfo);
      return;
    }

    setState(() {
      _isBusy = true;
      _setStatus('Terminating bot for "$targetDisplayName" (PID: ${session.pid})...', LawnchairTheme.statusInfo);
    });

    final killed = await _processTracker.killSession(targetAccountName);
    setState(() {
      _isBusy = false;
      if (killed) {
        _setStatus('Terminated bot for "$targetDisplayName" (PID: ${session.pid}).', LawnchairTheme.statusSuccess);
      } else {
        _setStatus('Process ${session.pid} already exited or could not be terminated.', LawnchairTheme.statusError);
      }
    });
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (_isBusy) return true;

    // Shift+R: Refresh
    if (event.isShiftPressed && event.logicalKey == LogicalKey.keyR) {
      _refreshFromDisk();
      return true;
    }

    // Q: Quit
    if (event.character?.toLowerCase() == 'q') {
      shutdownApp();
    }

    // R (without Shift): Run
    if (!event.isShiftPressed &&
        (event.character?.toUpperCase() == component.config.runHotkey.toUpperCase() ||
            event.logicalKey == LogicalKey.keyR)) {
      _runSelected();
      return true;
    }

    // K: Kill focused running bot
    if (event.character?.toLowerCase() == 'k' || event.logicalKey == LogicalKey.keyK) {
      _killFocusedBot();
      return true;
    }

    // S: Hot-swap / reload focused config or running bot session
    if (_navLevel != NavigationLevel.editingRootPath &&
        (event.character?.toLowerCase() == 's' || event.logicalKey == LogicalKey.keyS)) {
      if (_navLevel == NavigationLevel.configs) {
        final account = _activeAccount;
        if (account != null && account.configs.isNotEmpty && _focusedConfigIndex < account.configs.length) {
          final configName = account.configs[_focusedConfigIndex];
          _switchOrReloadConfig(account, configName);
        }
        return true;
      } else if (_navLevel == NavigationLevel.accounts) {
        if (_accounts.isNotEmpty && _focusedAccountIndex < _accounts.length) {
          final account = _accounts[_focusedAccountIndex];
          final queuedForAccount = _selectedQueue.where((t) => t.account.name == account.name).toList();
          if (queuedForAccount.isNotEmpty) {
            _switchOrReloadConfig(account, queuedForAccount.first.configName);
          } else {
            _digIntoAccount(account);
            _setStatus('Dig into "${_getAccountDisplayName(account.name)}": highlight the new config and press S to switch.');
          }
          return true;
        }
      }
    }

    // O: Toggle Obfuscate / Streamer Mode (unless typing in text field)
    if (_navLevel != NavigationLevel.editingRootPath &&
        (event.character?.toLowerCase() == 'o' || event.logicalKey == LogicalKey.keyO)) {
      _toggleObfuscation();
      return true;
    }

    // Number keys 1-4: Toggle chart series in expanded telemetry mode
    if (_navLevel == NavigationLevel.expandedStats) {
      if (event.character == '1' || event.logicalKey == LogicalKey.digit1) {
        setState(() {
          _showChartUridium = !_showChartUridium;
          _setStatus('Chart: Uridium series ${_showChartUridium ? "ON" : "OFF"}.');
        });
        return true;
      }
      if (event.character == '2' || event.logicalKey == LogicalKey.digit2) {
        setState(() {
          _showChartCredits = !_showChartCredits;
          _setStatus('Chart: Credits series ${_showChartCredits ? "ON" : "OFF"}.');
        });
        return true;
      }
      if (event.character == '3' || event.logicalKey == LogicalKey.digit3) {
        setState(() {
          _showChartXp = !_showChartXp;
          _setStatus('Chart: Experience series ${_showChartXp ? "ON" : "OFF"}.');
        });
        return true;
      }
      if (event.character == '4' || event.logicalKey == LogicalKey.digit4) {
        setState(() {
          _showChartHonor = !_showChartHonor;
          _setStatus('Chart: Honor series ${_showChartHonor ? "ON" : "OFF"}.');
        });
        return true;
      }
    }

    // Arrow keys
    if (event.logicalKey == LogicalKey.arrowUp) {
      _moveFocusUp();
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      _moveFocusDown();
      return true;
    }

    // Enter
    if (event.logicalKey == LogicalKey.enter) {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          _activateTopMenuItem(TopMenuItem.values[_focusedTopMenuIndex]);
          break;
        case NavigationLevel.accounts:
          if (_accounts.isNotEmpty) {
            _digIntoAccount(_accounts[_focusedAccountIndex]);
          }
          break;
        case NavigationLevel.configs:
          final account = _activeAccount;
          if (account != null && account.configs.isNotEmpty) {
            final configName = account.configs[_focusedConfigIndex];
            _toggleConfigSelection(account, configName);
          }
          break;
        case NavigationLevel.stats:
          if (_accounts.isNotEmpty && _focusedStatsAccountIndex < _accounts.length) {
            final targetAccount = _accounts[_focusedStatsAccountIndex];
            _digIntoExpandedStats(targetAccount);
          }
          break;
        case NavigationLevel.expandedStats:
          _popNavigation();
          break;
        case NavigationLevel.settings:
          _handleSettingsAction(SettingsItem.values[_focusedSettingsIndex]);
          break;
        case NavigationLevel.editingRootPath:
          _submitRootPath();
          break;
        case NavigationLevel.about:
          _popNavigation();
          break;
      }
      return true;
    }

    // Backspace: Pop back
    if (event.logicalKey == LogicalKey.backspace) {
      _popNavigation();
      return true;
    }

    // Space: Toggle selection in configs, open in accounts, or toggle setting
    if (event.logicalKey == LogicalKey.space) {
      if (_navLevel == NavigationLevel.configs) {
        final account = _activeAccount;
        if (account != null && account.configs.isNotEmpty) {
          final configName = account.configs[_focusedConfigIndex];
          _toggleConfigSelection(account, configName);
        }
      } else if (_navLevel == NavigationLevel.accounts) {
        if (_accounts.isNotEmpty) {
          _digIntoAccount(_accounts[_focusedAccountIndex]);
        }
      } else if (_navLevel == NavigationLevel.topMenu) {
        _activateTopMenuItem(TopMenuItem.values[_focusedTopMenuIndex]);
      } else if (_navLevel == NavigationLevel.settings) {
        _handleSettingsAction(SettingsItem.values[_focusedSettingsIndex]);
      } else if (_navLevel == NavigationLevel.about) {
        _popNavigation();
      }
      return true;
    }

    return false;
  }

  @override
  Component build(BuildContext context) {
    String leftPaneTitle;
    switch (_navLevel) {
      case NavigationLevel.topMenu:
        leftPaneTitle = 'MENU: Astra Lawnchair';
        break;
      case NavigationLevel.accounts:
        leftPaneTitle = 'MENU: Accounts [${_accounts.length}]';
        break;
      case NavigationLevel.configs:
        final activeName = _activeAccount != null
            ? _getAccountDisplayName(_activeAccount!.name)
            : '';
        leftPaneTitle = 'MENU: $activeName (${_activeAccount?.configs.length ?? 0} configs)';
        break;
      case NavigationLevel.stats:
        leftPaneTitle = 'TELEMETRY & STATS [${_accounts.length} Accounts]';
        break;
      case NavigationLevel.settings:
        leftPaneTitle = 'MENU: Settings';
        break;
      case NavigationLevel.editingRootPath:
        leftPaneTitle = 'SETTINGS: Edit Root Path';
        break;
      case NavigationLevel.about:
        leftPaneTitle = 'ABOUT & CHANGELOG';
        break;
      case NavigationLevel.expandedStats:
        leftPaneTitle = 'EXPANDED TELEMETRY';
        break;
    }

    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                const Text(
                  'Astra Lawnchair',
                  style: LawnchairTheme.titleStyle,
                ),
                const SizedBox(width: 2),
                if (_isObfuscated) ...[
                  const Text('[STREAMER MODE]', style: LawnchairTheme.statRate),
                  const SizedBox(width: 2),
                ],
                Text(
                  _currentConfig.rootPath.length > 35
                      ? 'Root: ...${_currentConfig.rootPath.substring(_currentConfig.rootPath.length - 32)}'
                      : 'Root: ${_currentConfig.rootPath}',
                  style: LawnchairTheme.footerDesc,
                ),
                const Spacer(),
                if (_isBusy)
                  const Text('BUSY', style: LawnchairTheme.statusInfo),
              ],
            ),
          ),
          const Divider(),

          // Main View (Full-width Single Pane for About / Expanded Stats, or Split Pane for Menus)
          Expanded(
            child: _navLevel == NavigationLevel.about
                ? PaneBox(
                    title: 'ABOUT & CHANGELOG',
                    isFocused: true,
                    child: _buildAboutContent(),
                  )
                : (_navLevel == NavigationLevel.expandedStats
                    ? PaneBox(
                        title: _expandedStatsTitle(),
                        isFocused: true,
                        child: _buildExpandedStatsContent(),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Pane: Menu Stack
                          Expanded(
                            child: PaneBox(
                              title: leftPaneTitle,
                              isFocused: true,
                              child: _buildLeftPaneContent(),
                            ),
                          ),

                          // Right Pane: Contextual (Selected Queue / Hotkeys / Settings)
                          Expanded(
                            child: _buildRightPane(),
                          ),
                        ],
                      )),
          ),

          // Footer & Status Bar
          FooterBar(
            statusMessage: _statusMessage,
            statusStyle: _statusStyle,
            runHotkey: _currentConfig.runHotkey,
            isObfuscated: _isObfuscated,
          ),
        ],
      ),
    );
  }

  Component _buildLeftPaneContent() {
    switch (_navLevel) {
      case NavigationLevel.topMenu:
        return ListView.builder(
          itemCount: TopMenuItem.values.length,
          itemBuilder: (context, index) {
            final item = TopMenuItem.values[index];
            final isFocused = index == _focusedTopMenuIndex;

            String title = item.label;
            String subtitle = item.description;

            if (item == TopMenuItem.accounts) {
              final queued = _selectedQueue.length;
              title = queued > 0
                  ? 'Accounts (${_accounts.length} accounts, $queued queued)'
                  : 'Accounts (${_accounts.length} accounts)';
            }

            return Padding(
              key: ValueKey('top_menu_${item.name}'),
              padding: const EdgeInsets.only(bottom: 1),
              child: ListItemRow(
                title: title,
                subtitle: subtitle,
                subtitleBelow: true,
                isFocused: isFocused,
                isSelected: item == TopMenuItem.accounts && _selectedQueue.isNotEmpty,
                showCheckbox: false,
                onTap: () {
                  setState(() {
                    _focusedTopMenuIndex = index;
                  });
                  _activateTopMenuItem(item);
                },
              ),
            );
          },
        );

      case NavigationLevel.accounts:
        if (_accounts.isEmpty) {
          return const Center(
            child: Text(
              'No account folders found.\nPress Shift+R to refresh or Backspace to go back.',
              style: LawnchairTheme.statusInfo,
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: _accounts.length,
          itemBuilder: (context, index) {
            final account = _accounts[index];
            final isFocused = index == _focusedAccountIndex;

            final queuedCount = _selectedQueue.where((t) => t.account.name == account.name).length;
            final isSelected = queuedCount > 0;
            final subtitle = queuedCount > 0 ? '($queuedCount queued)' : '(${account.configs.length} configs)';

            final session = _processTracker.getSession(account.name);
            final badge = session != null ? '[RUNNING: ${session.formattedUptime} | PID: ${session.pid}]' : null;

            final displayName = _getAccountDisplayName(account.name);

            return ListItemRow(
              title: displayName,
              subtitle: subtitle,
              badge: badge,
              badgeStyle: LawnchairTheme.statusRunning,
              isFocused: isFocused,
              isSelected: isSelected,
              showCheckbox: true,
              onTap: () {
                setState(() {
                  _focusedAccountIndex = index;
                });
                _digIntoAccount(account);
              },
            );
          },
        );

      case NavigationLevel.configs:
        final account = _activeAccount;
        final configs = account?.configs ?? [];

        if (configs.isEmpty) {
          return const Center(
            child: Text(
              'No .json configs found in /configs folder.\nPress Backspace to go back.',
              style: LawnchairTheme.statusInfo,
              textAlign: TextAlign.center,
            ),
          );
        }

        final activeSession = account != null ? _processTracker.getSession(account.name) : null;

        return ListView.builder(
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final configName = configs[index];
            final isFocused = index == _focusedConfigIndex;
            final isSelected = account != null && _isConfigSelected(account, configName);

            final isRunningThisConfig = activeSession != null && activeSession.configName == configName;
            final badge = isRunningThisConfig
                ? '[RUNNING: ${activeSession.formattedUptime} | PID: ${activeSession.pid}]'
                : null;

            return ListItemRow(
              title: configName,
              badge: badge,
              badgeStyle: LawnchairTheme.statusRunning,
              isFocused: isFocused,
              isSelected: isSelected,
              showCheckbox: true,
              onTap: () {
                setState(() {
                  _focusedConfigIndex = index;
                });
                if (account != null) {
                  _toggleConfigSelection(account, configName);
                }
              },
            );
          },
        );

      case NavigationLevel.stats:
        if (_accounts.isEmpty) {
          return const Center(
            child: Text(
              'No account folders found.\nPress Backspace to go back.',
              style: LawnchairTheme.statusInfo,
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: _accounts.length,
          itemBuilder: (context, index) {
            final account = _accounts[index];
            final isFocused = index == _focusedStatsAccountIndex;
            final stats = _statTracker.getStats(account.name);
            final session = _processTracker.getSession(account.name);

            final isRunning = session != null;
            final badge = isRunning
                ? '[RUNNING: ${session.formattedUptime} | PID: ${session.pid}]'
                : '[STOPPED]';
            final badgeStyle = isRunning
                ? LawnchairTheme.statusRunning
                : LawnchairTheme.footerDesc;

            String subtitle;
            if (stats != null) {
              final uriFormatted = NumberFormatter.formatNumber(stats.uridium);
              final uriRate = NumberFormatter.formatRate(stats.uridiumPerHour);
              final deathsFormatted = NumberFormatter.formatNumber(stats.deathCount);
              subtitle = 'URI: +$uriFormatted (+$uriRate/h) | Deaths: $deathsFormatted | ${stats.currentMap}';
            } else {
              subtitle = 'No telemetry data loaded yet';
            }

            final displayName = _getAccountDisplayName(account.name);

            return ListItemRow(
              title: displayName,
              subtitle: subtitle,
              subtitleBelow: true,
              badge: badge,
              badgeStyle: badgeStyle,
              isFocused: isFocused,
              showCheckbox: false,
              onTap: () {
                setState(() {
                  _focusedStatsAccountIndex = index;
                });
              },
            );
          },
        );

      case NavigationLevel.settings:
        return ListView.builder(
          itemCount: SettingsItem.values.length,
          itemBuilder: (context, index) {
            final item = SettingsItem.values[index];
            final isFocused = index == _focusedSettingsIndex;

            String subtitle;
            switch (item) {
              case SettingsItem.client:
                subtitle = 'Active: ${_currentConfig.clientName}';
                break;
              case SettingsItem.stagger:
                subtitle = 'Active: ${_currentConfig.staggerDelayMs} ms';
                break;
              case SettingsItem.rootPath:
                subtitle = _currentConfig.rootPath;
                break;
              case SettingsItem.obfuscate:
                subtitle = _isObfuscated ? 'Active: ON' : 'Active: OFF';
                break;
              case SettingsItem.autoStart:
                subtitle = _currentConfig.autoStart ? 'Active: ON' : 'Active: OFF';
                break;
              case SettingsItem.back:
                subtitle = 'Return to top-level menu';
                break;
            }

            return Padding(
              key: ValueKey('setting_pad_${item.name}_${_currentConfig.clientName}_${_currentConfig.staggerDelayMs}_${_isObfuscated}_${_currentConfig.autoStart}'),
              padding: const EdgeInsets.only(bottom: 1),
              child: ListItemRow(
                key: ValueKey('setting_row_${item.name}_${_currentConfig.clientName}_${_currentConfig.staggerDelayMs}_${_isObfuscated}_${_currentConfig.autoStart}'),
                title: item.label,
                subtitle: subtitle,
                subtitleBelow: true,
                isFocused: isFocused,
                showCheckbox: false,
                onTap: () {
                  setState(() {
                    _focusedSettingsIndex = index;
                  });
                  _handleSettingsAction(item);
                },
              ),
            );
          },
        );

      case NavigationLevel.editingRootPath:
        return Container(
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter new AstraBot root folder path:', style: LawnchairTheme.titleStyle),
              const SizedBox(height: 1),
              TextField(
                controller: _rootPathController,
                focused: true,
                decoration: InputDecoration(
                  border: BoxBorder.all(color: Colors.cyan),
                  hintText: 'e.g. E:\\darkorbit\\AstraBot',
                ),
                onSubmitted: (_) => _submitRootPath(),
              ),
              const SizedBox(height: 1),
              if (_settingsErrorMessage.isNotEmpty)
                Text(_settingsErrorMessage, style: LawnchairTheme.statusError),
              const SizedBox(height: 1),
              const Text(
                'Press Enter to validate & scan | Backspace to cancel',
                style: LawnchairTheme.footerDesc,
              ),
            ],
          ),
        );

      case NavigationLevel.about:
      case NavigationLevel.expandedStats:
        return const SizedBox();
    }
  }

  Component _buildRightPane() {
    // If on Top Menu and focused on Hotkeys, show Hotkeys reference
    if (_navLevel == NavigationLevel.topMenu) {
      final activeItem = TopMenuItem.values[_focusedTopMenuIndex];
      if (activeItem == TopMenuItem.hotkeys) {
        return PaneBox(
          title: 'HOTKEYS REFERENCE',
          isFocused: false,
          child: _buildHotkeysContent(),
        );
      } else if (activeItem == TopMenuItem.settings) {
        return PaneBox(
          title: 'SETTINGS & CONFIGURATION',
          isFocused: false,
          child: _buildSettingsContent(),
        );
      } else if (activeItem == TopMenuItem.about) {
        return PaneBox(
          title: 'ABOUT & CHANGELOG SUMMARY',
          isFocused: false,
          child: _buildAboutPreviewContent(),
        );
      } else if (activeItem == TopMenuItem.stats) {
        final focusedAccount = _accounts.isNotEmpty && _focusedStatsAccountIndex < _accounts.length
            ? _accounts[_focusedStatsAccountIndex]
            : (_accounts.isNotEmpty ? _accounts.first : null);
        final titleName = focusedAccount != null ? _getAccountDisplayName(focusedAccount.name) : '';
        return PaneBox(
          title: focusedAccount != null ? 'ACCOUNT STATS: $titleName' : 'ACCOUNT STATS',
          isFocused: false,
          child: _buildAccountStatsDetails(focusedAccount),
        );
      }
    } else if (_navLevel == NavigationLevel.stats) {
      final focusedAccount = _accounts.isNotEmpty && _focusedStatsAccountIndex < _accounts.length
          ? _accounts[_focusedStatsAccountIndex]
          : null;
      final titleName = focusedAccount != null ? _getAccountDisplayName(focusedAccount.name) : '';
      return PaneBox(
        title: focusedAccount != null ? 'ACCOUNT STATS: $titleName' : 'ACCOUNT STATS',
        isFocused: false,
        child: _buildAccountStatsDetails(focusedAccount),
      );
    } else if (_navLevel == NavigationLevel.settings || _navLevel == NavigationLevel.editingRootPath) {
      return PaneBox(
        title: 'SETTINGS & CONFIGURATION',
        isFocused: false,
        child: _buildSettingsContent(),
      );
    }

    // Check if currently focused account/config has an active running bot
    RunningSession? activeSession;
    if (_navLevel == NavigationLevel.accounts && _accounts.isNotEmpty && _focusedAccountIndex < _accounts.length) {
      activeSession = _processTracker.getSession(_accounts[_focusedAccountIndex].name);
    } else if (_navLevel == NavigationLevel.configs && _activeAccount != null) {
      activeSession = _processTracker.getSession(_activeAccount!.name);
    }

    if (activeSession != null) {
      return PaneBox(
        title: 'RUNNING BOT STATUS [PID: ${activeSession.pid}]',
        isFocused: false,
        child: _buildRunningSessionContent(activeSession),
      );
    }

    // Default right pane: Launch Queue
    return PaneBox(
      title: 'SELECTED (queued to launch) [${_selectedQueue.length}]',
      isFocused: false,
      child: _buildQueueContent(),
    );
  }

  Component _buildQueueContent() {
    if (_selectedQueue.isEmpty) {
      return const Center(
        child: Text(
          'Launch queue is empty.\nDig into Accounts and select configs with Space.',
          style: LawnchairTheme.footerDesc,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _selectedQueue.length,
      itemBuilder: (context, index) {
        final target = _selectedQueue[index];
        final session = _processTracker.getSession(target.account.name);
        final badge = session != null ? '[RUNNING: ${session.formattedUptime} | PID: ${session.pid}]' : null;

        final displayName = _getAccountDisplayName(target.account.name);

        return ListItemRow(
          title: displayName,
          subtitle: '— "${target.configName}"',
          badge: badge,
          badgeStyle: LawnchairTheme.statusRunning,
          isFocused: false,
          isSelected: true,
          showCheckbox: true,
          onTap: () {
            setState(() {
              _selectedQueue.removeAt(index);
              _setStatus('Removed "${_getTargetDisplayName(target)}" from queue.');
            });
          },
        );
      },
    );
  }

  Component _buildHotkeysContent() {
    return Container(
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Navigation Controls:', style: LawnchairTheme.titleStyle),
            const SizedBox(height: 1),
            _hotkeyRow('↑ / ↓', 'Move focus cursor up or down'),
            _hotkeyRow('Enter', 'Open menu item / Dig into account / Toggle config'),
            _hotkeyRow('Space', 'Toggle config into / out of launch queue'),
            _hotkeyRow('Backspace', 'Return to previous level (Configs -> Accounts -> Top Menu)'),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text('Global Actions:', style: LawnchairTheme.titleStyle),
            const SizedBox(height: 1),
            _hotkeyRow('R', 'Launch all queued accounts sequentially'),
            _hotkeyRow('S', 'Hot-swap or reload focused config for bot instantly'),
            _hotkeyRow('K', 'Kill / Terminate focused running bot process'),
            _hotkeyRow('O', 'Toggle Obfuscate / Streamer Mode (mask names & IPs)'),
            _hotkeyRow('Shift+R', 'Re-scan root directory and refresh cached configs'),
            _hotkeyRow('Q', 'Quit Astra Lawnchair from anywhere'),
            _hotkeyRow('Mouse Tap', 'Click any row to focus, open, or toggle'),
          ],
        ),
      ),
    );
  }

  Component _buildSettingsContent() {
    return Container(
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Current Settings:', style: LawnchairTheme.titleStyle),
            const SizedBox(height: 1),
            _settingRow('Root Path', _currentConfig.rootPath),
            _settingRow('Configs Storage', 'configs/ (JSON caches and settings)'),
            _settingRow('Launch Stagger', '${_currentConfig.staggerDelayMs} ms'),
            _settingRow('Client Parameter', _currentConfig.clientName),
            _settingRow('Run Hotkey', _currentConfig.runHotkey),
            _settingRow('Obfuscate Mode', _isObfuscated ? 'Enabled (ON)' : 'Disabled (OFF)'),
            _settingRow('Auto-Start Bot', _currentConfig.autoStart ? 'Enabled (ON: --auto-start)' : 'Disabled (OFF)'),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Press Enter on "Settings" in the main menu to edit these values interactively.',
              style: LawnchairTheme.footerDesc,
            ),
          ],
        ),
      ),
    );
  }

  Component _buildAboutPreviewContent() {
    return Container(
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Text('Astra Lawnchair ', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                Text('v0.1.4', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('by Joshh3ro', style: LawnchairTheme.footerDesc),
              ],
            ),
            const SizedBox(height: 1),
            const Text(
              'Terminal Launcher & Telemetry Dashboard for AstraBot',
              style: LawnchairTheme.itemNormal,
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Latest Updates (v0.1.4):',
              style: LawnchairTheme.statSectionHeader,
            ),
            const SizedBox(height: 1),
            _changelogPreviewBullet('Full-Screen Expanded Stats', 'ASCII graphs & multi-column loot breakdown'),
            _changelogPreviewBullet('Horizontal Velocity Meters', 'Clear proportional currency & velocity bars'),
            _changelogPreviewBullet('Interactive Graph Toggles', 'Keys [1-4] toggle currency visibility live'),
            _changelogPreviewBullet('Loot Categorization', 'Trinity, ammo, resources & minerals sorted'),
            _changelogPreviewBullet('Auto-Start Bot Support', 'AstraBot execution via --auto-start config'),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Recent Release History:',
              style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 1),
            _changelogPreviewBullet('v0.1.3', 'About changelog tab, duplicate bot filter, Streamer mode'),
            _changelogPreviewBullet('v0.1.2', 'Live account telemetry, incremental log reader, kill hotkey'),
            _changelogPreviewBullet('v0.1.1', 'Settings editor, process tracking, stagger delays'),
            const SizedBox(height: 1),
            const Text(
              'Press Enter on "About" to view the full changelog.',
              style: LawnchairTheme.footerDesc,
            ),
          ],
        ),
      ),
    );
  }

  Component _changelogPreviewBullet(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('• ', style: LawnchairTheme.footerKey),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(desc, style: LawnchairTheme.footerDesc),
          ),
        ],
      ),
    );
  }

  Component _hotkeyRow(String key, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Container(
            width: 14,
            child: Text(key, style: LawnchairTheme.footerKey),
          ),
          Expanded(
            child: Text(desc, style: LawnchairTheme.itemNormal),
          ),
        ],
      ),
    );
  }

  Component _settingRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label:', style: LawnchairTheme.footerKey),
          Text(value, style: LawnchairTheme.itemNormal),
        ],
      ),
    );
  }

  Component _buildRunningSessionContent(RunningSession session) {
    final accountDisplayName = _getAccountDisplayName(session.accountName);

    return Container(
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Active Process Information:', style: LawnchairTheme.titleStyle),
            const SizedBox(height: 1),
            _settingRow('Account', accountDisplayName),
            _settingRow('Config Name', session.configName),
            _settingRow('Process ID (PID)', '${session.pid}'),
            _settingRow('Uptime', session.formattedUptime),
            _settingRow('Started At', session.startTime.toLocal().toString().split('.').first),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Process Management:',
              style: LawnchairTheme.titleStyle,
            ),
            const SizedBox(height: 1),
            _hotkeyRow('S', 'Hot-swap or reload running config instantly'),
            _hotkeyRow('K', 'Terminate this bot process (kill tree)'),
            const SizedBox(height: 1),
            const Text(
              'Press S to hot-swap/reload, or K while focused on this account to stop the bot and free resources.',
              style: LawnchairTheme.footerDesc,
            ),
          ],
        ),
      ),
    );
  }

  Component _buildAccountStatsDetails(Account? account) {
    if (account == null) {
      return const Center(
        child: Text(
          'No account selected for stats.',
          style: LawnchairTheme.footerDesc,
          textAlign: TextAlign.center,
        ),
      );
    }

    final stats = _statTracker.getStats(account.name);
    final session = _processTracker.getSession(account.name);

    final isRunning = session != null;
    final statusText = isRunning ? 'RUNNING (PID: ${session.pid})' : 'STOPPED';
    final statusColor = isRunning ? LawnchairTheme.statusRunning : LawnchairTheme.footerDesc;

    final uriFormatted = NumberFormatter.formatNumber(stats?.uridium ?? 0);
    final credFormatted = NumberFormatter.formatNumber(stats?.credits ?? 0);
    final xpFormatted = NumberFormatter.formatNumber(stats?.experience ?? 0);
    final honorFormatted = NumberFormatter.formatNumber(stats?.honor ?? 0);

    final uriRate = NumberFormatter.formatRate(stats?.uridiumPerHour ?? 0.0);
    final credRate = NumberFormatter.formatRate(stats?.creditsPerHour ?? 0.0);
    final xpRate = NumberFormatter.formatRate(stats?.experiencePerHour ?? 0.0);
    final honorRate = NumberFormatter.formatRate(stats?.honorPerHour ?? 0.0);

    final items = stats?.itemsGained ?? {};
    final maskedProxyIp = Obfuscator.obfuscateIp(stats?.activeProxyIp, enabled: _isObfuscated);

    return Container(
      padding: const EdgeInsets.all(1),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Bot State & Session
            const Text('Session & Health:', style: LawnchairTheme.statSectionHeader),
            Row(
              children: [
                const SizedBox(width: 16, child: Text('Status:', style: LawnchairTheme.footerKey)),
                Text(statusText, style: statusColor),
              ],
            ),
            _statRow('Uptime', stats?.formattedUptime ?? (session?.formattedUptime ?? '0s')),
            _statRow('Current Map', stats?.currentMap ?? 'Unknown'),
            _statRow('Bot State', stats?.botState ?? (isRunning ? 'Running' : 'Offline')),
            if (maskedProxyIp != null) _statRow('Proxy IP', maskedProxyIp),
            if (stats?.lastError != null) ...[
              Text('Last Warning/Error:', style: LawnchairTheme.statDeathWarning),
              Text(stats!.lastError!, style: LawnchairTheme.statusError),
            ],
            const Divider(),

            // Section 2: Core Currencies & Hourly Rates
            const Text('Currency Earnings & Hourly Rates:', style: LawnchairTheme.statSectionHeader),
            _statRow('Uridium', '+$uriFormatted', '+$uriRate/hr'),
            _statRow('Credits', '+$credFormatted', '+$credRate/hr'),
            _statRow('Experience', '+$xpFormatted', '+$xpRate/hr'),
            _statRow('Honor', '+$honorFormatted', '+$honorRate/hr'),
            const Divider(),

            // Section 3: Survivability & Deaths
            const Text('Combat & Survivability:', style: LawnchairTheme.statSectionHeader),
            _statRow('Total Deaths', NumberFormatter.formatNumber(stats?.deathCount ?? 0)),
            if (stats?.lastKiller != null) _statRow('Last Killer', stats!.lastKiller!),
            if (stats?.lastDeathMap != null) _statRow('Death Map', stats!.lastDeathMap!),
            _statRow('Last Death', stats?.formattedTimeSinceLastDeath ?? 'None'),
            const Divider(),

            // Section 4: Loot & Special Items
            const Text('Items & Materials Collected:', style: LawnchairTheme.statSectionHeader),
            if (items.isEmpty)
              const Text('No special items collected in this session yet.', style: LawnchairTheme.footerDesc)
            else ...[
              for (final (index, catEntry) in ItemClassifier.categorizeItems(items).entries.indexed) ...[
                if (index > 0) const Divider(),
                Text('• ${catEntry.key.label}:', style: LawnchairTheme.statSubSectionHeader),
                for (final itemEntry in catEntry.value.entries)
                  _statRow(itemEntry.key, '+${NumberFormatter.formatNumber(itemEntry.value)}'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _expandedStatsTitle() {
    final account = _activeAccount;
    if (account == null) return 'EXPANDED TELEMETRY';
    final displayName = _getAccountDisplayName(account.name);
    return 'EXPANDED TELEMETRY & LIVE CHARTS: $displayName';
  }

  Component _buildExpandedStatsContent() {
    final account = _activeAccount;
    if (account == null) {
      return const Center(
        child: Text(
          'No account selected. Press Backspace to return.',
          style: LawnchairTheme.footerDesc,
          textAlign: TextAlign.center,
        ),
      );
    }

    final stats = _statTracker.getStats(account.name);
    final session = _processTracker.getSession(account.name);
    final isRunning = session != null;
    final statusText = isRunning ? 'RUNNING (PID: ${session.pid})' : 'STOPPED';
    final statusColor = isRunning ? LawnchairTheme.statusRunning : LawnchairTheme.footerDesc;

    final uriFormatted = NumberFormatter.formatNumber(stats?.uridium ?? 0);
    final credFormatted = NumberFormatter.formatNumber(stats?.credits ?? 0);
    final xpFormatted = NumberFormatter.formatNumber(stats?.experience ?? 0);
    final honorFormatted = NumberFormatter.formatNumber(stats?.honor ?? 0);

    final uriRate = NumberFormatter.formatRate(stats?.uridiumPerHour ?? 0.0);
    final credRate = NumberFormatter.formatRate(stats?.creditsPerHour ?? 0.0);
    final xpRate = NumberFormatter.formatRate(stats?.experiencePerHour ?? 0.0);
    final honorRate = NumberFormatter.formatRate(stats?.honorPerHour ?? 0.0);

    final history = stats?.currencyHistory ?? [];
    final uriSeries = history.map((s) => s.uridium).toList();
    final credSeries = history.map((s) => s.credits).toList();
    final xpSeries = history.map((s) => s.experience).toList();
    final honorSeries = history.map((s) => s.honor).toList();

    // Fallback single data point if no history exists yet
    if (uriSeries.isEmpty) uriSeries.add(stats?.uridium ?? 0);
    if (credSeries.isEmpty) credSeries.add(stats?.credits ?? 0);
    if (xpSeries.isEmpty) xpSeries.add(stats?.experience ?? 0);
    if (honorSeries.isEmpty) honorSeries.add(stats?.honor ?? 0);

    final items = stats?.itemsGained ?? {};
    final categorized = ItemClassifier.categorizeItems(items);

    final ammoItems = (categorized[ItemCategory.ammo] ?? {}).entries.toList();
    final resourceItems = (categorized[ItemCategory.resource] ?? {}).entries.toList();
    final trinityItems = (categorized[ItemCategory.trinity] ?? {}).entries.toList();
    final otherItems = (categorized[ItemCategory.other] ?? {}).entries.toList();

    final combinedOther = [...trinityItems, ...otherItems];

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Summary Bar
            Row(
              children: [
                const Text('Status: ', style: LawnchairTheme.footerKey),
                Text(statusText, style: statusColor),
                const SizedBox(width: 2),
                const Text('Uptime: ', style: LawnchairTheme.footerKey),
                Text(
                  stats?.formattedUptime ?? (session?.formattedUptime ?? '0s'),
                  style: LawnchairTheme.statValueHighlight,
                ),
                const SizedBox(width: 2),
                const Text('Map: ', style: LawnchairTheme.footerKey),
                Text(stats?.currentMap ?? 'Unknown', style: LawnchairTheme.statValueHighlight),
                const SizedBox(width: 2),
                const Text('Deaths: ', style: LawnchairTheme.footerKey),
                Text(
                  NumberFormatter.formatNumber(stats?.deathCount ?? 0),
                  style: (stats?.deathCount ?? 0) > 0 ? LawnchairTheme.statDeathWarning : LawnchairTheme.statValueHighlight,
                ),
                const Spacer(),
                const Text('[Backspace: Return to Stats]', style: LawnchairTheme.footerDesc),
              ],
            ),
            const Divider(),

            // Section: Unified Live Currency & Progression Chart
            AsciiChart(
              title: 'LIVE PROGRESSION GRAPH',
              height: 4,
              series: [
                ChartSeries(
                  id: 'uridium',
                  label: 'Uridium',
                  values: uriSeries,
                  color: Colors.cyan,
                  currentFormatted: '+$uriFormatted',
                  rateFormatted: '+$uriRate/h',
                  isVisible: _showChartUridium,
                ),
                ChartSeries(
                  id: 'credits',
                  label: 'Credits',
                  values: credSeries,
                  color: Colors.yellow,
                  currentFormatted: '+$credFormatted',
                  rateFormatted: '+$credRate/h',
                  isVisible: _showChartCredits,
                ),
                ChartSeries(
                  id: 'xp',
                  label: 'Experience',
                  values: xpSeries,
                  color: Colors.magenta,
                  currentFormatted: '+$xpFormatted',
                  rateFormatted: '+$xpRate/h',
                  isVisible: _showChartXp,
                ),
                ChartSeries(
                  id: 'honor',
                  label: 'Honor',
                  values: honorSeries,
                  color: Colors.green,
                  currentFormatted: '+$honorFormatted',
                  rateFormatted: '+$honorRate/h',
                  isVisible: _showChartHonor,
                ),
              ],
            ),
            const SizedBox(height: 1),
            const Divider(),

            // Section: Categorized Loot Columns
            // [Ammo & rockets], [Resources], [Other]
            const Text('COLLECTED REWARDS & MATERIALS:', style: LawnchairTheme.statSectionHeader),
            const SizedBox(height: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1: Ammo & Rockets
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.all(color: LawnchairTheme.borderNormal),
                    ),
                    padding: const EdgeInsets.all(1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Ammunition & Rockets',
                          style: LawnchairTheme.statSubSectionHeader,
                        ),
                        const Divider(),
                        if (ammoItems.isEmpty)
                          const Text('None collected', style: LawnchairTheme.footerDesc)
                        else
                          for (final entry in ammoItems)
                            _statRow(entry.key, '+${NumberFormatter.formatNumber(entry.value)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 1),

                // Column 2: Resources & Minerals
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.all(color: LawnchairTheme.borderNormal),
                    ),
                    padding: const EdgeInsets.all(1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Resources & Minerals',
                          style: LawnchairTheme.statSubSectionHeader,
                        ),
                        const Divider(),
                        if (resourceItems.isEmpty)
                          const Text('None collected', style: LawnchairTheme.footerDesc)
                        else
                          for (final entry in resourceItems)
                            _statRow(entry.key, '+${NumberFormatter.formatNumber(entry.value)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 1),

                // Column 3: Trinity Trials & Other Items
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: BoxBorder.all(color: LawnchairTheme.borderNormal),
                    ),
                    padding: const EdgeInsets.all(1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Trinity & Other',
                          style: LawnchairTheme.statSubSectionHeader,
                        ),
                        const Divider(),
                        if (combinedOther.isEmpty)
                          const Text('None collected', style: LawnchairTheme.footerDesc)
                        else
                          for (final entry in combinedOther)
                            _statRow(entry.key, '+${NumberFormatter.formatNumber(entry.value)}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
          ],
        ),
      ),
    );
  }

  Component _statRow(String label, String value, [String? rate]) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text('$label:', style: LawnchairTheme.footerKey),
        ),
        Text(value, style: LawnchairTheme.statValueHighlight),
        if (rate != null) ...[
          const SizedBox(width: 2),
          Text('($rate)', style: LawnchairTheme.statRate),
        ],
      ],
    );
  }

  Component _buildAboutContent() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 1),
            // Header Banner
            const Text(
              'A S T R A   L A W N C H A I R',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Text(
              'A fast, keyboard-driven Terminal Launcher & Telemetry Dashboard for AstraBot',
              style: LawnchairTheme.itemNormal,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Text(
              'Version 0.1.4 | Created by Joshh3ro | Built with Nocterm',
              style: LawnchairTheme.footerDesc,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Text(
              'Repository: https://github.com/Joshh3ro/astra_lawnchair',
              style: LawnchairTheme.footerKey,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),

            // Changelog Section Title
            const Text(
              'UPDATE CHANGELOG & RELEASE NOTES',
              style: TextStyle(
                color: Colors.yellow,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Text(
              'Track recent enhancements, fixes, and architectural revisions directly in the TUI.',
              style: LawnchairTheme.footerDesc,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),

            // Release V0.1.4 A
            _aboutReleaseCard(
              version: 'V0.1.4 A (Latest Update)',
              date: '2026-09-13',
              highlights: [
                'Full-Screen Expanded Telemetry & ASCII Charts: Press Enter on any account in Stats view to open a full-screen dashboard featuring live progression charts (Uridium, Credits, XP, Honor) and a multi-column loot breakdown.',
                'Categorized Rewards & Loot Tables: Telemetry loot drops are now cleanly organized into specialized categories (Trinity Trials & Gear, Ammunition & Rockets, Resources & Minerals, and Other Items) with alphabetical sorting.',
                'Auto-Start Launch Parameter (--auto-start): Added launch argument support instructing AstraBot instances to automatically run their assigned configuration upon startup.',
                'Interactive Auto-Start Settings Toggle: Real-time toggle in Settings menu (Space/Enter) with instant persistence to lawnchair_config.json and live right-pane inspector display.',
                'Complete Streamer Mode Anonymization: Guaranteed zero account leaks across all views, breadcrumbs, queue operations, launch progress, and process termination.',
              ],
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),

            // Release V0.1.3 A
            _aboutReleaseCard(
              version: 'V0.1.3 A',
              date: '2026-09-13',
              highlights: [
                'About & In-App Changelog Viewer: Dedicated full-width TUI changelog tab to keep operators informed directly inside the terminal without checking GitHub.',
                'Duplicate Bot Launch Prevention: Automatically verifies OS process liveness before launch. Skips already-running bots while launching only inactive accounts sequentially.',
                'Streamer & Obfuscation Mode: Global \'O\' hotkey and Settings option to anonymize account names (Account #1, Account #2) and completely mask proxy IP addresses (***.***.***.***).',
                'Preserved Session Telemetry: Retained live running session visibility, PID badges, and stat dashboards while obfuscation mode is enabled.',
                'Statistical Number Grouping & Compression: Standard dot thousands formatting (1.000, 10.000) with automatic space-saving compression for high magnitudes (1.11B, 1.5T).',
                'Single-Line Header Optimization: Truncates deep root paths with ellipsis to guarantee clean single-line header row rendering on narrow terminals.',
              ],
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),

            // Release V0.1.2 A
            _aboutReleaseCard(
              version: 'V0.1.2 A',
              date: '2026-09-12',
              highlights: [
                'Real-Time Account Telemetry & Stats: Dedicated \'Stats\' view with live dual-pane dashboard tracking session uptime, map, bot state, currencies, and special drops.',
                'High-Efficiency Incremental Log Reader: Non-blocking byte-offset seeking parser (StatTrackerService) reading only newly appended bytes without disk bottlenecks.',
                'Live Hourly Gain Velocities: Real-time rate calculation for Uridium/hr, Credits/hr, XP/hr, and Honor/hr.',
                'Combat & Survivability Tracking: Destruction counter, enemy killer identifier, death map, and elapsed time since last destruction.',
                'Session-Aware Correlation: Filters log timestamps matching active session start time to prevent stale historical log contamination.',
                'Persistent Session Recovery: Probes OS PID liveness on app boot via tasklist/kill(0) to resume tracking running bots without losing uptime continuity.',
                'Clean Terminal Teardown: Uses Nocterm shutdownApp() across all quit paths to completely restore alternate screen buffers and cursor visibility.',
              ],
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),

            // Release V0.1.1 A
            _aboutReleaseCard(
              version: 'V0.1.1 A',
              date: '2026-09-11',
              highlights: [
                'Hierarchical TUI Navigation: Revamped menu structure (Accounts, Stats, Hotkeys, Settings, Quit) with dig-in account configuration staging.',
                'Interactive Settings Editor: In-app controls to adjust launch stagger delay (200-1000ms), client parameter (Unity/Flash), and root scan directory.',
                'Process Tracking & PID Management: Detached process launch tracking, running badges, and \'K\' hotkey for clean process tree termination via taskkill.',
                'Interactive Hyperlinks: Clickable footer repository link utilizing OSC 8 terminal escape sequences.',
              ],
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),

            // Release V0.1.0 A
            _aboutReleaseCard(
              version: 'V0.1.0 A',
              date: '2026-09-09',
              highlights: [
                'Initial Release: Multi-account discovery, configuration scanning, and staggered batch launching.',
              ],
            ),
            const SizedBox(height: 2),

            // Navigation Return Hint
            const Text(
              'Press Backspace (or Enter / Space) to return to Top Menu',
              style: TextStyle(
                color: Colors.cyan,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
          ],
        ),
      ),
    );
  }

  Component _aboutReleaseCard({
    required String version,
    required String date,
    required List<String> highlights,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '• $version •',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Text('[$date]', style: LawnchairTheme.footerDesc),
          ],
        ),
        const SizedBox(height: 1),
        for (final item in highlights)
          Container(
            margin: const EdgeInsets.only(bottom: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  - ', style: LawnchairTheme.footerKey),
                Expanded(
                  child: Text(item, style: LawnchairTheme.itemNormal),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
