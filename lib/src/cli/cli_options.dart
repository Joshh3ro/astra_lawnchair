class CliOptions {
  final bool showHelp;
  final bool showVersion;
  final String? rootPath;
  final String? client;
  final int? staggerDelayMs;
  final bool streamerMode;
  final bool startInFleet;
  final bool startInStats;
  final bool dryRun;
  final bool cleanLogs;
  final bool printFleetStats;

  const CliOptions({
    this.showHelp = false,
    this.showVersion = false,
    this.rootPath,
    this.client,
    this.staggerDelayMs,
    this.streamerMode = false,
    this.startInFleet = false,
    this.startInStats = false,
    this.dryRun = false,
    this.cleanLogs = false,
    this.printFleetStats = false,
  });

  /// Parses a list of command-line arguments into a [CliOptions] instance.
  static CliOptions parse(List<String> args) {
    bool showHelp = false;
    bool showVersion = false;
    String? rootPath;
    String? client;
    int? staggerDelayMs;
    bool streamerMode = false;
    bool startInFleet = false;
    bool startInStats = false;
    bool dryRun = false;
    bool cleanLogs = false;
    bool printFleetStats = false;

    for (int i = 0; i < args.length; i++) {
      final arg = args[i].trim();

      if (arg == '-h' || arg == '--help') {
        showHelp = true;
      } else if (arg == '-v' || arg == '--version') {
        showVersion = true;
      } else if (arg == '-o' || arg == '--streamer' || arg == '--obfuscate') {
        streamerMode = true;
      } else if (arg == '-g' || arg == '--fleet' || arg == '--fleet-matrix') {
        startInFleet = true;
      } else if (arg == '--stats') {
        startInStats = true;
      } else if (arg == '--dry-run') {
        dryRun = true;
      } else if (arg == '--clean-logs') {
        cleanLogs = true;
      } else if (arg == '--fleet-stats') {
        printFleetStats = true;
      } else if (arg == '-r' || arg == '--root') {
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          rootPath = args[++i];
        }
      } else if (arg.startsWith('--root=')) {
        rootPath = arg.substring('--root='.length);
      } else if (arg == '-c' || arg == '--client') {
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          client = args[++i];
        }
      } else if (arg.startsWith('--client=')) {
        client = arg.substring('--client='.length);
      } else if (arg == '-s' || arg == '--stagger') {
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          staggerDelayMs = int.tryParse(args[++i]);
        }
      } else if (arg.startsWith('--stagger=')) {
        staggerDelayMs = int.tryParse(arg.substring('--stagger='.length));
      }
    }

    return CliOptions(
      showHelp: showHelp,
      showVersion: showVersion,
      rootPath: rootPath,
      client: client,
      staggerDelayMs: staggerDelayMs,
      streamerMode: streamerMode,
      startInFleet: startInFleet,
      startInStats: startInStats,
      dryRun: dryRun,
      cleanLogs: cleanLogs,
      printFleetStats: printFleetStats,
    );
  }

  /// Formatted usage and options guide for terminal output.
  static String getHelpText({String version = '0.1.8'}) {
    return '''
Astra Lawnchair (astral) v$version
Fast keyboard-driven Terminal Launcher & Fleet Telemetry Dashboard for AstraBot

USAGE:
  astral [OPTIONS]
  astra_lawnchair [OPTIONS]

LAUNCH OPTIONS:
  -r, --root <path>        Set or override AstraBot root directory path
  -c, --client <name>      Set bot client parameter (e.g. Unity or Flash)
  -s, --stagger <ms>       Set launch stagger delay in milliseconds (e.g. 500)
  -o, --streamer           Launch immediately with Obfuscation / Streamer Mode enabled
  -g, --fleet              Open directly into Fleet Command Matrix view
      --stats              Open directly into Account Stats view
      --dry-run            Dry-run mode (simulates launches without spawning processes)

UTILITY OPTIONS:
      --clean-logs         Sweep stale AstraBot logs across all accounts and exit
      --fleet-stats        Output current fleet session statistics to stdout and exit
  -v, --version            Display application version information and exit
  -h, --help               Display this help documentation and exit

EXAMPLES:
  astral                               Start launcher normally
  astral -o                            Launch in Streamer Mode (masked names/IPs)
  astral -g                            Launch directly into Fleet Command Matrix
  astral -r "C:\\Bots" -s 500           Set custom root path with 500ms launch stagger
  astral --clean-logs                  Perform standalone log clean without opening TUI
  astral --fleet-stats                 Query and print fleet telemetry snapshot

Created by Joshh3ro | Built with Nocterm
''';
  }
}
