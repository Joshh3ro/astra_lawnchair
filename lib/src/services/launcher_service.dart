import 'dart:io';
import '../models/launch_target.dart';

class LaunchResult {
  final LaunchTarget target;
  final bool success;
  final String? errorMessage;
  final int? pid;

  const LaunchResult({
    required this.target,
    required this.success,
    this.errorMessage,
    this.pid,
  });
}

class LauncherService {
  final int staggerDelayMs;
  final String clientName;
  final bool isDryRun;
  final bool autoStart;

  const LauncherService({
    this.staggerDelayMs = 400,
    this.clientName = 'Unity',
    this.isDryRun = false,
    this.autoStart = true,
  });

  /// Launches a list of targets sequentially with staggerDelayMs pause between each.
  Future<List<LaunchResult>> launchAll(
    List<LaunchTarget> targets, {
    void Function(LaunchTarget target, int index, int total)? onProgress,
  }) async {
    final results = <LaunchResult>[];

    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      onProgress?.call(target, i + 1, targets.length);

      final result = await launchSingle(target);
      results.add(result);

      if (i < targets.length - 1 && staggerDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: staggerDelayMs));
      }
    }

    return results;
  }

  /// Launches a single target.
  Future<LaunchResult> launchSingle(LaunchTarget target) async {
    final exePath = target.account.exePath;
    final datPath = target.account.datPath;

    if (exePath.isEmpty) {
      return LaunchResult(
        target: target,
        success: false,
        errorMessage: 'Executable not found in ${target.account.folderPath}',
      );
    }

    if (!isDryRun && !File(exePath).existsSync()) {
      return LaunchResult(
        target: target,
        success: false,
        errorMessage: 'Executable does not exist: $exePath',
      );
    }

    // Argument list: --datFile "<path>" --client Unity --config "<config name with spaces>"
    final args = <String>[];
    if (datPath.isNotEmpty) {
      args.addAll(['--datFile', datPath]);
    }
    args.addAll(['--client', clientName]);
    args.addAll(['--config', target.configName]);
    if (autoStart) {
      args.add('--auto-start');
    }

    if (isDryRun) {
      return LaunchResult(
        target: target,
        success: true,
        pid: 99999,
      );
    }

    try {
      final process = await Process.start(
        exePath,
        args,
        workingDirectory: target.account.folderPath,
        mode: ProcessStartMode.detached,
      );

      return LaunchResult(
        target: target,
        success: true,
        pid: process.pid,
      );
    } catch (e) {
      return LaunchResult(
        target: target,
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
