# Astra Lawnchair API (`lib/api/`)

A high-level, modular Dart API for programmatic control and user expandability. 

Use this API to build Discord bots, web dashboards, CLI tools, automation scripts, and custom fleet controllers on top of Astra Lawnchair without depending directly on internal UI components.

---

## Quick Start

```dart
import 'package:astra_lawnchair/api/api.dart';

void main() async {
  // 1. Initialize the unified Astra API
  final astra = await AstraApi.initialize(
    rootPath: r'C:\Bots\AstraBot',
    isDryRun: false,
  );

  // 2. Discover accounts and configs
  final accounts = await astra.accounts.getAccounts();
  print('Loaded ${accounts.length} accounts');

  // 3. Launch an account
  if (accounts.isNotEmpty) {
    final result = await astra.bots.launch(
      accounts.first,
      configName: 'Default',
    );
    print('Launch success: ${result.success}, PID: ${result.pid}');
  }

  // 4. Capture live fleet telemetry & session deltas
  final snapshot = astra.fleet.captureSnapshot();
  final delta = astra.fleet.calculateSessionDelta(snapshot);
  print('Active bots: ${snapshot.activeBotCount}');
  print('Net Uridium: ${delta.netUridium} (${delta.formattedUridiumPerHour})');

  // 5. Clean stale logs
  final cleanResult = await astra.logs.cleanLogs();
  print('Freed ${cleanResult.formattedBytes} across ${cleanResult.filesDeleted} log files');
}
```

---

## Modular Sub-APIs

| Sub-API | Property | Description |
| :--- | :--- | :--- |
| **AccountApi** | `astra.accounts` | Discover accounts, read configs, copy configurations across accounts. |
| **BotApi** | `astra.bots` | Launch bots, hot-swap configs in-place, monitor PID sessions, terminate processes. |
| **FleetApi** | `astra.fleet` | Live telemetry metrics, rates/hr, session snapshots, and deltas. |
| **LogApi** | `astra.logs` | Sweep stale log files, calculate log counts, protect active bot logs. |
| **ConfigApi** | `astra.config` | Read, patch, and persist `astra_lawnchair_config.json`. |

---

## Advanced: Direct Service Access
If custom extensions need lower-level mechanics, the underlying services remain accessible:
- `astra.scannerService`
- `astra.launcherService`
- `astra.processTracker`
- `astra.statTracker`
- `astra.fleetLogService`
- `astra.logCleaner`
- `astra.configService`
