import 'package:astra_lawnchair/src/cli/cli_options.dart';
import 'package:test/test.dart';

void main() {
  group('CliOptions Parser Tests', () {
    test('parses empty args with standard defaults', () {
      final options = CliOptions.parse([]);

      expect(options.showHelp, isFalse);
      expect(options.showVersion, isFalse);
      expect(options.rootPath, isNull);
      expect(options.client, isNull);
      expect(options.staggerDelayMs, isNull);
      expect(options.streamerMode, isFalse);
      expect(options.startInFleet, isFalse);
      expect(options.startInStats, isFalse);
      expect(options.dryRun, isFalse);
      expect(options.cleanLogs, isFalse);
      expect(options.printFleetStats, isFalse);
    });

    test('parses short flags correctly', () {
      final options = CliOptions.parse([
        '-r', '/path/to/bots',
        '-c', 'Flash',
        '-s', '600',
        '-o',
        '-g',
      ]);

      expect(options.rootPath, equals('/path/to/bots'));
      expect(options.client, equals('Flash'));
      expect(options.staggerDelayMs, equals(600));
      expect(options.streamerMode, isTrue);
      expect(options.startInFleet, isTrue);
    });

    test('parses long flags and key=value flags correctly', () {
      final options = CliOptions.parse([
        '--root=/custom/root',
        '--client=Unity',
        '--stagger=750',
        '--streamer',
        '--stats',
        '--dry-run',
        '--clean-logs',
        '--fleet-stats',
      ]);

      expect(options.rootPath, equals('/custom/root'));
      expect(options.client, equals('Unity'));
      expect(options.staggerDelayMs, equals(750));
      expect(options.streamerMode, isTrue);
      expect(options.startInStats, isTrue);
      expect(options.dryRun, isTrue);
      expect(options.cleanLogs, isTrue);
      expect(options.printFleetStats, isTrue);
    });

    test('parses help and version flags', () {
      expect(CliOptions.parse(['-h']).showHelp, isTrue);
      expect(CliOptions.parse(['--help']).showHelp, isTrue);
      expect(CliOptions.parse(['-v']).showVersion, isTrue);
      expect(CliOptions.parse(['--version']).showVersion, isTrue);
    });

    test('getHelpText contains usage instructions and flags', () {
      final help = CliOptions.getHelpText(version: '0.1.8');
      expect(help, contains('astral [OPTIONS]'));
      expect(help, contains('--root'));
      expect(help, contains('--streamer'));
      expect(help, contains('--fleet'));
      expect(help, contains('--dry-run'));
      expect(help, contains('--clean-logs'));
      expect(help, contains('--fleet-stats'));
    });
  });
}
