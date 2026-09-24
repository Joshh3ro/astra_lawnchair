## V0.1.5 A

- Interactive Multi-Account Config Copying (`C` Hotkey & Yellow Palette Workspace)
    > One-touch configuration duplication directly between accounts with distinct visual feedback
    - **Interactive Copy Workspace**: Press `C` on any highlighted config in the Configs menu to open a dedicated multi-account copy workspace (`NavigationLevel.copyConfig`)
    - **Distinct Yellow / Gold Color Scheme**: Designed specifically to differentiate copy destination selection from green launch queue staging, utilizing bold yellow checkboxes and black-on-yellow focused items
    - **Target Status Badges**: Displays `[NEW]` (Cyan) for accounts without the config, and `[OVERWRITE]` (Yellow) for accounts that will have their config updated
    - **Quick Controls & Batch Toggles**: `Space` to toggle accounts, `A` to toggle select-all/deselect-all, `Enter` or `C` to execute copy, and `Backspace` to cancel
    - **Real-Time Summary Card**: Right pane tracks source account, config name, source file, selected count, and breakdown of New vs. Overwrite targets
    - **Instant Disk & Cache Sync**: Copies `.json` files to target `configs/` folders on disk and updates memory & cache files (`<Account>-Configs.json` and `accounts.json`)
    - **Streamer Mode Compliant**: All account names are anonymized when obfuscation is active

- Batch Bot Configuration Switching (`Shift+S` Hotkey)
    > One-step batch switching and hot-swapping across multiple or all accounts at once
    - **One-Key Batch Hot-Swap**: Press `Shift+S` while focused on any config in the Configs menu to immediately apply that configuration to all accounts (or all queued accounts) that possess it, avoiding manual account-by-account switching
    - **Queued Batch Execution**: Pressing `Shift+S` from the Accounts view or Main Menu gracefully terminates all currently running instances in the launch queue, polls until dead, and restarts them with their new configs (applying configured stagger delays)
    - **Account Deduplication Safeguard**: Automatically filters queued targets to prevent duplicate instances from launching for the same account
    - **UI & Hotkey Guidance**: Added `Shift+S: all` to the footer bar, updated the hotkey reference guide, and documented the action in README

- Automated Bot Configuration Hot-Swapping & Reloading (`S` Hotkey)
    > Instant in-place bot configuration switching and reloading without manual kill-queue-run steps
    - **One-Key Hot-Swap**: Press `S` while focused on any config in the Configs menu to instantly terminate the active AstraBot process, wait until process handles are confirmed closed in the OS, and relaunch AstraBot with the new `--config "<name>"` parameter
    - **Native Profile Launching**: Passes `--config "<name>"` directly to AstraBot without touching or copying to root `config.json`, preserving the bot's base configuration intact
    - **Process Death Verification**: Confirms the previous bot PID is fully terminated before spawning the new instance, preventing dual-instance conflicts or port lockouts
    - **Smart Accounts Screen Action**: Pressing `S` on an account in the Accounts list switches to any staged configuration in the launch queue, or automatically digs into the account's configs list for immediate selection
    - **Full Obfuscation Support**: Emits masked status notifications (`Switched "Account #1" to config "PvP" (PID: ...)`) ensuring zero account name exposures in streamer mode
    - **UI & Hotkey Guidance**: Added `S: switch` to the footer bar, updated status prompts, and documented hotkey controls in the Hotkeys and Running Session panels

## V0.1.4 A

- Full-Screen Expanded Account Stats Dashboard & Unified Interactive ASCII Chart
    > Drill-down telemetry visualizer with single unified progression chart, series toggling, and multi-column loot breakdown
    - **Drill-down Navigation**: Press `Enter` on any account in the `Stats` menu to open a dedicated full-screen telemetry workspace (`NavigationLevel.expandedStats`), and `Backspace` to return
    - **Unified Multi-Series Interactive Chart**: Replaced split 2x2 sparkline grids with a full-width progression visualizer plotting:
        - **[1] Uridium** (Cyan)
        - **[2] Credits** (Yellow)
        - **[3] Experience** (Magenta)
        - **[4] Honor** (Green)
    - **Interactive Keyboard Toggles**: Press hotkeys `1`, `2`, `3`, or `4` when in expanded stats to toggle visibility of individual currency series dynamically with instant status notifications
    - **Clean Horizontal Currency & Velocity Bar Gauges**: Replaced cluttered line graphs with high-contrast, proportional horizontal bar meters (`██████░░░░`). Each active metric displays its hotkey index, current earnings, solid colored progress bar, and hourly rate formatted with crystal-clear alignment
    - **Compact Header Chips & Footers**: Clean status indicators `●[1] Uridium`, `○[2] Credits` showing active state and hotkey hints within 80-column terminal bounds
    - **Multi-Column Loot Organization**: Three side-by-side bordered panels below the graphs:
        - `[Ammunition & Rockets]`
        - `[Resources & Minerals]`
        - `[Trinity & Other]`
    - **On-Demand Performance**: Heavy rendering and snapshot tracking are activated only when viewing expanded stats, keeping standard polling fast and lightweight

- Categorized Rewards & Loot Tables
    > Organized telemetry item drops into structured, alphabetical categories
    - Introduced `ItemClassifier` and `ItemCategory` system for mapping DarkOrbit loot items
    - Dedicated categories:
        - **Trinity Trials & Gear**: Quantum Prism, Xyralith, Trinity Token, OS Modules, Refractors, and Particle Cannons (Helios, Nidhogg, Indra across Common to Ultimate rarities)
        - **Ammunition & Rockets**: Specified laser ammo (UCB-100, RSB-75, LCB-10, MCB-25/50, SAB-50, CBO-100, JOB-100, RB-214, PIB-100, RCB-140, IDB-125, VB-142, EMAA-20, SBL-100, A-BL, CC-A..Z) and rocket types (R-310, PLT-2026/2021/3030, BDR-1211/1212, DCR-250, PLD-8, R-IC3, RC-100, SR-5, HSTRM-01, UBR-100)
        - **Resources & Minerals**: Ore, crafting materials, and hardware (Prometium, Prometid, Duranium, Promerium, Seprom, Palladium, Rinusk, Scrap, Mucosum, Diametrion, Log Disk, Booty Key, etc.)
        - **Other Collected Items**: Fallback bucket for general event items and uncategorized drops
    - Clean display filtering: Only categories with non-zero collected items are rendered
    - Items within each category are automatically sorted alphabetically
    - Distinct Cyan subheader styling (`statSubSectionHeader`) for clear visual grouping in Section 4

- `--auto-start` Launch Parameter Support
    > Automatically start bot execution upon process launch
    - Added support for `--auto-start` CLI argument in LauncherService
    - Added `autoStart` property (default: `true`) to AppConfig and serialized in JSON configs
    - Added interactive toggle in Settings menu (`Auto-Start Config: ON / OFF`)
    - Displays current Auto-Start status in the Settings inspection panel

- Top Menu "About" Changelog Preview
    > Contextual summary on the right pane before digging into the full view
    - Displays `ABOUT & CHANGELOG SUMMARY` in the right pane when hovering over "About" in the main menu
    - Highlights current version, key v0.1.4 features, recent release tags, and dig-in instruction

- Nocterm Layout Stability Fix
    > Solved element assertion crash during eager layout passes
    - Refactored right-pane inspector cards (`About`, `Settings`, `Hotkeys`, `Running Bot Status`) to `SingleChildScrollView` with `Column`
    - Resolves Nocterm `assert(newComponent != component)` failures when updating `const` child widgets

- UI Copy & Menu Polish
    > Replaced 'drill into' terminology and decluttered settings subtitles
    - Standardized navigation wording to 'Dig into' across empty queue prompts, hotkey guides, and code methods
    - Removed redundant inline `(Press Space/Enter to toggle/cycle)` strings next to settings items for a clean layout

- Comprehensive Obfuscation & Leak Elimination
    > Eliminated unmasked account name exposures across all views, queues, and status notifications
    - Centralized account and launch target masking through `_getAccountDisplayName()` and `_getTargetDisplayName()`
    - Eliminated raw account names in status messages when digging into configs, expanding stats, adding/removing launch queue items, reporting launch progress, and killing bot processes (`K`)
    - Added `getDisplayName({bool obfuscated = false, int? accountIndex})` to `LaunchTarget`
    - Added comprehensive automated test verifying zero account leaks across all views, statuses, and process termination under Obfuscation mode

## V0.1.3 A

- About Tab & In-App Changelog Viewer
    > Dedicated centered single-pane changelog reader directly in the TUI
    - Added 'About' menu tab in top navigation hierarchy
    - Swaps dual split-pane for a centered full-width PaneBox with version, author, and GitHub info
    - Formatted release cards for all updates (V0.1.4 A down to V0.1.0 A)
    - Scrollable layout with quick Backspace/Enter/Space return
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