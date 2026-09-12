/// Helper utilities for anonymizing account names and IP addresses
/// when taking screenshots, streaming, or sharing screen recordings.
class Obfuscator {
  static final Map<String, String> _accountAliasCache = {};

  /// Clears the cached account name aliases (useful during testing or rescan).
  static void clearCache() {
    _accountAliasCache.clear();
  }

  /// Obfuscates an account name into a clean, consistent alias like `Account #1`.
  ///
  /// If [enabled] is false, the original [name] is returned unchanged.
  /// If an [index] is provided (0-based), it will format as `Account #${index + 1}`
  /// and cache the mapping.
  static String obfuscateAccountName(
    String name, {
    int? index,
    bool enabled = true,
  }) {
    if (!enabled) return name;

    if (index != null && index >= 0) {
      final alias = 'Account #${index + 1}';
      _accountAliasCache[name] = alias;
      return alias;
    }

    return _accountAliasCache.putIfAbsent(
      name,
      () => 'Account #${_accountAliasCache.length + 1}',
    );
  }

  /// Completely masks an IP address to prevent exposing network addresses in screenshots.
  ///
  /// For example:
  /// - `192.186.186.236` -> `***.***.***.***`
  /// - `127.0.0.1:8080` -> `***.***.***.***:8080`
  ///
  /// If [enabled] is false or [ip] is null/empty, returns original input.
  static String? obfuscateIp(String? ip, {bool enabled = true}) {
    if (!enabled || ip == null || ip.isEmpty) return ip;

    // Handle port suffix if present
    String host = ip;
    String? port;
    if (ip.contains(':')) {
      final parts = ip.split(':');
      host = parts[0];
      port = parts.sublist(1).join(':');
    }

    final octets = host.split('.');
    String maskedHost;
    if (octets.length == 4) {
      // Entire IPv4 masked
      maskedHost = '***.***.***.***';
    } else {
      maskedHost = '***.***.***.***';
    }

    return port != null ? '$maskedHost:$port' : maskedHost;
  }
}
