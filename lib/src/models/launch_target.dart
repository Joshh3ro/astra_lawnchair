import 'account.dart';
import '../utils/obfuscator.dart';

class LaunchTarget {
  final Account account;
  final String configName;

  const LaunchTarget({
    required this.account,
    required this.configName,
  });

  String get displayName => '${account.name} — "$configName"';

  String getDisplayName({bool obfuscated = false, int? accountIndex}) {
    final accName = Obfuscator.obfuscateAccountName(
      account.name,
      index: accountIndex,
      enabled: obfuscated,
    );
    return '$accName — "$configName"';
  }

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
