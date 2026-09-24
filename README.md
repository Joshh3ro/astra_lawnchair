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
| `Enter` | Dig into focused account's Config List |
| `Space` | Toggle focused item into / out of launch queue |
| `Backspace` | Return from Config List to Account List |
| `R` | Run all queued account/config pairs |
| `S` | Hot-swap focused config or restart running bot session |
| `Shift+S` | Batch switch all selected or matching account configs at once |
| `C` | Copy focused config to other accounts interactively (Yellow mode) |
| `K` | Terminate focused running bot process |
| `O` | Toggle Obfuscate / Streamer Mode |
| `Shift+R` | Refresh accounts and configs from disk |
| `Q` | Quit application |

## Running & Building

### Run Directly (No build required)
```bash
dart run bin/astra_lawnchair.dart
```

### Run with Stateful Hot Reload
```bash
dart --enable-vm-service bin/astra_lawnchair.dart
```

### Build Native Standalone Executable (Optional)
```bash
dart compile exe bin/astra_lawnchair.dart -o AstraLawnchair.exe
```
