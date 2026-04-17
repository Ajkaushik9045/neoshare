import 'package:flutter/services.dart';

/// Input formatter for NeoShare short codes.
///
/// Keeps only 6 valid characters and does not auto-insert separators.
class ShortCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll(RegExp(r'[^A-HJ-KM-NP-Z2-9]'), '');

    final limited = raw.length > 6 ? raw.substring(0, 6) : raw;

    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}
