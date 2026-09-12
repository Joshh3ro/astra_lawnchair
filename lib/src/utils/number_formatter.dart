/// Utility for formatting numeric statistics with dot-separated thousands groups
/// and compact abbreviations for large values (billions and trillions).
///
/// Rules:
/// - Values below 1,000,000,000 are formatted with dot (`.`) thousand separators:
///   e.g. `1000`, `10.000`, `100.000`, `1.000.000`, `10.000.000`, `100.000.000`.
/// - Values at or above 1,000,000,000 are compressed to conserve UI space:
///   e.g. `1.11B`, `25.50B`, `1.11T`.
class NumberFormatter {
  /// Formats an integer amount with dots for thousands, compressing to B/T at 1 billion+.
  static String formatNumber(int value) {
    if (value < 0) {
      return '-${formatNumber(-value)}';
    }

    // Trillions (>= 1,000,000,000,000)
    if (value >= 1000000000000) {
      final t = value / 1000000000000.0;
      return '${_trimTrailingZeros(t.toStringAsFixed(2))}T';
    }

    // Billions (>= 1,000,000,000)
    if (value >= 1000000000) {
      final b = value / 1000000000.0;
      return '${_trimTrailingZeros(b.toStringAsFixed(2))}B';
    }

    // Values under 1 billion: dot thousand separators
    // e.g. 1000, 10.000, 100.000, 1.000.000
    final str = value.toString();
    final buffer = StringBuffer();
    final len = str.length;

    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }

  /// Formats hourly velocity rates (double) cleanly.
  ///
  /// Examples:
  /// - Rate < 1,000: `250`
  /// - Rate < 1,000,000: `12.500`
  /// - Rate < 1,000,000,000: `1.25M`
  /// - Rate >= 1,000,000,000: `2.40B`
  /// - Rate >= 1,000,000,000,000: `1.10T`
  static String formatRate(double rate) {
    if (rate <= 0) return '0';

    if (rate >= 1000000000000) {
      final t = rate / 1000000000000.0;
      return '${_trimTrailingZeros(t.toStringAsFixed(2))}T';
    }

    if (rate >= 1000000000) {
      final b = rate / 1000000000.0;
      return '${_trimTrailingZeros(b.toStringAsFixed(2))}B';
    }

    if (rate >= 1000000) {
      final m = rate / 1000000.0;
      return '${_trimTrailingZeros(m.toStringAsFixed(2))}M';
    }

    return formatNumber(rate.round());
  }

  static String _trimTrailingZeros(String formatted) {
    if (!formatted.contains('.')) return formatted;
    var trimmed = formatted;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
