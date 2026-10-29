import 'dart:async';
import '../src/models/account.dart';
import '../src/models/launch_target.dart';
import '../src/models/running_session.dart';
import '../src/services/launcher_service.dart';
import '../src/services/process_tracker_service.dart';
import '../src/services/stat_tracker_service.dart';

/// High-level API for launching, hot-swapping, tracking, and terminating AstraBot instances.
class BotApi {
  final LauncherService _launcherService;
  final ProcessTrackerService _processTracker;
  final StatTrackerService? _statTracker;

  BotApi({
    required this._launcherService,
    required this._processTracker,
    this._statTracker,
  });

  /// The underlying [LauncherService].
  LauncherService get launcher => _launcherService;

  /// The underlying [ProcessTrackerService].
  ProcessTrackerService get tracker => _processTracker;

  /// Retrieves active running sessions, optionally pruning dead processes if [refresh] is true.
  Future<List<RunningSession>> getRunningSessions({bool refresh = false}) async {
    if (refresh) {
      await _processTracker.pruneStaleSessions();
    }
    return _processTracker.activeSessions.values.toList();
  }

  /// Checks if a given account is currently running.
  bool isRunning(String accountName) => _processTracker.isRunning(accountName);

  /// Returns the [RunningSession] for [accountName] if active, otherwise null.
  RunningSession? getSession(String accountName) => _processTracker.getSession(accountName);

  /// Launches a single bot instance for the given [account] and [configName].
  Future<LaunchResult> launch(
    Account account, {
    String? configName,
    String? clientName,
    bool? isDryRun,
    bool? autoStart,
  }) async {
    final effectiveConfig = configName ?? (account.configs.isNotEmpty ? account.configs.first : 'Default');
    final target = LaunchTarget(account: account, configName: effectiveConfig);

    final launcher = (clientName != null || isDryRun != null || autoStart != null)
        ? LauncherService(
            staggerDelayMs: _launcherService.staggerDelayMs,
            clientName: clientName ?? _launcherService.clientName,
            isDryRun: isDryRun ?? _launcherService.isDryRun,
            autoStart: autoStart ?? _launcherService.autoStart,
          )
        : _launcherService;

    final result = await launcher.launchSingle(target);
    if (result.success && result.pid != null) {
      _statTracker?.resetAccount(account.name);
      await _processTracker.registerLaunch(target, result.pid!);
    }
    return result;
  }

  /// Launches a queue of [LaunchTarget]s sequentially with stagger delays.
  Future<List<LaunchResult>> launchQueue(
    List<LaunchTarget> queue, {
    int? staggerDelayMs,
    String? clientName,
    bool? isDryRun,
    bool? autoStart,
    void Function(LaunchTarget target, int index, int total)? onProgress,
  }) async {
    final launcher = LauncherService(
      staggerDelayMs: staggerDelayMs ?? _launcherService.staggerDelayMs,
      clientName: clientName ?? _launcherService.clientName,
      isDryRun: isDryRun ?? _launcherService.isDryRun,
      autoStart: autoStart ?? _launcherService.autoStart,
    );

    final results = <LaunchResult>[];
    for (var i = 0; i < queue.length; i++) {
      final target = queue[i];
      onProgress?.call(target, i + 1, queue.length);

      final result = await launcher.launchSingle(target);
      results.add(result);

      if (result.success && result.pid != null) {
        _statTracker?.resetAccount(target.account.name);
        await _processTracker.registerLaunch(target, result.pid!);
      }

      if (i < queue.length - 1 && launcher.staggerDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: launcher.staggerDelayMs));
      }
    }

    return results;
  }

  /// In-place hot-swap: terminates any existing session for [account] and re-launches with [configName].
  Future<LaunchResult> hotSwap({
    required Account account,
    required String configName,
    String? clientName,
    bool? isDryRun,
    bool? autoStart,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final existing = getSession(account.name);
    if (existing != null) {
      final oldPid = existing.pid;
      await _processTracker.killSession(account.name);
      _statTracker?.resetAccount(account.name);

      // Wait for process termination
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final alive = await _processTracker.isProcessAlive(oldPid);
        if (!alive) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return launch(
      account,
      configName: configName,
      clientName: clientName,
      isDryRun: isDryRun,
      autoStart: autoStart,
    );
  }

  /// Terminates the running bot process for [accountName].
  Future<bool> kill(String accountName) => _processTracker.killSession(accountName);

  /// Terminates all currently active bot sessions. Returns the count of terminated bots.
  Future<int> killAll() async {
    final active = List<RunningSession>.from(_processTracker.activeSessions.values);
    int killed = 0;
    for (final session in active) {
      final ok = await _processTracker.killSession(session.accountName);
      if (ok) killed++;
    }
    return killed;
  }
}
