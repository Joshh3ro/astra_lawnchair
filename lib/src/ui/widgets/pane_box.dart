import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class PaneBox extends StatelessComponent {
  final String title;
  final bool isFocused;
  final Component child;

  const PaneBox({
    super.key,
    required this.title,
    required this.child,
    this.isFocused = false,
  });

  @override
  Component build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: BoxBorder.all(
          color: isFocused ? LawnchairTheme.borderFocused : LawnchairTheme.borderNormal,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              title,
              style: isFocused
                  ? LawnchairTheme.paneHeaderFocused
                  : LawnchairTheme.paneHeaderNormal,
            ),
          ),
          const Divider(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
