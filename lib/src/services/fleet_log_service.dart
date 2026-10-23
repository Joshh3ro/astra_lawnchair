import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/fleet_stats_snapshot.dart';

class FleetLogService {
  final String baseDir;
  final int maxStoredSnapshots;

  late final File _storageFile;
  final List<FleetStatsSnapshot> _snapshots = [];

  String _currentSessionId;
  FleetStatsSnapshot? _sessionBaseline;

  FleetLogService({
    String? baseDir,
    this.maxStoredSnapshots = 500,
    String? sessionId,
  })  : baseDir = baseDir ?? Directory.current.path,
        _currentSessionId = sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}' {
    _storageFile = File(p.join(this.baseDir, 'configs', 'fleet_sessions.json'));
  }

  String get currentSessionId => _currentSessionId;
  FleetStatsSnapshot? get sessionBaseline => _sessionBaseline;
  FleetStatsSnapshot? get latestSnapshot => _snapshots.isNotEmpty ? _snapshots.last : null;
  List<FleetStatsSnapshot> get snapshots => List.unmodifiable(_snapshots);

  /// Initializes the service and loads existing historical snapshots from disk.
  Future<void> init() async {
    try {
      if (await _storageFile.exists()) {
        final content = await _storageFile.readAsString();
        if (content.trim().isNotEmpty) {
          final dynamic decoded = jsonDecode(content);
          if (decoded is List) {
            _snapshots.clear();
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                _snapshots.add(FleetStatsSnapshot.fromJson(item));
              }
            }
          }
        }
      }
    } catch (_) {
      // In case of corrupt or unreadable cache, start fresh without crashing
    }
  }

  /// Starts a new session with an optional custom ID and baseline snapshot.
  void startSession({String? sessionId, FleetStatsSnapshot? baseline}) {
    _currentSessionId = sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}';
    _sessionBaseline = baseline;
    if (baseline != null) {
      recordSnapshot(baseline);
    }
  }

  /// Sets or updates the baseline snapshot used for calculating session deltas.
  void setSessionBaseline(FleetStatsSnapshot baseline) {
    _sessionBaseline = baseline;
  }

  /// Calculates the delta between the established session baseline and the given [current] snapshot.
  FleetStatsDelta? calculateSessionDelta(FleetStatsSnapshot current) {
    final baseline = _sessionBaseline;
    if (baseline == null) return null;
    return baseline.calculateDelta(current);
  }

  /// Records a snapshot into the session history and persists to disk.
  Future<void> recordSnapshot(FleetStatsSnapshot snapshot) async {
    // If no baseline has been set yet, treat the first recorded snapshot as the baseline
    _sessionBaseline ??= snapshot;

    _snapshots.add(snapshot);

    // Prune oldest snapshots if exceeding max limit
    if (_snapshots.length > maxStoredSnapshots) {
      _snapshots.removeRange(0, _snapshots.length - maxStoredSnapshots);
    }

    await _saveToDisk();
  }

  /// Retrieves snapshots filtered by session ID or limited to the latest [limit] items.
  List<FleetStatsSnapshot> getHistory({String? sessionId, int? limit}) {
    Iterable<FleetStatsSnapshot> result = _snapshots;
    if (sessionId != null && sessionId.isNotEmpty) {
      result = result.where((s) => s.sessionId == sessionId);
    }
    if (limit != null && limit > 0 && result.length > limit) {
      result = result.toList().sublist(result.length - limit);
    }
    return result.toList();
  }

  /// Clears in-memory and persisted history.
  Future<void> clearHistory() async {
    _snapshots.clear();
    _sessionBaseline = null;
    if (await _storageFile.exists()) {
      await _storageFile.delete();
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final parentDir = _storageFile.parent;
      if (!parentDir.existsSync()) {
        await parentDir.create(recursive: true);
      }
      final jsonList = _snapshots.map((s) => s.toJson()).toList();
      await _storageFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Silent catch on write failure to avoid crashing launcher during active sessions
    }
  }
}
