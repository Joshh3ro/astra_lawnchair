import 'dart:io';
import 'package:path/path.dart' as p;
import '../src/models/account.dart';
import '../src/services/scanner_service.dart';

/// High-level API for discovering accounts, reading configs, and copying profiles.
class AccountApi {
  final ScannerService _scannerService;
  final String Function()? _rootPathResolver;
  List<Account> _cachedAccounts = [];

  AccountApi(this._scannerService, {this._rootPathResolver});

  /// The underlying [ScannerService].
  ScannerService get service => _scannerService;

  /// In-memory cached accounts list from previous scan/load.
  List<Account> get cachedAccounts => List.unmodifiable(_cachedAccounts);

  /// Total number of known accounts.
  int get count => _cachedAccounts.length;

  /// Retrieves accounts, either from disk cache or by re-scanning if [refresh] is true.
  Future<List<Account>> getAccounts({bool refresh = false, String? rootPath}) async {
    final effectiveRoot = rootPath ?? _rootPathResolver?.call();

    if (refresh && effectiveRoot != null && effectiveRoot.isNotEmpty) {
      _cachedAccounts = await _scannerService.scanAndCache(effectiveRoot);
    } else if (_cachedAccounts.isEmpty) {
      _cachedAccounts = await _scannerService.loadCachedAccounts();
      if (_cachedAccounts.isEmpty && effectiveRoot != null && effectiveRoot.isNotEmpty) {
        _cachedAccounts = await _scannerService.scanAndCache(effectiveRoot);
      }
    }

    return List.unmodifiable(_cachedAccounts);
  }

  /// Finds an account by exact or case-insensitive name.
  Account? getAccountByName(String name) {
    for (final acc in _cachedAccounts) {
      if (acc.name.toLowerCase() == name.toLowerCase()) {
        return acc;
      }
    }
    return null;
  }

  /// Returns available config names for a specific account.
  Future<List<String>> getConfigsForAccount(String accountName) async {
    final account = getAccountByName(accountName);
    if (account != null && account.configs.isNotEmpty) {
      return account.configs;
    }
    final perAccountFile = _scannerService.accountConfigFile(accountName);
    if (perAccountFile.existsSync()) {
      return (await _scannerService.loadCachedAccounts())
          .firstWhere((a) => a.name.toLowerCase() == accountName.toLowerCase(),
              orElse: () => Account(name: accountName, folderPath: '', exePath: '', datPath: ''))
          .configs;
    }
    return [];
  }

  /// Copies a configuration file from [sourceAccountName] to [targetAccountName].
  Future<bool> copyConfig({
    required String sourceAccountName,
    required String targetAccountName,
    required String configName,
  }) async {
    final results = await copyConfigToMultiple(
      sourceAccountName: sourceAccountName,
      targetAccountNames: [targetAccountName],
      configName: configName,
    );
    return results > 0;
  }

  /// Copies a configuration file from [sourceAccountName] to multiple [targetAccountNames].
  /// Returns the count of successfully updated target accounts.
  Future<int> copyConfigToMultiple({
    required String sourceAccountName,
    required List<String> targetAccountNames,
    required String configName,
  }) async {
    final sourceAccount = getAccountByName(sourceAccountName);
    if (sourceAccount == null) return 0;

    final sourceConfigsDir = Directory(p.join(sourceAccount.folderPath, 'configs'));
    if (!sourceConfigsDir.existsSync()) return 0;

    // Locate source file matching config name
    File? sourceFile;
    for (final file in sourceConfigsDir.listSync()) {
      if (file is File && file.path.toLowerCase().endsWith('.json')) {
        if (p.basenameWithoutExtension(file.path).toLowerCase() == configName.toLowerCase()) {
          sourceFile = file;
          break;
        }
      }
    }
    if (sourceFile == null) return 0;

    final configContent = await sourceFile.readAsString();
    final filename = p.basename(sourceFile.path);
    int successCount = 0;

    for (final targetName in targetAccountNames) {
      final targetAccount = getAccountByName(targetName);
      if (targetAccount == null) continue;

      final targetConfigsDir = Directory(p.join(targetAccount.folderPath, 'configs'));
      if (!targetConfigsDir.existsSync()) {
        targetConfigsDir.createSync(recursive: true);
      }

      final targetFile = File(p.join(targetConfigsDir.path, filename));
      await targetFile.writeAsString(configContent);

      if (!targetAccount.configs.contains(configName)) {
        final updatedConfigs = List<String>.from(targetAccount.configs)..add(configName);
        updatedConfigs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        final updatedAccount = targetAccount.copyWith(configs: updatedConfigs);

        final idx = _cachedAccounts.indexWhere((a) => a.name == targetAccount.name);
        if (idx != -1) {
          _cachedAccounts[idx] = updatedAccount;
        }

        await _scannerService.saveAccountConfigsCache(targetAccount.name, updatedConfigs);
      }
      successCount++;
    }

    if (successCount > 0) {
      await _scannerService.saveAccountsCache(_cachedAccounts);
    }

    return successCount;
  }
}
