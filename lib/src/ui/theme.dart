import 'package:nocterm/nocterm.dart';

class LawnchairTheme {
  // Border colors
  static const Color borderNormal = Colors.gray;
  static const Color borderFocused = Colors.cyan;

  // Header & Title
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle paneHeaderFocused = TextStyle(
    color: Colors.cyan,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle paneHeaderNormal = TextStyle(
    color: Colors.gray,
    fontWeight: FontWeight.bold,
  );

  // Item states
  static const TextStyle itemNormal = TextStyle(
    color: Colors.white,
  );

  static const TextStyle itemFocused = TextStyle(
    color: Colors.black,
    backgroundColor: Colors.cyan,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle itemSelected = TextStyle(
    color: Colors.green,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle itemSelectedAndFocused = TextStyle(
    color: Colors.black,
    backgroundColor: Colors.green,
    fontWeight: FontWeight.bold,
  );

  // Footer & Status
  static const TextStyle footerKey = TextStyle(
    color: Colors.cyan,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle footerDesc = TextStyle(
    color: Colors.gray,
  );

  static const TextStyle footerLink = TextStyle(
    color: Colors.cyan,
    decoration: TextDecoration.underline,
  );

  static const TextStyle statusSuccess = TextStyle(
    color: Colors.green,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statusError = TextStyle(
    color: Colors.red,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statusInfo = TextStyle(
    color: Colors.yellow,
  );

  static const TextStyle statusRunning = TextStyle(
    color: Colors.green,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle badgeRunning = TextStyle(
    color: Colors.green,
  );

  // Statistics theme styles
  static const TextStyle statValueHighlight = TextStyle(
    color: Colors.cyan,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statRate = TextStyle(
    color: Colors.green,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statDeathWarning = TextStyle(
    color: Colors.red,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statSectionHeader = TextStyle(
    color: Colors.yellow,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle statSubSectionHeader = TextStyle(
    color: Colors.cyan,
    fontWeight: FontWeight.bold,
  );
}
