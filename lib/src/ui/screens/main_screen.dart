import 'dart:io';
import 'package:nocterm/nocterm.dart';
import '../../models/account.dart';
import '../../models/app_config.dart';
import '../../models/launch_target.dart';
import '../../services/config_service.dart';
import '../../services/launcher_service.dart';
import '../../services/scanner_service.dart';
import '../theme.dart';
import '../widgets/footer_bar.dart';
import '../widgets/list_item_row.dart';
import '../widgets/pane_box.dart';

enum NavigationLevel { topMenu, accounts, configs, settings, editingRootPath }

enum TopMenuItem {
  accounts('Accounts', 'Manage accounts and queue bots'),
  hotkeys('Hotkeys', 'Keyboard shortcuts & navigation'),
  settings('Settings', 'App preferences & launch parameters'),
  quit('Quit', 'Exit Astra Lawnchair');

  final String label;
  final String description;
  const TopMenuItem(this.label, this.description);
}

enum SettingsItem {
  client('Client Parameter', 'Toggle between Unity and Flash client mode'),
  stagger('Launch Stagger Delay', 'Pause duration between bot launches'),
  rootPath('Root Folder Path', 'Base directory containing AstraBot accounts'),
  back('[< Back to Top Menu]', 'Return to top-level menu');

  final String label;
  final String description;
  const SettingsItem(this.label, this.description);
}

class MainScreen extends StatefulComponent {
  final AppConfig config;
  final ConfigService? configService;
  final ScannerService scannerService;
  final LauncherService launcherService;
  final List<Account> initialAccounts;

  const MainScreen({
    super.key,
    required this.config,
    this.configService,
    required this.scannerService,
    required this.launcherService,
    required this.initialAccounts,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AppConfig _currentConfig;
  late List<Account> _accounts;
  final List<LaunchTarget> _selectedQueue = [];

  NavigationLevel _navLevel = NavigationLevel.topMenu;
  Account? _activeAccount;

  int _focusedTopMenuIndex = 0;
  int _focusedAccountIndex = 0;
  int _focusedConfigIndex = 0;
  int _focusedSettingsIndex = 0;

  final _rootPathController = TextEditingController();
  String _settingsErrorMessage = '';

  String _statusMessage = '';
  TextStyle? _statusStyle;
  bool _isBusy = false;

  static const List<int> _staggerPresets = [200, 300, 400, 500, 750, 1000];

  @override
  void initState() {
    super.initState();
    _currentConfig = component.config;
    _accounts = List.from(component.initialAccounts);
  }

  @override
  void dispose() {
    _rootPathController.dispose();
    super.dispose();
  }

  void _setStatus(String msg, [TextStyle? style]) {
    setState(() {
      _statusMessage = msg;
      _statusStyle = style;
    });
  }

  void _moveFocusUp() {
    setState(() {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          if (_focusedTopMenuIndex > 0) {
            _focusedTopMenuIndex--;
          }
          break;
        case NavigationLevel.accounts:
          if (_focusedAccountIndex > 0) {
            _focusedAccountIndex--;
          }
          break;
        case NavigationLevel.configs:
          if (_focusedConfigIndex > 0) {
            _focusedConfigIndex--;
          }
          break;
        case NavigationLevel.settings:
          if (_focusedSettingsIndex > 0) {
            _focusedSettingsIndex--;
          }
          break;
        case NavigationLevel.editingRootPath:
          break;
      }
    });
  }

  void _moveFocusDown() {
    setState(() {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          if (_focusedTopMenuIndex < TopMenuItem.values.length - 1) {
            _focusedTopMenuIndex++;
          }
          break;
        case NavigationLevel.accounts:
          if (_focusedAccountIndex < _accounts.length - 1) {
            _focusedAccountIndex++;
          }
          break;
        case NavigationLevel.configs:
          final configs = _activeAccount?.configs ?? [];
          if (_focusedConfigIndex < configs.length - 1) {
            _focusedConfigIndex++;
          }
          break;
        case NavigationLevel.settings:
          if (_focusedSettingsIndex < SettingsItem.values.length - 1) {
            _focusedSettingsIndex++;
          }
          break;
        case NavigationLevel.editingRootPath:
          break;
      }
    });
  }

  void _activateTopMenuItem(TopMenuItem item) {
    switch (item) {
      case TopMenuItem.accounts:
        setState(() {
          _navLevel = NavigationLevel.accounts;
          _setStatus('Accounts Menu: Press Enter to view configs, Backspace to return to Top Menu.');
        });
        break;
      case TopMenuItem.hotkeys:
        _setStatus('Viewing Hotkeys reference in right panel.');
        break;
      case TopMenuItem.settings:
        setState(() {
          _navLevel = NavigationLevel.settings;
          _focusedSettingsIndex = 0;
          _setStatus('Settings: Press Enter/Space to adjust or edit options, Backspace to go back.');
        });
        break;
      case TopMenuItem.quit:
        exit(0);
    }
  }

  void _drillIntoAccount(Account account) {
    setState(() {
      _activeAccount = account;
      _navLevel = NavigationLevel.configs;
      _focusedConfigIndex = 0;
      _setStatus('Viewing configs for "${account.name}". Press Space to toggle, Backspace to return.');
    });
  }

  void _popNavigation() {
    setState(() {
      if (_navLevel == NavigationLevel.editingRootPath) {
        _navLevel = NavigationLevel.settings;
        _settingsErrorMessage = '';
        _setStatus('Cancelled path editing.');
      } else if (_navLevel == NavigationLevel.configs) {
        _navLevel = NavigationLevel.accounts;
        _activeAccount = null;
        _setStatus('Returned to Accounts list.');
      } else if (_navLevel == NavigationLevel.accounts || _navLevel == NavigationLevel.settings) {
        _navLevel = NavigationLevel.topMenu;
        _setStatus('Returned to Top Menu.');
      }
    });
  }

  Future<void> _persistConfig(AppConfig newConfig) async {
    setState(() {
      _currentConfig = newConfig;
    });
    if (component.configService != null) {
      await component.configService!.saveConfig(newConfig);
    }
  }

  void _toggleClientMode() async {
    final nextClient = _currentConfig.clientName.toLowerCase() == 'unity' ? 'Flash' : 'Unity';
    final updated = _currentConfig.copyWith(clientName: nextClient);
    await _persistConfig(updated);
    _setStatus('Client parameter set to: $nextClient', LawnchairTheme.statusSuccess);
  }

  void _cycleStaggerDelay() async {
    final current = _currentConfig.staggerDelayMs;
    int nextDelay = _staggerPresets.first;
    for (int i = 0; i < _staggerPresets.length; i++) {
      if (_staggerPresets[i] == current) {
        nextDelay = _staggerPresets[(i + 1) % _staggerPresets.length];
        break;
      }
    }
    final updated = _currentConfig.copyWith(staggerDelayMs: nextDelay);
    await _persistConfig(updated);
    _setStatus('Launch stagger delay set to: $nextDelay ms', LawnchairTheme.statusSuccess);
  }

  void _startEditingRootPath() {
    setState(() {
      _navLevel = NavigationLevel.editingRootPath;
      _rootPathController.text = _currentConfig.rootPath;
      _settingsErrorMessage = '';
      _setStatus('Type new root directory path and press Enter to save.');
    });
  }

  Future<void> _submitRootPath() async {
    final rawPath = _rootPathController.text.trim();
    if (rawPath.isEmpty) {
      setState(() {
        _settingsErrorMessage = 'Path cannot be empty.';
      });
      return;
    }

    final dir = Directory(rawPath);
    if (!dir.existsSync()) {
      setState(() {
        _settingsErrorMessage = 'Folder does not exist: $rawPath';
      });
      return;
    }

    setState(() {
      _settingsErrorMessage = '';
      _navLevel = NavigationLevel.settings;
    });

    final updated = _currentConfig.copyWith(rootPath: dir.path);
    await _persistConfig(updated);
    _setStatus('Root path updated to: ${dir.path}', LawnchairTheme.statusSuccess);
    await _refreshFromDisk();
  }

  void _handleSettingsAction(SettingsItem item) {
    switch (item) {
      case SettingsItem.client:
        _toggleClientMode();
        break;
      case SettingsItem.stagger:
        _cycleStaggerDelay();
        break;
      case SettingsItem.rootPath:
        _startEditingRootPath();
        break;
      case SettingsItem.back:
        _popNavigation();
        break;
    }
  }

  bool _isConfigSelected(Account account, String configName) {
    final target = LaunchTarget(account: account, configName: configName);
    return _selectedQueue.contains(target);
  }

  void _toggleConfigSelection(Account account, String configName) {
    final target = LaunchTarget(account: account, configName: configName);
    setState(() {
      if (_selectedQueue.contains(target)) {
        _selectedQueue.remove(target);
        _setStatus('Removed "${target.displayName}" from launch queue.');
      } else {
        _selectedQueue.add(target);
        _setStatus('Added "${target.displayName}" to launch queue.');
      }
    });
  }

  Future<void> _refreshFromDisk() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _setStatus('Refreshing accounts and configs from disk...', LawnchairTheme.statusInfo);
    });

    try {
      final updatedAccounts = await component.scannerService.scanAndCache(_currentConfig.rootPath);
      setState(() {
        _accounts = updatedAccounts;
        if (_focusedAccountIndex >= _accounts.length) {
          _focusedAccountIndex = _accounts.isEmpty ? 0 : _accounts.length - 1;
        }

        // If currently drilled into an account, re-bind active account
        if (_activeAccount != null) {
          final found = _accounts.where((a) => a.name == _activeAccount!.name);
          if (found.isNotEmpty) {
            _activeAccount = found.first;
            if (_focusedConfigIndex >= _activeAccount!.configs.length) {
              _focusedConfigIndex =
                  _activeAccount!.configs.isEmpty ? 0 : _activeAccount!.configs.length - 1;
            }
          } else {
            _navLevel = NavigationLevel.accounts;
            _activeAccount = null;
          }
        }
        _isBusy = false;
        _setStatus('Refreshed ${_accounts.length} accounts from disk.', LawnchairTheme.statusSuccess);
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _setStatus('Refresh failed: $e', LawnchairTheme.statusError);
      });
    }
  }

  Future<void> _runSelected() async {
    if (_isBusy) return;
    if (_selectedQueue.isEmpty) {
      _setStatus(
        'No accounts/configs selected to run. Select configs with Space first.',
        LawnchairTheme.statusInfo,
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _setStatus('Preparing to launch ${_selectedQueue.length} instances...', LawnchairTheme.statusInfo);
    });

    try {
      final launcher = LauncherService(
        staggerDelayMs: _currentConfig.staggerDelayMs,
        clientName: _currentConfig.clientName,
        isDryRun: component.launcherService.isDryRun,
      );

      final results = await launcher.launchAll(
        _selectedQueue,
        onProgress: (target, current, total) {
          _setStatus('Launching [$current/$total]: "${target.displayName}"...', LawnchairTheme.statusInfo);
        },
      );

      final successCount = results.where((r) => r.success).length;
      final failCount = results.where((r) => !r.success).length;

      setState(() {
        _isBusy = false;
        if (failCount == 0) {
          _setStatus('Successfully launched all $successCount bot instances!', LawnchairTheme.statusSuccess);
        } else {
          final firstError = results.firstWhere((r) => !r.success).errorMessage ?? 'Unknown error';
          _setStatus('Launched $successCount bots ($failCount failed). Error: $firstError', LawnchairTheme.statusError);
        }
      });
    } catch (e) {
      setState(() {
        _isBusy = false;
        _setStatus('Launch process failed: $e', LawnchairTheme.statusError);
      });
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (_isBusy) return true;

    // Shift+R: Refresh
    if (event.isShiftPressed && event.logicalKey == LogicalKey.keyR) {
      _refreshFromDisk();
      return true;
    }

    // Q: Quit
    if (event.character?.toLowerCase() == 'q') {
      exit(0);
    }

    // R (without Shift): Run
    if (!event.isShiftPressed &&
        (event.character?.toUpperCase() == component.config.runHotkey.toUpperCase() ||
            event.logicalKey == LogicalKey.keyR)) {
      _runSelected();
      return true;
    }

    // Arrow keys
    if (event.logicalKey == LogicalKey.arrowUp) {
      _moveFocusUp();
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowDown) {
      _moveFocusDown();
      return true;
    }

    // Enter
    if (event.logicalKey == LogicalKey.enter) {
      switch (_navLevel) {
        case NavigationLevel.topMenu:
          _activateTopMenuItem(TopMenuItem.values[_focusedTopMenuIndex]);
          break;
        case NavigationLevel.accounts:
          if (_accounts.isNotEmpty) {
            _drillIntoAccount(_accounts[_focusedAccountIndex]);
          }
          break;
        case NavigationLevel.configs:
          final account = _activeAccount;
          if (account != null && account.configs.isNotEmpty) {
            final configName = account.configs[_focusedConfigIndex];
            _toggleConfigSelection(account, configName);
          }
          break;
        case NavigationLevel.settings:
          _handleSettingsAction(SettingsItem.values[_focusedSettingsIndex]);
          break;
        case NavigationLevel.editingRootPath:
          _submitRootPath();
          break;
      }
      return true;
    }

    // Backspace: Pop back
    if (event.logicalKey == LogicalKey.backspace) {
      _popNavigation();
      return true;
    }

    // Space: Toggle selection in configs, open in accounts, or toggle setting
    if (event.logicalKey == LogicalKey.space) {
      if (_navLevel == NavigationLevel.configs) {
        final account = _activeAccount;
        if (account != null && account.configs.isNotEmpty) {
          final configName = account.configs[_focusedConfigIndex];
          _toggleConfigSelection(account, configName);
        }
      } else if (_navLevel == NavigationLevel.accounts) {
        if (_accounts.isNotEmpty) {
          _drillIntoAccount(_accounts[_focusedAccountIndex]);
        }
      } else if (_navLevel == NavigationLevel.topMenu) {
        _activateTopMenuItem(TopMenuItem.values[_focusedTopMenuIndex]);
      } else if (_navLevel == NavigationLevel.settings) {
        _handleSettingsAction(SettingsItem.values[_focusedSettingsIndex]);
      }
      return true;
    }

    return false;
  }

  @override
  Component build(BuildContext context) {
    String leftPaneTitle;
    switch (_navLevel) {
      case NavigationLevel.topMenu:
        leftPaneTitle = 'MENU: Astra Lawnchair';
        break;
      case NavigationLevel.accounts:
        leftPaneTitle = 'MENU: Accounts [${_accounts.length}]';
        break;
      case NavigationLevel.configs:
        leftPaneTitle = 'MENU: ${_activeAccount?.name ?? ""} (${_activeAccount?.configs.length ?? 0} configs)';
        break;
      case NavigationLevel.settings:
        leftPaneTitle = 'MENU: Settings';
        break;
      case NavigationLevel.editingRootPath:
        leftPaneTitle = 'SETTINGS: Edit Root Path';
        break;
    }

    return Focusable(
      focused: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              children: [
                const Text(
                  'Astra Lawnchair',
                  style: LawnchairTheme.titleStyle,
                ),
                const SizedBox(width: 2),
                Text(
                  'Root: ${_currentConfig.rootPath}',
                  style: LawnchairTheme.footerDesc,
                ),
                const Spacer(),
                if (_isBusy)
                  const Text('BUSY', style: LawnchairTheme.statusInfo),
              ],
            ),
          ),
          const Divider(),

          // Main Split Pane
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Pane: Menu Stack
                Expanded(
                  child: PaneBox(
                    title: leftPaneTitle,
                    isFocused: true,
                    child: _buildLeftPaneContent(),
                  ),
                ),

                // Right Pane: Contextual (Selected Queue / Hotkeys / Settings)
                Expanded(
                  child: _buildRightPane(),
                ),
              ],
            ),
          ),

          // Footer & Status Bar
          FooterBar(
            statusMessage: _statusMessage,
            statusStyle: _statusStyle,
            runHotkey: _currentConfig.runHotkey,
          ),
        ],
      ),
    );
  }

  Component _buildLeftPaneContent() {
    switch (_navLevel) {
      case NavigationLevel.topMenu:
        return ListView.builder(
          itemCount: TopMenuItem.values.length,
          itemBuilder: (context, index) {
            final item = TopMenuItem.values[index];
            final isFocused = index == _focusedTopMenuIndex;

            String title = item.label;
            String subtitle = item.description;

            if (item == TopMenuItem.accounts) {
              final queued = _selectedQueue.length;
              title = queued > 0
                  ? 'Accounts (${_accounts.length} accounts, $queued queued)'
                  : 'Accounts (${_accounts.length} accounts)';
            }

            return Padding(
              key: ValueKey('top_menu_${item.name}'),
              padding: const EdgeInsets.only(bottom: 1),
              child: ListItemRow(
                title: title,
                subtitle: subtitle,
                subtitleBelow: true,
                isFocused: isFocused,
                isSelected: item == TopMenuItem.accounts && _selectedQueue.isNotEmpty,
                showCheckbox: false,
                onTap: () {
                  setState(() {
                    _focusedTopMenuIndex = index;
                  });
                  _activateTopMenuItem(item);
                },
              ),
            );
          },
        );

      case NavigationLevel.accounts:
        if (_accounts.isEmpty) {
          return const Center(
            child: Text(
              'No account folders found.\nPress Shift+R to refresh or Backspace to go back.',
              style: LawnchairTheme.statusInfo,
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: _accounts.length,
          itemBuilder: (context, index) {
            final account = _accounts[index];
            final isFocused = index == _focusedAccountIndex;

            final queuedCount = _selectedQueue.where((t) => t.account.name == account.name).length;
            final isSelected = queuedCount > 0;
            final subtitle = queuedCount > 0 ? '($queuedCount queued)' : '(${account.configs.length} configs)';

            return ListItemRow(
              title: account.name,
              subtitle: subtitle,
              isFocused: isFocused,
              isSelected: isSelected,
              showCheckbox: true,
              onTap: () {
                setState(() {
                  _focusedAccountIndex = index;
                });
                _drillIntoAccount(account);
              },
            );
          },
        );

      case NavigationLevel.configs:
        final account = _activeAccount;
        final configs = account?.configs ?? [];

        if (configs.isEmpty) {
          return const Center(
            child: Text(
              'No .json configs found in /configs folder.\nPress Backspace to go back.',
              style: LawnchairTheme.statusInfo,
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final configName = configs[index];
            final isFocused = index == _focusedConfigIndex;
            final isSelected = account != null && _isConfigSelected(account, configName);

            return ListItemRow(
              title: configName,
              isFocused: isFocused,
              isSelected: isSelected,
              showCheckbox: true,
              onTap: () {
                setState(() {
                  _focusedConfigIndex = index;
                });
                if (account != null) {
                  _toggleConfigSelection(account, configName);
                }
              },
            );
          },
        );

      case NavigationLevel.settings:
        return ListView.builder(
          itemCount: SettingsItem.values.length,
          itemBuilder: (context, index) {
            final item = SettingsItem.values[index];
            final isFocused = index == _focusedSettingsIndex;

            String subtitle;
            switch (item) {
              case SettingsItem.client:
                subtitle = 'Active: ${_currentConfig.clientName} (Press Space/Enter to toggle)';
                break;
              case SettingsItem.stagger:
                subtitle = 'Active: ${_currentConfig.staggerDelayMs} ms (Press Space/Enter to cycle)';
                break;
              case SettingsItem.rootPath:
                subtitle = _currentConfig.rootPath;
                break;
              case SettingsItem.back:
                subtitle = 'Return to top-level menu';
                break;
            }

            return Padding(
              key: ValueKey('setting_pad_${item.name}_${_currentConfig.clientName}_${_currentConfig.staggerDelayMs}'),
              padding: const EdgeInsets.only(bottom: 1),
              child: ListItemRow(
                key: ValueKey('setting_row_${item.name}_${_currentConfig.clientName}_${_currentConfig.staggerDelayMs}'),
                title: item.label,
                subtitle: subtitle,
                subtitleBelow: true,
                isFocused: isFocused,
                showCheckbox: false,
                onTap: () {
                  setState(() {
                    _focusedSettingsIndex = index;
                  });
                  _handleSettingsAction(item);
                },
              ),
            );
          },
        );

      case NavigationLevel.editingRootPath:
        return Container(
          padding: const EdgeInsets.all(1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter new AstraBot root folder path:', style: LawnchairTheme.titleStyle),
              const SizedBox(height: 1),
              TextField(
                controller: _rootPathController,
                focused: true,
                decoration: InputDecoration(
                  border: BoxBorder.all(color: Colors.cyan),
                  hintText: 'e.g. E:\\darkorbit\\AstraBot',
                ),
                onSubmitted: (_) => _submitRootPath(),
              ),
              const SizedBox(height: 1),
              if (_settingsErrorMessage.isNotEmpty)
                Text(_settingsErrorMessage, style: LawnchairTheme.statusError),
              const SizedBox(height: 1),
              const Text(
                'Press Enter to validate & scan | Backspace to cancel',
                style: LawnchairTheme.footerDesc,
              ),
            ],
          ),
        );
    }
  }

  Component _buildRightPane() {
    // If on Top Menu and focused on Hotkeys, show Hotkeys reference
    if (_navLevel == NavigationLevel.topMenu) {
      final activeItem = TopMenuItem.values[_focusedTopMenuIndex];
      if (activeItem == TopMenuItem.hotkeys) {
        return PaneBox(
          title: 'HOTKEYS REFERENCE',
          isFocused: false,
          child: _buildHotkeysContent(),
        );
      } else if (activeItem == TopMenuItem.settings) {
        return PaneBox(
          title: 'SETTINGS & CONFIGURATION',
          isFocused: false,
          child: _buildSettingsContent(),
        );
      }
    } else if (_navLevel == NavigationLevel.settings || _navLevel == NavigationLevel.editingRootPath) {
      return PaneBox(
        title: 'SETTINGS & CONFIGURATION',
        isFocused: false,
        child: _buildSettingsContent(),
      );
    }

    // Default right pane: Launch Queue
    return PaneBox(
      title: 'SELECTED (queued to launch) [${_selectedQueue.length}]',
      isFocused: false,
      child: _buildQueueContent(),
    );
  }

  Component _buildQueueContent() {
    if (_selectedQueue.isEmpty) {
      return const Center(
        child: Text(
          'Launch queue is empty.\nDrill into Accounts and select configs with Space.',
          style: LawnchairTheme.footerDesc,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _selectedQueue.length,
      itemBuilder: (context, index) {
        final target = _selectedQueue[index];
        return ListItemRow(
          title: target.account.name,
          subtitle: '— "${target.configName}"',
          isFocused: false,
          isSelected: true,
          showCheckbox: true,
          onTap: () {
            setState(() {
              _selectedQueue.removeAt(index);
              _setStatus('Removed "${target.displayName}" from queue.');
            });
          },
        );
      },
    );
  }

  Component _buildHotkeysContent() {
    return Container(
      padding: const EdgeInsets.all(1),
      child: ListView(
        children: [
          const Text('Navigation Controls:', style: LawnchairTheme.titleStyle),
          const SizedBox(height: 1),
          _hotkeyRow('↑ / ↓', 'Move focus cursor up or down'),
          _hotkeyRow('Enter', 'Open menu item / Drill into account / Toggle config'),
          _hotkeyRow('Space', 'Toggle config into / out of launch queue'),
          _hotkeyRow('Backspace', 'Return to previous level (Configs -> Accounts -> Top Menu)'),
          const SizedBox(height: 1),
          const Divider(),
          const SizedBox(height: 1),
          const Text('Global Actions:', style: LawnchairTheme.titleStyle),
          const SizedBox(height: 1),
          _hotkeyRow('R', 'Launch all queued accounts sequentially'),
          _hotkeyRow('Shift+R', 'Re-scan root directory and refresh cached configs'),
          _hotkeyRow('Q', 'Quit Astra Lawnchair from anywhere'),
          _hotkeyRow('Mouse Tap', 'Click any row to focus, open, or toggle'),
        ],
      ),
    );
  }

  Component _buildSettingsContent() {
    return Container(
      padding: const EdgeInsets.all(1),
      child: ListView(
        children: [
          const Text('Current Settings:', style: LawnchairTheme.titleStyle),
          const SizedBox(height: 1),
          _settingRow('Root Path', _currentConfig.rootPath),
          _settingRow('Configs Storage', 'configs/ (JSON caches and settings)'),
          _settingRow('Launch Stagger', '${_currentConfig.staggerDelayMs} ms'),
          _settingRow('Client Parameter', _currentConfig.clientName),
          _settingRow('Run Hotkey', _currentConfig.runHotkey),
          const SizedBox(height: 1),
          const Divider(),
          const SizedBox(height: 1),
          const Text(
            'Press Enter on "Settings" in the main menu to edit these values interactively.',
            style: LawnchairTheme.footerDesc,
          ),
        ],
      ),
    );
  }

  Component _hotkeyRow(String key, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Container(
            width: 14,
            child: Text(key, style: LawnchairTheme.footerKey),
          ),
          Expanded(
            child: Text(desc, style: LawnchairTheme.itemNormal),
          ),
        ],
      ),
    );
  }

  Component _settingRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label:', style: LawnchairTheme.footerKey),
          Text(value, style: LawnchairTheme.itemNormal),
        ],
      ),
    );
  }
}
