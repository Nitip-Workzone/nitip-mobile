import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatToIdr(dynamic value, {bool withSymbol = false}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: withSymbol ? 'Rp ' : '',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  static double parseIdr(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    if (newValue.text.compareTo(oldValue.text) == 0) {
      return newValue;
    }

    final double value = double.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final String newText = CurrencyFormatter.formatToIdr(value);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
