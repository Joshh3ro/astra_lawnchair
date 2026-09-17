import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';
import 'package:astra_lawnchair/src/models/account_stats.dart';
import 'package:astra_lawnchair/src/ui/widgets/ascii_chart.dart';

void main() {
  group('AsciiChart Widget & CurrencySnapshot Tests', () {
    test('CurrencySnapshot serializes and deserializes correctly', () {
      final now = DateTime.now();
      final snapshot = CurrencySnapshot(
        timestamp: now,
        uridium: 50000,
        credits: 12000000,
        experience: 950000,
        honor: 45000,
      );

      final json = snapshot.toJson();
      final restored = CurrencySnapshot.fromJson(json);

      expect(restored.uridium, equals(50000));
      expect(restored.credits, equals(12000000));
      expect(restored.experience, equals(950000));
      expect(restored.honor, equals(45000));
    });

    test('AccountStats handles currencyHistory serialization', () {
      final snapshot1 = CurrencySnapshot(
        timestamp: DateTime.now(),
        uridium: 100,
        credits: 1000,
        experience: 500,
        honor: 50,
      );
      final snapshot2 = CurrencySnapshot(
        timestamp: DateTime.now(),
        uridium: 200,
        credits: 2000,
        experience: 1000,
        honor: 100,
      );

      final stats = AccountStats(
        accountName: 'TestBot',
        uridium: 200,
        currencyHistory: [snapshot1, snapshot2],
      );

      final json = stats.toJson();
      final restored = AccountStats.fromJson(json);

      expect(restored.currencyHistory.length, equals(2));
      expect(restored.currencyHistory.first.uridium, equals(100));
      expect(restored.currencyHistory.last.uridium, equals(200));
    });

    test('AsciiChart renders title, formatted value, rate, and block bars in single-series mode', () async {
      await testNocterm('renders single series sparkline chart', (tester) async {
        await tester.pumpComponent(
          const AsciiChart(
            title: 'Uridium Live',
            series: [
              ChartSeries(
                id: 'uridium',
                label: 'Uridium',
                values: [100, 150, 300, 500, 800, 1200],
                color: Colors.cyan,
                currentFormatted: '+1.200',
                rateFormatted: '+600/h',
                isVisible: true,
              ),
            ],
          ),
        );

        expect(tester.terminalState, containsText('Uridium Live'));
        expect(tester.terminalState, containsText('●[1] Uridium'));
        expect(tester.terminalState, containsText('Uridium: '));
        expect(tester.terminalState, containsText('+1.200'));
        expect(tester.terminalState, containsText('(+600/h)'));
        expect(tester.terminalState, containsText('[1-4: Toggle]'));
      });
    });

    test('AsciiChart renders multi-series overlay and handles hidden series', () async {
      await testNocterm('renders multi series chart with toggles', (tester) async {
        await tester.pumpComponent(
          const AsciiChart(
            title: 'LIVE PROGRESSION GRAPH',
            series: [
              ChartSeries(
                id: 'uridium',
                label: 'Uridium',
                values: [100, 200, 300],
                color: Colors.cyan,
                currentFormatted: '+300',
                rateFormatted: '+100/h',
                isVisible: true,
              ),
              ChartSeries(
                id: 'credits',
                label: 'Credits',
                values: [1000, 2000, 3000],
                color: Colors.yellow,
                currentFormatted: '+3.000',
                rateFormatted: '+1.000/h',
                isVisible: false,
              ),
            ],
          ),
        );

        expect(tester.terminalState, containsText('LIVE PROGRESSION GRAPH'));
        expect(tester.terminalState, containsText('●[1] Uridium'));
        expect(tester.terminalState, containsText('○[2] Credits'));
        expect(tester.terminalState, containsText('Uridium: '));
        expect(tester.terminalState, containsText('+300'));
        expect(tester.terminalState, isNot(containsText('Credits: ')));
      });
    });
  });
}
