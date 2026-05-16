/// Centralized payment method constants.
///
/// Use these values whenever reading or writing payment_method in the DB.
/// Do NOT use raw string literals like 'cash', 'card', 'bank' elsewhere.
class PaymentMethod {
  const PaymentMethod._();

  static const String cash = 'cash';
  static const String card = 'card';
  static const String bank = 'bank';

  /// All valid payment method values for validation / UI rendering.
  static const List<String> values = <String>[cash, card, bank];

  /// Human-readable display labels keyed by value.
  static const Map<String, String> labels = <String, String>{
    cash: 'Cash',
    card: 'Card',
    bank: 'Bank Transfer',
  };

  /// Returns true if [value] is one of the known payment methods.
  static bool isValid(String? value) =>
      value != null && values.contains(value);

  /// Trims and validates payment method.
  ///
  /// Returns `null` when the value is empty or not one of the allowed payment
  /// methods.
  static String? normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return isValid(trimmed) ? trimmed : null;
  }

  static String normalizeOrDefault(
    String? value, {
    String fallback = cash,
  }) {
    return normalizeNullable(value) ?? fallback;
  }
}
