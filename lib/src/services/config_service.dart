import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/app_config.dart';

class ConfigService {
  final String baseDir;
  static const String configFileName = 'astra_lawnchair_config.json';

  ConfigService({String? baseDir})
      : baseDir = baseDir ?? defaultStorageDir();

  /// Resolves the default configs storage folder.
  /// For standalone executables, uses ./configs next to the executable.
  /// For source runs (dart run), uses ./configs in the current working directory.
  static String defaultStorageDir() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final exeName = p.basenameWithoutExtension(Platform.resolvedExecutable).toLowerCase();
    if (exeName != 'dart' && exeName != 'dartaotruntime' && exeName != 'flutter') {
      return p.join(exeDir, 'configs');
    }
    return p.join(Directory.current.path, 'configs');
  }

  File get configFile => File(p.join(baseDir, configFileName));

  bool configExists() {
    if (configFile.existsSync()) return true;
    // Check legacy root location
    final legacyFile = File(p.join(p.dirname(baseDir), configFileName));
    return legacyFile.existsSync();
  }

  Future<AppConfig?> loadConfig() async {
    File file = configFile;

    // Migrate from legacy root if not in configs/ yet
    if (!file.existsSync()) {
      final legacyFile = File(p.join(p.dirname(baseDir), configFileName));
      if (legacyFile.existsSync()) {
        try {
          Directory(baseDir).createSync(recursive: true);
          legacyFile.copySync(file.path);
          legacyFile.deleteSync();
        } catch (_) {
          file = legacyFile;
        }
      } else {
        return null;
      }
    }

    try {
      final content = await file.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return AppConfig.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  /// Ensures the configs storage directory exists on disk.
  void ensureDirectoryExists() {
    final dir = Directory(baseDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    ensureDirectoryExists();
    final file = configFile;
    final content = const JsonEncoder.withIndent('  ').convert(config.toJson());
    await file.writeAsString(content);
  }
}
