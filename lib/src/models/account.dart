class Account {
  final String name;
  final String folderPath;
  final String exePath;
  final String datPath;
  final List<String> configs;

  const Account({
    required this.name,
    required this.folderPath,
    required this.exePath,
    required this.datPath,
    this.configs = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'folderPath': folderPath,
        'exePath': exePath,
        'datPath': datPath,
        'configs': configs,
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      name: json['name'] as String? ?? '',
      folderPath: json['folderPath'] as String? ?? '',
      exePath: json['exePath'] as String? ?? '',
      datPath: json['datPath'] as String? ?? '',
      configs: (json['configs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Account copyWith({
    String? name,
    String? folderPath,
    String? exePath,
    String? datPath,
    List<String>? configs,
  }) {
    return Account(
      name: name ?? this.name,
      folderPath: folderPath ?? this.folderPath,
      exePath: exePath ?? this.exePath,
      datPath: datPath ?? this.datPath,
      configs: configs ?? this.configs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          folderPath == other.folderPath;

  @override
  int get hashCode => name.hashCode ^ folderPath.hashCode;
}
