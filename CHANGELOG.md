## V0.1.3 A

- Duplicate Bot Launch Prevention & Filtering
    > Automatically ignores already-running bots when executing launch queue
    - Validates bot process liveness before launch execution via ProcessTracker
    - Filters out running bots and launches only inactive accounts sequentially
    - Informs user if all queued accounts are already running without spawning new processes
    - Clear UI status notifications indicating launched count and skipped running instances
    - Automatically prunes launched and running accounts from the queue
- Streamer / Obfuscation Privacy Mode
    > Complete name and IP anonymization for screenshots and streams
    - Global hotkey `O` and Settings menu option to mask sensitive account names into `Account #1`, `Account #2`, etc.
    - Full IP address masking (`***.***.***.***`) for active proxy connections in session & health cards
    - Dedicated `[STREAMER MODE]` visual tag in title bar and dynamic footer hint
    - Fixed running bot session badge and telemetry inspector visibility under obfuscation mode
    - Preserved PID, uptime, status, and config metrics across all views while masked
- Stat Number Grouping & High-Value Space Compression
    > Dot-separated thousands and ten-thousands with B/T compression
    - Added `NumberFormatter` utility to format all stat amounts: `1.000`, `10.000`, `100.000`, `1.000.000`
    - High magnitude values automatically compressed to `1.11B`, `25.5B`, `1.11T` to prevent UI overflow
    - Formatted currencies, hourly rates, death counts, and custom loot collections

## V0.1.2 A

- Real-Time Account Telemetry & Stats Tracking (Option A)
    > Dedicated Stats menu with full dual-pane dashboard
    - Added dedicated Stats view in top menu hierarchy
    - Left pane: accounts list with live badges, Uridium/hr rates, deaths, and current map
    - Right pane: 4-section telemetry card (Session & Health, Currencies & Rates, Combat, Loot items)
    - Auto-polling every 1.8s + manual Enter refresh
- High-Efficiency Incremental Log Reader
    > Non-blocking parsing via byte-offset seeking
    - Reads only newly appended bytes on each poll without re-reading whole files
    - Parses ingameLogs_*.txt, deaths_*.txt, and console stdout logs
    - Tracks hourly velocities for Uridium, Credits, XP, and Honor
- Session-Aware Log Correlation & Stale Log Prevention
    > Reliable live telemetry without historical data pollution
    - Log discovery filters files modified during or after session.startTime - 30s
    - Automatically detects and binds newly created log files mid-session
    - Resets stats and file offsets cleanly on new bot launches
- Persistent Bot Session Recovery Across Restarts
    > Seamless continuity across Astra Lawnchair launches
    - Bootstrap verifies OS PID liveness via tasklist/kill(0) before UI mount
    - Alive bots maintain continuous uptime from original launch time
    - Serialized lastStats snapshot pre-populates telemetry on app start
- Clean Terminal Teardown & Buffer Restoration
    > Complete screen reset upon exit
    - Switched from dart:io exit() to Nocterm shutdownApp() across all quit triggers
    - Properly exits alternate screen buffer, unhides cursor, and clears terminal canvas on quit
- Viewport & Spacing Optimization
    > Flawless rendering in terminal dimensions
    - Replaced eager ListView with SingleChildScrollView(child: Column(...))
    - Compacted spacing and aligned labels

## V0.1.1 A

- Initial setup of architecture and modules
    > Changed the way the menus work
    - added menu item descriptions
    - added new menus: settings, hotkeys, quit
    - changed how the UI flows, better layout 
- Settings menu
    > Added options to configure in the TUI
    - Added adjustable launch timing 
    - Added adjustable root folder
    - Added adjustable client option, Unity or Flash
- Setup Configs Folder
    > Cleaned up artifacts
    - Made the json format easier to read
    - Fixed issue that would cause the configs to be saved in random places
- Process Tracking & Bot Management
    > Monitor, inspect, and terminate active accounts
    - Captured OS process PID on bot launches
    - Added live uptime and PID status badges in TUI
    - Added 'K' hotkey to cleanly kill/terminate focused running bots
    - Persistent running sessions saved to configs/running_sessions.json
- Clickable Hyperlink
    > Interactive footer links
    - Added clickable (GitHub) repository link opening in default browser

## V0.1.0 A

- Initial setup of architecture and modules
- Initial Testing of Account and folder logic
- Setup Configs Folder