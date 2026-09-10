class AppConfig {
  final String rootPath;
  final int staggerDelayMs;
  final String clientName;
  final String runHotkey;

  const AppConfig({
    required this.rootPath,
    this.staggerDelayMs = 400,
    this.clientName = 'Unity',
    this.runHotkey = 'R',
  });

  Map<String, dynamic> toJson() => {
        'rootPath': rootPath,
        'staggerDelayMs': staggerDelayMs,
        'clientName': clientName,
        'runHotkey': runHotkey,
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      rootPath: json['rootPath'] as String? ?? '',
      staggerDelayMs: json['staggerDelayMs'] as int? ?? 400,
      clientName: json['clientName'] as String? ?? 'Unity',
      runHotkey: json['runHotkey'] as String? ?? 'R',
    );
  }

  AppConfig copyWith({
    String? rootPath,
    int? staggerDelayMs,
    String? clientName,
    String? runHotkey,
  }) {
    return AppConfig(
      rootPath: rootPath ?? this.rootPath,
      staggerDelayMs: staggerDelayMs ?? this.staggerDelayMs,
      clientName: clientName ?? this.clientName,
      runHotkey: runHotkey ?? this.runHotkey,
    );
  }
}
