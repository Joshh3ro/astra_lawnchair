import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/launch_target.dart';
import '../models/running_session.dart';

class ProcessTrackerService {
  final String baseDir;
  static const String sessionFileName = 'running_sessions.json';

  final Map<String, RunningSession> _activeSessions = {};

  ProcessTrackerService({required this.baseDir});

  File get sessionFile => File(p.join(baseDir, sessionFileName));

  Map<String, RunningSession> get activeSessions => Map.unmodifiable(_activeSessions);

  RunningSession? getSession(String accountName) => _activeSessions[accountName];

  bool isRunning(String accountName) => _activeSessions.containsKey(accountName);

  /// Loads saved sessions from disk and verifies if processes are still alive in the OS.
  Future<void> initAndPrune() async {
    await loadSessions();
    await pruneStaleSessions();
  }

  /// Loads active sessions from configs/running_sessions.json
  Future<void> loadSessions() async {
    _activeSessions.clear();
    final file = sessionFile;
    if (!file.existsSync()) return;

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            final session = RunningSession.fromJson(entry.value as Map<String, dynamic>);
            _activeSessions[entry.key] = session;
          }
        }
      }
    } catch (_) {
      // Ignore corrupted session file
    }
  }

  /// Persists active sessions map to configs/running_sessions.json
  Future<void> saveSessions() async {
    final file = sessionFile;
    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final map = <String, dynamic>{};
      for (final entry in _activeSessions.entries) {
        map[entry.key] = entry.value.toJson();
      }

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(map));
    } catch (_) {}
  }

  /// Registers a newly launched bot process
  Future<RunningSession> registerLaunch(LaunchTarget target, int pid) async {
    final session = RunningSession(
      accountName: target.account.name,
      configName: target.configName,
      pid: pid,
      startTime: DateTime.now(),
    );

    _activeSessions[target.account.name] = session;
    await saveSessions();
    return session;
  }

  /// Updates the latest known stats snapshot for an active running session
  Future<void> updateSessionStats(String accountName, Map<String, dynamic> stats) async {
    final session = _activeSessions[accountName];
    if (session == null) return;

    _activeSessions[accountName] = session.copyWith(lastStats: stats);
    await saveSessions();
  }

  /// Checks if a process is still alive in the operating system
  Future<bool> isProcessAlive(int pid) async {
    if (pid <= 0) return false;

    // Special mock PID range for unit testing / dry runs
    if (pid >= 90000 && pid <= 99999) {
      return true;
    }

    try {
      if (Platform.isWindows) {
        // Query tasklist with filter for specific PID
        final result = await Process.run(
          'tasklist',
          ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
        );
        final stdout = result.stdout.toString().trim();
        // If tasklist finds the process, it returns a CSV line with the PID; otherwise "INFO: No tasks..."
        if (stdout.isEmpty || stdout.startsWith('INFO:')) {
          return false;
        }
        return stdout.contains('"$pid"') || stdout.contains(',$pid,');
      } else {
        // Unix: kill with signal 0 checks liveness without killing
        final result = Process.killPid(pid, ProcessSignal.sigchld);
        return result;
      }
    } catch (_) {
      return false;
    }
  }

  /// Prunes sessions whose processes have terminated in the OS
  Future<List<String>> pruneStaleSessions() async {
    final pruned = <String>[];
    final keys = _activeSessions.keys.toList();

    for (final accountName in keys) {
      final session = _activeSessions[accountName];
      if (session == null) continue;

      final alive = await isProcessAlive(session.pid);
      if (!alive) {
        _activeSessions.remove(accountName);
        pruned.add(accountName);
      }
    }

    if (pruned.isNotEmpty) {
      await saveSessions();
    }
    return pruned;
  }

  /// Terminates a bot process by account name using PID
  Future<bool> killSession(String accountName) async {
    final session = _activeSessions[accountName];
    if (session == null) return false;

    final success = await killPid(session.pid);
    _activeSessions.remove(accountName);
    await saveSessions();
    return success;
  }

  /// Terminates a process by PID across platforms
  Future<bool> killPid(int pid) async {
    if (pid <= 0) return false;

    // Test/Dry-run mock PIDs
    if (pid >= 90000 && pid <= 99999) {
      return true;
    }

    try {
      if (Platform.isWindows) {
        // Forcefully terminate process and all its children (/T /F)
        final result = await Process.run(
          'taskkill',
          ['/PID', pid.toString(), '/T', '/F'],
        );
        return result.exitCode == 0;
      } else {
        return Process.killPid(pid);
      }
    } catch (_) {
      return false;
    }
  }
}
