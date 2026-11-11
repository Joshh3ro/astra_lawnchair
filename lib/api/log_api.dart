import 'dart:io';
import 'package:path/path.dart' as p;
import '../src/models/account.dart';
import '../src/services/log_cleaner_service.dart';

/// High-level API for log inspection, cleanup, and disk maintenance.
class LogApi {
  final LogCleanerService _logCleaner;
  final Future<List<Account>> Function()? _accountsProvider;

  LogApi(this._logCleaner, {this._accountsProvider});

  /// The underlying [LogCleanerService].
  LogCleanerService get service => _logCleaner;

  /// Sweeps stale log files across accounts, while protecting active bot processes.
  Future<CleanLogsResult> cleanLogs({List<Account>? accounts}) async {
    final targets = accounts ?? (await _accountsProvider?.call()) ?? [];
    return _logCleaner.cleanAllLogs(targets);
  }

  /// Lists all log files (both in `<account>/logs/` and root) for a given [account].
  Future<List<File>> getAccountLogs(Account account) async {
    final logFiles = <File>[];
    final accountDir = Directory(account.folderPath);
    if (!accountDir.existsSync()) return logFiles;

    final logsDir = Directory(p.join(accountDir.path, 'logs'));
    if (logsDir.existsSync()) {
      try {
        for (final entry in logsDir.listSync()) {
          if (entry is File) {
            final ext = p.extension(entry.path).toLowerCase();
            if (ext == '.txt' || ext == '.log') {
              logFiles.add(entry);
            }
          }
        }
      } catch (_) {}
    }

    try {
      for (final entry in accountDir.listSync()) {
        if (entry is File) {
          final filename = p.basename(entry.path);
          if ((filename.startsWith('ingameLogs_') && filename.endsWith('.txt')) ||
              (filename.startsWith('deaths_') && filename.endsWith('.txt')) ||
              RegExp(r'^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.txt$').hasMatch(filename)) {
            logFiles.add(entry);
          }
        }
      }
    } catch (_) {}

    return logFiles;
  }

  /// Calculates total log files across [accounts].
  Future<int> getTotalLogCount({List<Account>? accounts}) async {
    final targets = accounts ?? (await _accountsProvider?.call()) ?? [];
    int total = 0;
    for (final acc in targets) {
      final logs = await getAccountLogs(acc);
      total += logs.length;
    }
    return total;
  }
}
