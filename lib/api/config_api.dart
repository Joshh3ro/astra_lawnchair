import '../src/models/app_config.dart';
import '../src/services/config_service.dart';

/// High-level API for reading, saving, and updating Astra Lawnchair configuration.
class ConfigApi {
  final ConfigService _configService;

  ConfigApi(this._configService);

  /// The underlying [ConfigService] instance.
  ConfigService get service => _configService;

  /// The directory where configuration files are stored.
  String get baseDir => _configService.baseDir;

  /// Returns true if a valid configuration file exists on disk.
  bool exists() => _configService.configExists();

  /// Loads the persisted [AppConfig], or returns null if not configured yet.
  Future<AppConfig?> load() => _configService.loadConfig();

  /// Saves the given [AppConfig] to disk.
  Future<void> save(AppConfig config) => _configService.saveConfig(config);

  /// Convenience method to patch specific configuration properties in-place.
  Future<AppConfig> update({
    String? rootPath,
    String? clientName,
    int? staggerDelayMs,
    String? runHotkey,
    bool? obfuscateNames,
    bool? autoStart,
  }) async {
    final current = await load() ??
        AppConfig(
          rootPath: rootPath ?? '',
          clientName: clientName ?? 'Unity',
          staggerDelayMs: staggerDelayMs ?? 400,
          runHotkey: runHotkey ?? 'R',
          obfuscateNames: obfuscateNames ?? false,
          autoStart: autoStart ?? true,
        );

    final updated = current.copyWith(
      rootPath: rootPath,
      clientName: clientName,
      staggerDelayMs: staggerDelayMs,
      runHotkey: runHotkey,
      obfuscateNames: obfuscateNames,
      autoStart: autoStart,
    );

    await save(updated);
    return updated;
  }
}
