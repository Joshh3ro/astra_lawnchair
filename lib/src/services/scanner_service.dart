import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/account.dart';
import 'config_service.dart';

class ScannerService {
  final String baseDir;
  static const String accountsCacheFileName = 'accounts.json';

  ScannerService({String? baseDir})
      : baseDir = baseDir ?? ConfigService.defaultStorageDir();

  File get accountsCacheFile => File(p.join(baseDir, accountsCacheFileName));

  File accountConfigFile(String accountName) =>
      File(p.join(baseDir, '$accountName-Configs.json'));

  /// Ensures the configs storage directory exists on disk.
  void ensureDirectoryExists() {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  bool cacheExists() {
    if (accountsCacheFile.existsSync()) return true;
    final legacyFile = File(p.join(p.dirname(baseDir), accountsCacheFileName));
    return legacyFile.existsSync();
  }

  /// Loads cached accounts and their cached configs from disk.
  Future<List<Account>> loadCachedAccounts() async {
    File file = accountsCacheFile;

    // Migrate from legacy root if needed
    if (!file.existsSync()) {
      final legacyFile = File(p.join(p.dirname(baseDir), accountsCacheFileName));
      if (legacyFile.existsSync()) {
        try {
          Directory(baseDir).createSync(recursive: true);
          legacyFile.copySync(file.path);
          legacyFile.deleteSync();

          // Migrate any per-account config files from parent directory
          final parentDir = Directory(p.dirname(baseDir));
          for (final entry in parentDir.listSync()) {
            if (entry is File && entry.path.endsWith('-Configs.json')) {
              final target = File(p.join(baseDir, p.basename(entry.path)));
              entry.copySync(target.path);
              entry.deleteSync();
            }
          }
        } catch (_) {
          file = legacyFile;
        }
      } else {
        return [];
      }
    }

    try {
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      final accounts = <Account>[];

      for (final item in jsonList) {
        final account = Account.fromJson(item as Map<String, dynamic>);

        // Also check if per-account config cache file exists
        final perAccountConfigFile = accountConfigFile(account.name);
        List<String> configs = account.configs;
        if (perAccountConfigFile.existsSync()) {
          try {
            final confContent = await perAccountConfigFile.readAsString();
            final confList = (jsonDecode(confContent) as List<dynamic>)
                .map((e) => e.toString())
                .toList();
            if (confList.isNotEmpty) {
              configs = confList;
            }
          } catch (_) {}
        }

        accounts.add(account.copyWith(configs: configs));
      }

      return accounts;
    } catch (e) {
      return [];
    }
  }

  /// Scans root AstraBot directory for account subdirectories and their configs,
  /// then writes the cache to accounts.json and `<AccountName>-Configs.json`.
  Future<List<Account>> scanAndCache(String rootPath) async {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) return [];

    Directory(baseDir).createSync(recursive: true);
    final accounts = <Account>[];

    final entries = rootDir.listSync();
    for (final entry in entries) {
      if (entry is Directory) {
        final accountName = p.basename(entry.path);

        // Skip hidden or common non-account directories
        if (accountName.startsWith('.') || accountName.startsWith('_')) {
          continue;
        }

        final account = await _scanSingleAccount(entry);
        accounts.add(account);

        // Write per-account configs cache
        await _saveAccountConfigsCache(account.name, account.configs);
      }
    }

    // Sort accounts alphabetically
    accounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Write consolidated accounts cache
    final jsonList = accounts.map((a) => a.toJson()).toList();
    final encoder = const JsonEncoder.withIndent('  ');
    await accountsCacheFile.writeAsString(encoder.convert(jsonList));

    return accounts;
  }

  Future<Account> _scanSingleAccount(Directory accountDir) async {
    final accountName = p.basename(accountDir.path);
    String exePath = '';
    String datPath = '';
    final configs = <String>[];

    try {
      final items = accountDir.listSync();

      // Find exe
      for (final item in items) {
        if (item is File && item.path.toLowerCase().endsWith('.exe')) {
          final basename = p.basename(item.path);
          if (basename.toLowerCase() == 'astrabot.exe') {
            exePath = item.path;
            break;
          } else if (exePath.isEmpty) {
            exePath = item.path;
          }
        }
      }

      // Find dat
      for (final item in items) {
        if (item is File && item.path.toLowerCase().endsWith('.dat')) {
          final basename = p.basenameWithoutExtension(item.path);
          if (basename.toLowerCase() == accountName.toLowerCase()) {
            datPath = item.path;
            break;
          } else if (datPath.isEmpty) {
            datPath = item.path;
          }
        }
      }

      // Scan configs directory
      final configsDir = Directory(p.join(accountDir.path, 'configs'));
      if (configsDir.existsSync()) {
        final configFiles = configsDir.listSync();
        for (final configFile in configFiles) {
          if (configFile is File && configFile.path.toLowerCase().endsWith('.json')) {
            final configName = await _readConfigName(configFile);
            if (configName.isNotEmpty) {
              configs.add(configName);
            }
          }
        }
      }
    } catch (_) {}

    configs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Account(
      name: accountName,
      folderPath: accountDir.path,
      exePath: exePath,
      datPath: datPath,
      configs: configs,
    );
  }

  Future<String> _readConfigName(File file) async {
    try {
      final content = await file.readAsString();
      final jsonMap = jsonDecode(content);
      if (jsonMap is Map<String, dynamic> && jsonMap.containsKey('name')) {
        final name = jsonMap['name']?.toString() ?? '';
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}

    // Fallback to filename without extension
    return p.basenameWithoutExtension(file.path);
  }

  Future<void> _saveAccountConfigsCache(String accountName, List<String> configs) async {
    try {
      ensureDirectoryExists();
      final file = accountConfigFile(accountName);
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(configs));
    } catch (_) {}
  }
}
