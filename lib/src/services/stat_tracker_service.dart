import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/account.dart';
import '../models/account_stats.dart';
import '../models/running_session.dart';

class StatTrackerService {
  final Map<String, AccountStats> _statsMap = {};
  final Map<String, int> _fileOffsets = {};
  final Map<String, int> _trackedPids = {};
  final Map<String, DateTime> _trackedSessionStarts = {};
  final Map<String, String> _activeIngameLogPaths = {};
  final Map<String, String> _activeDeathLogPaths = {};
  final Map<String, String> _activeConsoleLogPaths = {};

  // Regex patterns
  // Example: [20:21:07] You received 6 uridium.
  static final RegExp _receivedRegex = RegExp(
    r'^\[(\d{2}:\d{2}:\d{2})\]\s+You\s+received\s+(\d+)\s+([^.]+)\.?$',
    caseSensitive: false,
  );

  // Example: [20:22:33] You have been destroyed by ..::{ Boss StreuneR }::.. | Map: 1-8
  static final RegExp _deathRegex = RegExp(
    r'^\[(\d{2}:\d{2}:\d{2})\]\s+You\s+have\s+been\s+destroyed\s+by\s+(.+?)\s*\|\s*Map:\s*(.+)$',
    caseSensitive: false,
  );

  // Example: [19:58:43.640] Proxy test succeed. IP: 192.186.186.236
  static final RegExp _proxyRegex = RegExp(
    r'Proxy\s+test\s+succeed\.\s*IP:\s*([0-9.]+)',
    caseSensitive: false,
  );

  // Example: [20:00:27.748] pois ready Hellfire III
  static final RegExp _mapRegex = RegExp(
    r'pois\s+ready\s+(.+)$',
    caseSensitive: false,
  );

  AccountStats? getStats(String accountName) => _statsMap[accountName];

  /// Restores pre-existing or persisted stats for an account
  void restoreStats(String accountName, AccountStats stats) {
    _statsMap[accountName] = stats;
  }

  /// Reset parsed state and file offsets for an account (e.g. on fresh session start)
  void resetAccount(String accountName) {
    _statsMap.remove(accountName);
    _trackedPids.remove(accountName);
    _trackedSessionStarts.remove(accountName);
    _activeIngameLogPaths.remove(accountName);
    _activeDeathLogPaths.remove(accountName);
    _activeConsoleLogPaths.remove(accountName);
    _fileOffsets.removeWhere((key, _) => key.startsWith('$accountName:'));
  }

  /// Updates stats for a given account by reading any newly appended log lines.
  Future<AccountStats> updateAccount(
    Account account, {
    RunningSession? session,
  }) async {
    final accountDir = Directory(account.folderPath);
    if (!accountDir.existsSync()) {
      return _statsMap[account.name] ?? AccountStats(accountName: account.name);
    }

    // Detect session change or new bot launch
    if (session != null) {
      final isNewSession = _trackedSessionStarts[account.name] != session.startTime ||
          _trackedPids[account.name] != session.pid;
      if (isNewSession) {
        _trackedSessionStarts[account.name] = session.startTime;
        _trackedPids[account.name] = session.pid;
        _fileOffsets.removeWhere((key, _) => key.startsWith('${account.name}:'));
        _activeIngameLogPaths.remove(account.name);
        _activeDeathLogPaths.remove(account.name);
        _activeConsoleLogPaths.remove(account.name);

        if (session.lastStats != null) {
          _statsMap[account.name] = AccountStats.fromJson(session.lastStats!).copyWith(
            sessionStart: session.startTime,
            botState: 'Running',
          );
        } else {
          _statsMap[account.name] = AccountStats(
            accountName: account.name,
            sessionStart: session.startTime,
            botState: 'Running',
          );
        }
      }
    }

    AccountStats current = _statsMap[account.name] ??
        AccountStats(
          accountName: account.name,
          sessionStart: session?.startTime,
          botState: session != null ? 'Running' : 'Offline',
        );

    // Update uptime from running session
    if (session != null) {
      final now = DateTime.now();
      final uptimeSecs = now.difference(session.startTime).inSeconds;
      current = current.copyWith(
        sessionStart: session.startTime,
        uptimeSeconds: uptimeSecs > 0 ? uptimeSecs : 0,
        botState: 'Running',
      );
    } else {
      current = current.copyWith(botState: 'Offline');
    }

    // Locate active log files (filtered to session timeframe if running)
    final latestFiles = _findLatestLogFiles(accountDir, session: session);

    // Parse newly appended lines
    if (latestFiles.ingameLogs != null) {
      if (latestFiles.ingameLogs!.path != _activeIngameLogPaths[account.name]) {
        _activeIngameLogPaths[account.name] = latestFiles.ingameLogs!.path;
      }
      current = await _parseIngameLog(account.name, latestFiles.ingameLogs!, current);
    }
    if (latestFiles.deathLogs != null) {
      if (latestFiles.deathLogs!.path != _activeDeathLogPaths[account.name]) {
        _activeDeathLogPaths[account.name] = latestFiles.deathLogs!.path;
      }
      current = await _parseDeathLog(account.name, latestFiles.deathLogs!, current);
    }
    if (latestFiles.consoleLog != null) {
      if (latestFiles.consoleLog!.path != _activeConsoleLogPaths[account.name]) {
        _activeConsoleLogPaths[account.name] = latestFiles.consoleLog!.path;
      }
      current = await _parseConsoleLog(account.name, latestFiles.consoleLog!, current);
    }

    // Record historical currency snapshot for sparklines (capped at 30 points)
    final history = List<CurrencySnapshot>.from(current.currencyHistory);
    final lastSnapshot = history.isNotEmpty ? history.last : null;
    final now = DateTime.now();

    final currenciesChanged = lastSnapshot == null ||
        lastSnapshot.uridium != current.uridium ||
        lastSnapshot.credits != current.credits ||
        lastSnapshot.experience != current.experience ||
        lastSnapshot.honor != current.honor;

    // Record if values changed, or at least once every 30 seconds if running
    final timeSinceLastSnapshot = lastSnapshot != null
        ? now.difference(lastSnapshot.timestamp).inSeconds
        : 999;

    if (currenciesChanged || timeSinceLastSnapshot >= 30) {
      history.add(
        CurrencySnapshot(
          timestamp: now,
          uridium: current.uridium,
          credits: current.credits,
          experience: current.experience,
          honor: current.honor,
        ),
      );
      if (history.length > 30) {
        history.removeAt(0);
      }
      current = current.copyWith(currencyHistory: history);
    }

    _statsMap[account.name] = current;
    return current;
  }

  /// Extracts a [DateTime] from filenames matching patterns like `ingameLogs_2026-09-12_00-13-02.txt`
  /// or `2026-09-12_00-13-02.txt`. Returns `null` if the filename doesn't contain a valid timestamp.
  static DateTime? _parseTimestampFromFilename(String filename) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})').firstMatch(filename);
    if (match == null) return null;
    final datePart = match.group(1);
    final hour = match.group(2);
    final min = match.group(3);
    final sec = match.group(4);
    return DateTime.tryParse('${datePart}T$hour:$min:$sec');
  }

  /// Locates the most recently modified log files of each category in an account directory.
  /// Checks `<accountDir>/logs/` if it exists, falling back to `<accountDir>/`.
  /// When [session] is provided, only files created or modified around or after (session.startTime - 2m)
  /// are considered, preventing stale historical logs from polluting the active session.
  ({File? consoleLog, File? ingameLogs, File? deathLogs}) _findLatestLogFiles(
    Directory dir, {
    RunningSession? session,
  }) {
    File? latestConsole;
    File? latestIngame;
    File? latestDeath;

    DateTime consoleTime = DateTime.fromMillisecondsSinceEpoch(0);
    DateTime ingameTime = DateTime.fromMillisecondsSinceEpoch(0);
    DateTime deathTime = DateTime.fromMillisecondsSinceEpoch(0);

    // Give a generous 2-minute margin prior to session start to account for bot initialization
    final minTime = session?.startTime.subtract(const Duration(minutes: 2));

    // AstraBot places logs inside a 'logs' subfolder if it exists
    final logsDir = Directory(p.join(dir.path, 'logs'));
    final targetDir = logsDir.existsSync() ? logsDir : dir;

    try {
      final entries = targetDir.listSync();
      for (final entry in entries) {
        if (entry is File && entry.path.endsWith('.txt')) {
          final filename = p.basename(entry.path);
          final stat = entry.statSync();

          // Prefer the creation timestamp encoded in the filename (e.g. 2026-09-12_00-13-02),
          // falling back to file modification time.
          final logTime = _parseTimestampFromFilename(filename) ?? stat.modified;

          // Ignore stale logs created before this active session started
          if (minTime != null && logTime.isBefore(minTime)) {
            continue;
          }

          if (filename.startsWith('ingameLogs_')) {
            if (logTime.isAfter(ingameTime)) {
              ingameTime = logTime;
              latestIngame = entry;
            }
          } else if (filename.startsWith('deaths_')) {
            if (logTime.isAfter(deathTime)) {
              deathTime = logTime;
              latestDeath = entry;
            }
          } else {
            // Main console stdout log (usually timestamped, e.g. 2026-09-11_20-15-30.txt)
            if (logTime.isAfter(consoleTime)) {
              consoleTime = logTime;
              latestConsole = entry;
            }
          }
        }
      }
    } catch (_) {}

    return (
      consoleLog: latestConsole,
      ingameLogs: latestIngame,
      deathLogs: latestDeath,
    );
  }

  /// Incrementally reads newly appended bytes from [file], updating [accountName]'s offset.
  Future<List<String>> _readNewLines(String accountName, File file) async {
    final cacheKey = '$accountName:${file.path}';
    final currentOffset = _fileOffsets[cacheKey] ?? 0;

    RandomAccessFile? raf;
    try {
      final fileSize = await file.length();
      if (fileSize <= currentOffset) {
        if (fileSize < currentOffset) {
          // File was truncated or rotated, reset offset
          _fileOffsets[cacheKey] = 0;
        }
        return [];
      }

      raf = await file.open(mode: FileMode.read);
      if (currentOffset > 0) {
        await raf.setPosition(currentOffset);
      }

      final bytesToRead = fileSize - currentOffset;
      final bytes = await raf.read(bytesToRead);
      _fileOffsets[cacheKey] = fileSize;

      final text = utf8.decode(bytes, allowMalformed: true);
      return const LineSplitter().convert(text);
    } catch (_) {
      return [];
    } finally {
      await raf?.close();
    }
  }

  Future<AccountStats> _parseIngameLog(
    String accountName,
    File file,
    AccountStats current,
  ) async {
    final lines = await _readNewLines(accountName, file);
    if (lines.isEmpty) return current;

    int newUri = current.uridium;
    int newCredits = current.credits;
    int newXp = current.experience;
    int newHonor = current.honor;
    final newItems = Map<String, int>.from(current.itemsGained);

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _receivedRegex.firstMatch(line);
      if (match != null) {
        final amount = int.tryParse(match.group(2) ?? '0') ?? 0;
        final rawResource = match.group(3)?.trim().toLowerCase() ?? '';

        if (rawResource == 'uridium') {
          newUri += amount;
        } else if (rawResource == 'credits' || rawResource == 'credit') {
          newCredits += amount;
        } else if (rawResource == 'experience' || rawResource == 'xp') {
          newXp += amount;
        } else if (rawResource == 'honour' || rawResource == 'honor') {
          newHonor += amount;
        } else {
          // Loot item or special material
          final originalItemName = match.group(3)?.trim() ?? rawResource;
          newItems[originalItemName] = (newItems[originalItemName] ?? 0) + amount;
        }
      }
    }

    return current.copyWith(
      uridium: newUri,
      credits: newCredits,
      experience: newXp,
      honor: newHonor,
      itemsGained: newItems,
    );
  }

  Future<AccountStats> _parseDeathLog(
    String accountName,
    File file,
    AccountStats current,
  ) async {
    final lines = await _readNewLines(accountName, file);
    if (lines.isEmpty) return current;

    int deathCount = current.deathCount;
    String? lastKiller = current.lastKiller;
    String? lastDeathMap = current.lastDeathMap;
    DateTime? lastDeathTime = current.lastDeathTime;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = _deathRegex.firstMatch(line);
      if (match != null) {
        deathCount++;
        lastKiller = match.group(2)?.trim();
        lastDeathMap = match.group(3)?.trim();
        lastDeathTime = DateTime.now();
      }
    }

    return current.copyWith(
      deathCount: deathCount,
      lastKiller: lastKiller,
      lastDeathMap: lastDeathMap,
      lastDeathTime: lastDeathTime,
    );
  }

  Future<AccountStats> _parseConsoleLog(
    String accountName,
    File file,
    AccountStats current,
  ) async {
    final lines = await _readNewLines(accountName, file);
    if (lines.isEmpty) return current;

    String? proxyIp = current.activeProxyIp;
    String currentMap = current.currentMap;
    String botState = current.botState;
    String? lastError = current.lastError;
    DateTime? lastErrorTime = current.lastErrorTime;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check proxy
      final proxyMatch = _proxyRegex.firstMatch(line);
      if (proxyMatch != null) {
        proxyIp = proxyMatch.group(1);
      }

      // Check map
      final mapMatch = _mapRegex.firstMatch(line);
      if (mapMatch != null) {
        currentMap = mapMatch.group(1)?.trim() ?? currentMap;
      }

      // Check errors and states
      if (line.contains('FATAL CRASH:')) {
        botState = 'Crashed';
        lastError = line;
        lastErrorTime = DateTime.now();
      } else if (line.contains('Tick error:')) {
        if (botState != 'Crashed') {
          botState = 'Reconnecting';
        }
        lastError = line;
        lastErrorTime = DateTime.now();
      } else if (line.contains('KeepAlive Error') || line.contains('Socket closed')) {
        if (botState != 'Crashed') {
          botState = 'Reconnecting';
        }
      } else if (line.contains('jump') || line.contains('atlama tamamlandı')) {
        if (botState != 'Crashed') {
          botState = 'Jumping';
        }
      } else if (line.contains('particle null ammunition_slug')) {
        if (botState != 'Crashed') {
          botState = 'Fighting';
        }
      } else if (line.contains('LoginStatus{status=0}')) {
        if (botState != 'Crashed') {
          botState = 'Running';
        }
      }
    }

    return current.copyWith(
      activeProxyIp: proxyIp,
      currentMap: currentMap,
      botState: botState,
      lastError: lastError,
      lastErrorTime: lastErrorTime,
    );
  }
}
