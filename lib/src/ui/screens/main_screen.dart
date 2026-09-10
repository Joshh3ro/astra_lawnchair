import 'dart:io';
import 'package:nocterm/nocterm.dart';
import '../../models/account.dart';
import '../../models/app_config.dart';
import '../../models/launch_target.dart';
import '../../services/launcher_service.dart';
import '../../services/scanner_service.dart';
import '../theme.dart';
import '../widgets/footer_bar.dart';
import '../widgets/list_item_row.dart';
import '../widgets/pane_box.dart';

enum MenuLevel { accounts, configs }

class MainScreen extends StatefulComponent {
  final AppConfig config;
  final ScannerService scannerService;
  final LauncherService launcherService;
  final List<Account> initialAccounts;

  const MainScreen({
    super.key,
    required this.config,
    required this.scannerService,
    required this.launcherService,
    required this.initialAccounts,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late List<Account> _accounts;
  final List<LaunchTarget> _selectedQueue = [];

  MenuLevel _menuLevel = MenuLevel.accounts;
  Account? _activeAccount;

  int _focusedAccountIndex = 0;
  int _focusedConfigIndex = 0;

  String _statusMessage = '';
  TextStyle? _statusStyle;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _accounts = List.from(component.initialAccounts);
  }

  void _setStatus(String msg, [TextStyle? style]) {
    setState(() {
      _statusMessage = msg;
      _statusStyle = style;
    });
  }

  void _moveFocusUp() {
    setState(() {
      if (_menuLevel == MenuLevel.accounts) {
        if (_focusedAccountIndex > 0) {
          _focusedAccountIndex--;
        }
      } else {
        if (_focusedConfigIndex > 0) {
          _focusedConfigIndex--;
        }
      }
    });
  }

  void _moveFocusDown() {
    setState(() {
      if (_menuLevel == MenuLevel.accounts) {
        if (_focusedAccountIndex < _accounts.length - 1) {
          _focusedAccountIndex++;
        }
      } else {
        final configs = _activeAccount?.configs ?? [];
        if (_focusedConfigIndex < configs.length - 1) {
          _focusedConfigIndex++;
        }
      }
    });
  }

  void _drillIntoAccount(Account account) {
    setState(() {
      _activeAccount = account;
      _menuLevel = MenuLevel.configs;
      _focusedConfigIndex = 0;
      _setStatus('Viewing configs for "${account.name}". Press Space to toggle, Backspace to return.');
    });
  }

  void _popToAccounts() {
    setState(() {
      _menuLevel = MenuLevel.accounts;
      _activeAccount = null;
      _setStatus('Returned to Accounts list.');
    });
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

  void _toggleCurrentFocusedItem() {
    if (_menuLevel == MenuLevel.accounts) {
      if (_accounts.isEmpty) return;
      final account = _accounts[_focusedAccountIndex];
      _drillIntoAccount(account);
    } else {
      final account = _activeAccount;
      if (account == null || account.configs.isEmpty) return;
      final configName = account.configs[_focusedConfigIndex];
      _toggleConfigSelection(account, configName);
    }
  }

  Future<void> _refreshFromDisk() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _setStatus('Refreshing accounts and configs from disk...', LawnchairTheme.statusInfo);
    });

    try {
      final updatedAccounts = await component.scannerService.scanAndCache(component.config.rootPath);
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
              _focusedConfigIndex = _activeAccount!.configs.isEmpty ? 0 : _activeAccount!.configs.length - 1;
            }
          } else {
            _popToAccounts();
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
      _setStatus('No accounts/configs selected to run. Select configs with Space first.', LawnchairTheme.statusInfo);
      return;
    }

    setState(() {
      _isBusy = true;
      _setStatus('Preparing to launch ${_selectedQueue.length} instances...', LawnchairTheme.statusInfo);
    });

    try {
      final results = await component.launcherService.launchAll(
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
      if (_menuLevel == MenuLevel.accounts) {
        if (_accounts.isNotEmpty) {
          _drillIntoAccount(_accounts[_focusedAccountIndex]);
        }
      } else {
        _toggleCurrentFocusedItem();
      }
      return true;
    }

    // Backspace: Pop up
    if (event.logicalKey == LogicalKey.backspace) {
      if (_menuLevel == MenuLevel.configs) {
        _popToAccounts();
        return true;
      }
    }

    // Space: Toggle selection
    if (event.logicalKey == LogicalKey.space) {
      _toggleCurrentFocusedItem();
      return true;
    }

    return false;
  }

  @override
  Component build(BuildContext context) {
    final leftPaneTitle = _menuLevel == MenuLevel.accounts
        ? 'MENU (Accounts) [${_accounts.length}]'
        : 'MENU: ${_activeAccount?.name ?? ""} (${_activeAccount?.configs.length ?? 0} configs)';

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
                  'Root: ${component.config.rootPath}',
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

                // Right Pane: Selected / Staged Queue
                Expanded(
                  child: PaneBox(
                    title: 'SELECTED (queued to launch) [${_selectedQueue.length}]',
                    isFocused: false,
                    child: _buildRightPaneContent(),
                  ),
                ),
              ],
            ),
          ),

          // Footer & Status Bar
          FooterBar(
            statusMessage: _statusMessage,
            statusStyle: _statusStyle,
            runHotkey: component.config.runHotkey,
          ),
        ],
      ),
    );
  }

  Component _buildLeftPaneContent() {
    if (_menuLevel == MenuLevel.accounts) {
      if (_accounts.isEmpty) {
        return const Center(
          child: Text(
            'No account folders found.\nPress Shift+R to refresh or check root path.',
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
          
          // Count how many configs of this account are currently queued
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
    } else {
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
    }
  }

  Component _buildRightPaneContent() {
    if (_selectedQueue.isEmpty) {
      return const Center(
        child: Text(
          'Launch queue is empty.\nSelect configs from the left menu with Space.',
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
}
