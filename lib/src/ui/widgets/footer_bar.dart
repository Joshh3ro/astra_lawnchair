import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class FooterBar extends StatelessComponent {
  final String statusMessage;
  final TextStyle? statusStyle;
  final String runHotkey;

  const FooterBar({
    super.key,
    this.statusMessage = '',
    this.statusStyle,
    this.runHotkey = 'R',
  });

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
              const Text(
                'Astra Lawnchair v0.1.0',
                style: LawnchairTheme.footerDesc,
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
