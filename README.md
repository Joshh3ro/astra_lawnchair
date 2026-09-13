<img width="1919" height="1079" alt="image" src="https://github.com/user-attachments/assets/cb95e2e2-1eab-47e8-9753-10b6b571423a" />

# Astra Lawnchair

*(A relaxed place to sit while your bots log in. Formerly known as "Astra Launcher." ill probably be changing the name to "Astral Lawnchair")*

A Dart terminal UI (TUI) app, built with the **Nocterm** framework, that replaces a folder full of hand-written `.bat` launcher files. It scans a directory of AstraBot account folders, lets the user pick one or more accounts and one or more configs per account, and launches all selected account/config combinations at once as detached processes with staggered intervals.

## Features

- **Nocterm TUI Interface**: Dual-pane keyboard & mouse driven interface with focus/selection differentiation.
- **First-Time Setup**: Path validation check and auto-discovery on initial run.
- **Instant Caching**: Discovered accounts and configs are cached (`accounts.json`, `<Account>-Configs.json`) so startup remains instantaneous.
- **Detached Process Execution**: Runs each AstraBot instance independently with custom `--datFile`, `--client`, and `--config` arguments.
- **Staggered Delays**: Configurable pause (default 400ms) between launches to avoid server throttling.

## Hotkeys

| Key | Action |
|---|---|
| `↑` / `↓` | Move focus up/down within current list |
| `Enter` | Drill down into focused account's Config List |
| `Space` | Toggle focused item into / out of launch queue |
| `Backspace` | Return from Config List to Account List |
| `R` | Run all queued account/config pairs |
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
