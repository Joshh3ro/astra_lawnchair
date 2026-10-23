import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/account.dart';
import '../utils/number_formatter.dart';
import 'process_tracker_service.dart';
import 'stat_tracker_service.dart';

/// Result summary returned after executing [LogCleanerService.cleanAllLogs].
class CleanLogsResult {
  final int filesDeleted;
  final int bytesFreed;
  final int accountsScanned;
  final int runningBotsProtected;

  const CleanLogsResult({
    required this.filesDeleted,
    required this.bytesFreed,
    required this.accountsScanned,
    required this.runningBotsProtected,
  });

  /// Formatted representation of bytes freed (e.g. `14.2 MB`, `350 KB`).
  String get formattedBytes => NumberFormatter.formatBytes(bytesFreed);

  @override
  String toString() =>
      'CleanLogsResult(filesDeleted: $filesDeleted, bytesFreed: $formattedBytes, '
      'accountsScanned: $accountsScanned, runningBotsProtected: $runningBotsProtected)';
}

/// Service that sweeps and deletes stale log files across AstraBot account directories,
/// strictly safeguarding active sessions and locked files.
class LogCleanerService {
  final ProcessTrackerService? processTracker;
  final StatTrackerService? statTracker;

  const LogCleanerService({
    this.processTracker,
    this.statTracker,
  });

  /// Regular expression to match timestamped stdout logs like `2026-09-12_00-13-02.txt`
  static final RegExp _timestampLogRegex =
      RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.txt$');

  /// Parses timestamps encoded in log filenames.
  static DateTime? _parseTimestampFromFilename(String filename) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})').firstMatch(filename);
    if (match == null) return null;
    final datePart = match.group(1);
    final hour = match.group(2);
    final min = match.group(3);
    final sec = match.group(4);
    return DateTime.tryParse('${datePart}T$hour:$min:$sec');
  }

  /// Scans all accounts in [accounts], deletes historical/stale log files,
  /// and returns a [CleanLogsResult] with statistics.
  Future<CleanLogsResult> cleanAllLogs(List<Account> accounts) async {
    int totalFilesDeleted = 0;
    int totalBytesFreed = 0;
    int accountsScanned = 0;
    final protectedRunningBots = <String>{};

    for (final account in accounts) {
      accountsScanned++;
      final accountDir = Directory(account.folderPath);
      if (!accountDir.existsSync()) continue;

      final session = processTracker?.getSession(account.name);
      final isRunning = session != null;
      DateTime? minActiveTime;

      if (isRunning) {
        // Protect any log created or modified within 2 minutes of the active session starting
        minActiveTime = session.startTime.subtract(const Duration(minutes: 2));
      }

      final filesToDelete = <File>[];

      // 1. Inspect <accountDir>/logs/
      final logsDir = Directory(p.join(accountDir.path, 'logs'));
      if (logsDir.existsSync()) {
        try {
          final entries = logsDir.listSync();
          for (final entry in entries) {
            if (entry is File) {
              final ext = p.extension(entry.path).toLowerCase();
              if (ext == '.txt' || ext == '.log') {
                if (isRunning && minActiveTime != null) {
                  final filename = p.basename(entry.path);
                  DateTime? fileTime;
                  try {
                    final stat = entry.statSync();
                    fileTime = _parseTimestampFromFilename(filename) ?? stat.modified;
                  } catch (_) {}

                  if (fileTime != null && !fileTime.isBefore(minActiveTime)) {
                    // Active session log: protect it
                    protectedRunningBots.add(account.name);
                    continue;
                  }
                }
                filesToDelete.add(entry);
              }
            }
          }
        } catch (_) {}
      }

      // 2. Inspect loose log files in <accountDir>/ root
      try {
        final rootEntries = accountDir.listSync();
        for (final entry in rootEntries) {
          if (entry is File) {
            final filename = p.basename(entry.path);
            final isLooseLog = (filename.startsWith('ingameLogs_') && filename.endsWith('.txt')) ||
                (filename.startsWith('deaths_') && filename.endsWith('.txt')) ||
                _timestampLogRegex.hasMatch(filename);

            if (isLooseLog) {
              if (isRunning && minActiveTime != null) {
                DateTime? fileTime;
                try {
                  final stat = entry.statSync();
                  fileTime = _parseTimestampFromFilename(filename) ?? stat.modified;
                } catch (_) {}

                if (fileTime != null && !fileTime.isBefore(minActiveTime)) {
                  protectedRunningBots.add(account.name);
                  continue;
                }
              }
              filesToDelete.add(entry);
            }
          }
        }
      } catch (_) {}

      // Delete identified stale log files safely
      for (final file in filesToDelete) {
        int fileSize = 0;
        try {
          fileSize = file.lengthSync();
        } catch (_) {}

        bool deleted = false;
        try {
          file.deleteSync();
          deleted = true;
        } catch (e) {
          // On Windows, handle closing can hold a momentary lock. Retry briefly after a short yield.
          try {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            if (file.existsSync()) {
              await file.delete();
              deleted = true;
            }
          } catch (_) {
            // Truly locked by an external running process (e.g. AstraBot)
            if (isRunning) {
              protectedRunningBots.add(account.name);
            }
          }
        }

        if (deleted) {
          totalFilesDeleted++;
          totalBytesFreed += fileSize;
        }
      }
    }

    return CleanLogsResult(
      filesDeleted: totalFilesDeleted,
      bytesFreed: totalBytesFreed,
      accountsScanned: accountsScanned,
      runningBotsProtected: protectedRunningBots.length,
    );
  }
}
