import 'dart:io';
import 'package:nocterm/nocterm.dart';
import '../../models/app_config.dart';
import '../../services/config_service.dart';
import '../../services/scanner_service.dart';
import '../theme.dart';

class SetupScreen extends StatefulComponent {
  final ConfigService configService;
  final ScannerService scannerService;
  final void Function(AppConfig config) onSetupComplete;

  const SetupScreen({
    super.key,
    required this.configService,
    required this.scannerService,
    required this.onSetupComplete,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pathController = TextEditingController();
  String _errorMessage = '';
  bool _isScanning = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _submitPath() async {
    final rawPath = _pathController.text.trim();
    if (rawPath.isEmpty) {
      setState(() {
        _errorMessage = 'Path cannot be empty.';
      });
      return;
    }

    final dir = Directory(rawPath);
    if (!dir.existsSync()) {
      setState(() {
        _errorMessage = 'Folder does not exist: $rawPath';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = '';
    });

    try {
      final config = AppConfig(rootPath: dir.path);
      await component.configService.saveConfig(config);

      // Initial scan and cache
      await component.scannerService.scanAndCache(dir.path);

      component.onSetupComplete(config);
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Error saving setup: $e';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: BoxBorder.all(color: LawnchairTheme.borderFocused),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Astra Lawnchair — Initial Setup',
              style: LawnchairTheme.titleStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Where are your AstraBot account folders?',
              style: TextStyle(color: Colors.white),
            ),
            const Text(
              'Enter the path to the root folder (e.g. E:\\darkorbit\\AstraBot):',
              style: TextStyle(color: Colors.gray),
            ),
            const SizedBox(height: 1),
            TextField(
              controller: _pathController,
              focused: true,
              decoration: InputDecoration(
                border: BoxBorder.all(color: Colors.white),
                hintText: 'Enter directory path...',
              ),
              onSubmitted: (_) {
                if (!_isScanning) {
                  _submitPath();
                }
              },
              onKeyEvent: (event) {
                if (event.logicalKey == LogicalKey.enter) {
                  if (!_isScanning) {
                    _submitPath();
                  }
                  return true;
                } else if (event.character?.toLowerCase() == 'q' && _pathController.text.isEmpty) {
                  shutdownApp();
                }
                return false;
              },
            ),
            const SizedBox(height: 1),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: LawnchairTheme.statusError,
              ),
            if (_isScanning)
              const Text(
                'Scanning account folders and caching configs...',
                style: LawnchairTheme.statusInfo,
              ),
            const SizedBox(height: 1),
            const Divider(),
            const SizedBox(height: 1),
            const Text(
              'Press [Enter] to continue | [Q] to quit (when input is empty)',
              style: LawnchairTheme.footerDesc,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
