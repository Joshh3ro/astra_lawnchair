import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class ListItemRow extends StatelessComponent {
  final String title;
  final String? subtitle;
  final bool subtitleBelow;
  final bool isFocused;
  final bool isSelected;
  final bool showCheckbox;
  final String? badge;
  final TextStyle? badgeStyle;
  final TextStyle? selectedStyle;
  final TextStyle? selectedAndFocusedStyle;
  final VoidCallback? onTap;

  const ListItemRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleBelow = false,
    this.badge,
    this.badgeStyle,
    this.selectedStyle,
    this.selectedAndFocusedStyle,
    this.isFocused = false,
    this.isSelected = false,
    this.showCheckbox = false,
    this.onTap,
  });

  @override
  Component build(BuildContext context) {
    // Determine style based on focused and selected
    TextStyle textStyle;
    if (isSelected && isFocused) {
      textStyle = selectedAndFocusedStyle ?? LawnchairTheme.itemSelectedAndFocused;
    } else if (isFocused) {
      textStyle = LawnchairTheme.itemFocused;
    } else if (isSelected) {
      textStyle = selectedStyle ?? LawnchairTheme.itemSelected;
    } else {
      textStyle = LawnchairTheme.itemNormal;
    }

    final focusPrefix = isFocused ? '> ' : '  ';
    final checkPrefix = showCheckbox ? (isSelected ? '[x] ' : '[ ] ') : '';

    Component content;
    if (subtitleBelow && subtitle != null && subtitle!.isNotEmpty) {
      // Subtitle rendered on its own indented line below title
      final descStyle = isFocused ? textStyle : LawnchairTheme.footerDesc;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$focusPrefix$checkPrefix$title', style: textStyle),
              if (badge != null) ...[
                const SizedBox(width: 1),
                Text(badge!, style: isFocused ? textStyle : (badgeStyle ?? LawnchairTheme.badgeRunning)),
              ],
            ],
          ),
          Text('    $subtitle', style: descStyle),
        ],
      );
    } else {
      content = Row(
        children: [
          Text('$focusPrefix$checkPrefix$title${subtitle != null ? ' $subtitle' : ''}', style: textStyle),
          if (badge != null) ...[
            const SizedBox(width: 1),
            Text(badge!, style: isFocused ? textStyle : (badgeStyle ?? LawnchairTheme.badgeRunning)),
          ],
        ],
      );
    }

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
