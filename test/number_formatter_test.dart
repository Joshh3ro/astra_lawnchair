import 'package:test/test.dart';
import 'package:astra_lawnchair/src/utils/number_formatter.dart';

void main() {
  group('NumberFormatter', () {
    group('formatNumber', () {
      test('formats numbers below thousands without separators', () {
        expect(NumberFormatter.formatNumber(0), '0');
        expect(NumberFormatter.formatNumber(5), '5');
        expect(NumberFormatter.formatNumber(999), '999');
      });

      test('formats thousands and ten thousands with dot separators', () {
        expect(NumberFormatter.formatNumber(1000), '1.000');
        expect(NumberFormatter.formatNumber(10000), '10.000');
        expect(NumberFormatter.formatNumber(100000), '100.000');
        expect(NumberFormatter.formatNumber(12288), '12.288');
        expect(NumberFormatter.formatNumber(999999), '999.999');
      });

      test('formats millions with dot separators', () {
        expect(NumberFormatter.formatNumber(1000000), '1.000.000');
        expect(NumberFormatter.formatNumber(10000000), '10.000.000');
        expect(NumberFormatter.formatNumber(100000000), '100.000.000');
        expect(NumberFormatter.formatNumber(123456789), '123.456.789');
      });

      test('compresses billions to B notation with up to 2 decimal places', () {
        expect(NumberFormatter.formatNumber(1000000000), '1B');
        expect(NumberFormatter.formatNumber(1110000000), '1.11B');
        expect(NumberFormatter.formatNumber(25500000000), '25.5B');
        expect(NumberFormatter.formatNumber(100000000000), '100B');
      });

      test('compresses trillions to T notation', () {
        expect(NumberFormatter.formatNumber(1000000000000), '1T');
        expect(NumberFormatter.formatNumber(1110000000000), '1.11T');
        expect(NumberFormatter.formatNumber(5000000000000), '5T');
      });

      test('handles negative values appropriately', () {
        expect(NumberFormatter.formatNumber(-5000), '-5.000');
        expect(NumberFormatter.formatNumber(-2000000000), '-2B');
      });
    });

    group('formatRate', () {
      test('formats small rates as integer without decimals', () {
        expect(NumberFormatter.formatRate(0.0), '0');
        expect(NumberFormatter.formatRate(450.4), '450');
      });

      test('formats thousand rates with dot separators', () {
        expect(NumberFormatter.formatRate(1250.0), '1.250');
        expect(NumberFormatter.formatRate(85000.0), '85.000');
      });

      test('formats million rates with M abbreviation', () {
        expect(NumberFormatter.formatRate(1000000.0), '1M');
        expect(NumberFormatter.formatRate(1250000.0), '1.25M');
        expect(NumberFormatter.formatRate(15800000.0), '15.8M');
      });

      test('formats billion and trillion rates with B and T', () {
        expect(NumberFormatter.formatRate(1110000000.0), '1.11B');
        expect(NumberFormatter.formatRate(25000000000.0), '25B');
        expect(NumberFormatter.formatRate(1500000000000.0), '1.5T');
      });
    });
  });
}
