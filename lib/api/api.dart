/// Central export barrel for the Astra Lawnchair Public API.
///
/// Import this library to integrate Astra Lawnchair programmatically:
/// ```dart
/// import 'package:astra_lawnchair/api/api.dart';
/// ```
library;

export 'account_api.dart';
export 'astra_api.dart';
export 'bot_api.dart';
export 'config_api.dart';
export 'fleet_api.dart';
export 'log_api.dart';

// Core data models consumed by the API
export '../src/models/account.dart';
export '../src/models/account_stats.dart';
export '../src/models/app_config.dart';
export '../src/models/fleet_stats_snapshot.dart';
export '../src/models/launch_target.dart';
export '../src/models/running_session.dart';

// Result payloads
export '../src/services/launcher_service.dart' show LaunchResult;
export '../src/services/log_cleaner_service.dart' show CleanLogsResult;
