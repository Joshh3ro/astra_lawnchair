import 'dart:io';
import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class FooterBar extends StatelessComponent {
  final String statusMessage;
  final TextStyle? statusStyle;
  final String runHotkey;
  final bool isObfuscated;

  const FooterBar({
    super.key,
    this.statusMessage = '',
    this.statusStyle,
    this.runHotkey = 'R',
    this.isObfuscated = false,
  });

  static Future<void> _openUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            children: [
              Text(
                statusMessage.isNotEmpty ? statusMessage : 'Ready',
                style: statusStyle ?? LawnchairTheme.statusInfo,
              ),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Joshh3ro | v0.1.4 | ',
                    style: LawnchairTheme.footerDesc,
                  ),
                  GestureDetector(
                    onTap: () => _openUrl('https://github.com/Joshh3ro/astra-lawnchair'),
                    child: const Text(
                      '(GitHub)',
                      style: LawnchairTheme.footerLink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Row(
            children: [
              _keyItem('Space', 'select'),
              const SizedBox(width: 2),
              _keyItem('Enter', 'open'),
              const SizedBox(width: 2),
              _keyItem('Backspace', 'back'),
              const SizedBox(width: 2),
              _keyItem(runHotkey, 'run'),
              const SizedBox(width: 2),
              _keyItem('K', 'kill'),
              const SizedBox(width: 2),
              _keyItem('O', isObfuscated ? 'reveal' : 'hide'),
              const SizedBox(width: 2),
              _keyItem('Shift+R', 'refresh'),
              const SizedBox(width: 2),
              _keyItem('Q', 'quit'),
            ],
          ),
        ),
      ],
    );
  }

  Component _keyItem(String key, String desc) {
    return Row(
      children: [
        Text(key, style: LawnchairTheme.footerKey),
        const Text(': ', style: LawnchairTheme.footerDesc),
        Text(desc, style: LawnchairTheme.footerDesc),
      ],
    );
  }
}
