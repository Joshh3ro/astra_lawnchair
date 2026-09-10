import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class ListItemRow extends StatelessComponent {
  final String title;
  final String? subtitle;
  final bool isFocused;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback? onTap;

  const ListItemRow({
    super.key,
    required this.title,
    this.subtitle,
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
      textStyle = LawnchairTheme.itemSelectedAndFocused;
    } else if (isFocused) {
      textStyle = LawnchairTheme.itemFocused;
    } else if (isSelected) {
      textStyle = LawnchairTheme.itemSelected;
    } else {
      textStyle = LawnchairTheme.itemNormal;
    }

    final focusPrefix = isFocused ? '> ' : '  ';
    final checkPrefix = showCheckbox ? (isSelected ? '[x] ' : '[ ] ') : '';
    final displayText = '$focusPrefix$checkPrefix$title${subtitle != null ? ' $subtitle' : ''}';

    Component content = Text(
      displayText,
      style: textStyle,
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
