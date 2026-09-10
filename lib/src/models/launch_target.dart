import 'account.dart';

class LaunchTarget {
  final Account account;
  final String configName;

  const LaunchTarget({
    required this.account,
    required this.configName,
  });

  String get displayName => '${account.name} — "$configName"';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchTarget &&
          runtimeType == other.runtimeType &&
          account.name == other.account.name &&
          configName == other.configName;

  @override
  int get hashCode => account.name.hashCode ^ configName.hashCode;
}
