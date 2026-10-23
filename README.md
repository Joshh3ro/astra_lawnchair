<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/cb95e2e2-1eab-47e8-9753-10b6b571423a" />

# Astra Lawnchair

*(A relaxed place to sit while your bots log in. Formerly known as "Astra Launcher." ill probably be changing the name to "Astral Lawnchair")*

[![Download Latest Release](https://img.shields.io/badge/Download-Latest%20Release-2ea44f?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/Joshh3ro/astra_lawnchair/releases/latest)

[![Latest Release](https://img.shields.io/github/v/release/Joshh3ro/astra_lawnchair?style=flat-square&logo=github&color=00B4D8&label=release)](https://github.com/Joshh3ro/astra_lawnchair/releases/latest)
[![Total Downloads](https://img.shields.io/github/downloads/Joshh3ro/astra_lawnchair/total?style=flat-square&logo=github&color=2EA44F&label=downloads)](https://github.com/Joshh3ro/astra_lawnchair/releases)
[![Repo Views](https://komarev.com/ghpvc/?username=Joshh3ro&repo=astra_lawnchair&label=views&color=0e75b6&style=flat-square)](https://github.com/Joshh3ro/astra_lawnchair)
[![Stars](https://img.shields.io/github/stars/Joshh3ro/astra_lawnchair?style=flat-square&color=E3B341&logo=star)](https://github.com/Joshh3ro/astra_lawnchair/stargazers)
[![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square&logo=windows&logoColor=white)](https://github.com/Joshh3ro/astra_lawnchair)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Built with Nocterm](https://img.shields.io/badge/TUI-Nocterm-7928CA?style=flat-square)](https://github.com/Norbert515/nocterm)

A Dart terminal UI (TUI) app, built with the **Nocterm** framework, that replaces a folder full of hand-written `.bat` launcher files. It scans a directory of AstraBot account folders, lets the user pick one or more accounts and one or more configs per account, and launches all selected account/config combinations at once as detached processes with staggered intervals.

## Features

- **Nocterm TUI Interface**: Dual-pane keyboard & mouse driven interface with focus/selection differentiation.
- **Unified Stats & Fleet Command Matrix**: High-density real-time multi-bot telemetry dashboard showing status, uptimes, 20-col maps, earnings, velocities (Uri/hr, XP/hr, Honor/hr), deaths, and fleet aggregates with instant drill-down.
- **Fleet Session Stats Logging**: Automatic baseline capture, historical snapshot logging (`configs/fleet_sessions.json`), and live session delta indicators (`Δ SESSION`).
- **Escape Quick Menu & Cheatsheet**: Global modal overlay (`Esc`) providing instant cheatsheet guidance and direct jump to Settings.
- **On-Demand Log Cleaner**: Global `Shift+L` sweep to purge stale logs and reclaim disk space while protecting active bot sessions.
- **First-Time Setup**: Path validation check and auto-discovery on initial run.
- **Instant Caching**: Discovered accounts and configs are cached (`accounts.json`, `<Account>-Configs.json`) so startup remains instantaneous.
- **Detached Process Execution**: Runs each AstraBot instance independently with custom `--datFile`, `--client`, and `--config` arguments.
- **Staggered Delays**: Configurable pause (default 400ms) between launches to avoid server throttling.

## Download & Quick Start

1. Go to the **[Latest Release](https://github.com/Joshh3ro/astra_lawnchair/releases/latest)** page.
2. Grab the latest `AstraLawnchair.exe` standalone build.
3. Launch it directly — no Dart SDK or dependencies needed!

## Hotkeys

| Key | Action |
|---|---|
| `↑` / `↓` | Move focus up/down within current list |
| `Enter` | Dig into focused account's Config List / inspect telemetry |
| `Space` | Toggle focused item into / out of launch queue |
| `Backspace` | Return to previous view / Top Menu |
| `Esc` | Open Quick Menu & Hotkey Cheatsheet modal (with direct Settings jump) |
| `G` | Toggle into / out of Unified Stats & Fleet Command Matrix |
| `Shift+L` | Sweep stale bot logs across all accounts (safe session protection) |
| `R` | Run all queued account/config pairs |
| `S` | Hot-swap focused config or restart running bot session |
| `Shift+S` | Batch switch all selected or matching account configs at once |
| `C` | Copy focused config to other accounts interactively (Yellow mode) |
| `K` | Terminate focused running bot process |
| `O` | Toggle Obfuscate / Streamer Mode |
| `Shift+R` | Refresh accounts and configs from disk |
| `Q` | Quit application |

## Console Launch Options (`astral`)

Astra Lawnchair can be invoked directly from the terminal via the **`astral`** CLI command (or `astra_lawnchair`), providing flexible startup parameters and headless utility commands.

### Running with `astral`

If Astra Lawnchair is in your `PATH` or activated globally:
```bash
# Activate locally from source repository
dart pub global activate .

# Launch directly using the astral command
astral [OPTIONS]
```
Or execute directly via the Dart CLI:
```bash
dart run bin/astral.dart [OPTIONS]
```

### Command-Line Arguments Reference

| Option | Shorthand | Argument | Description |
|---|---|---|---|
| `--root` | `-r` | `<path>` | Set or override the AstraBot root directory path |
| `--client` | `-c` | `<name>` | Override bot client parameter (e.g. `Unity` or `Flash`) |
| `--stagger` | `-s` | `<ms>` | Set process launch stagger delay in milliseconds (e.g. `500`) |
| `--streamer` | `-o` | None | Launch immediately with Streamer Mode / Obfuscation enabled |
| `--fleet` | `-g` | None | Open directly into the Fleet Command Matrix view |
| `--stats` | | None | Open directly into the Account Stats view |
| `--dry-run` | | None | Enable dry-run mode (simulates launches without spawning processes) |
| `--clean-logs` | | None | Headless: sweep stale logs across all accounts and exit |
| `--fleet-stats`| | None | Headless: output current fleet session telemetry to stdout and exit |
| `--version` | `-v` | None | Display application version information and exit |
| `--help` | `-h` | None | Display terminal usage documentation and exit |

### Examples

- **Quick Launch into Fleet Matrix with Obfuscation**:
  ```bash
  astral -o -g
  ```
- **Pre-set Custom Bot Directory and 500ms Launch Stagger**:
  ```bash
  astral -r "C:\MyBots" -s 500 -c Unity
  ```
- **Headless Stale Log Cleanup (Automated or Cron script)**:
  ```bash
  astral -r "C:\MyBots" --clean-logs
  ```
  *Output:* `[astral] Cleaned 38 stale logs across 6 accounts (14.2 MB recovered). Active bots protected: 2.`
- **Print Current Fleet Telemetry to Console**:
  ```bash
  astral --fleet-stats
  ```
  *Output:*
  ```
  === FLEET TELEMETRY SNAPSHOT (2026-10-23 10:15:00) ===
  Session:     session_1792743300000
  Bots:        4 / 6 running
  Uridium:     +185,400 (+42,500/h)
  Experience:  +4,250,000 (+950,000/h)
  Honor:       +82,000 (+18,000/h)
  Credits:     +14,200,000
  Deaths:      1
  ```

## Running & Building

### Run Directly (No build required)
```bash
dart run bin/astral.dart
```

### Run with Stateful Hot Reload
```bash
dart --enable-vm-service bin/astral.dart
```

### Build Native Standalone Executable (Optional)
```bash
dart compile exe bin/astral.dart -o AstraLawnchair.exe
```
