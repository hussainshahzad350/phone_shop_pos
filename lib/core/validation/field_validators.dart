import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

/// Single source of truth for form-field validation rules that were
/// previously duplicated (byte-for-byte, in some cases) across repositories
/// and form widgets — e.g. the IMEI format regex existed identically in 6
/// separate files. Callers should use these instead of re-implementing the
/// same check inline.
class FieldValidators {
  const FieldValidators._();

  static final RegExp _imeiPattern = RegExp(r'^\d{14,15}$');
  static final RegExp _phonePattern = RegExp(r'^\+?\d{7,15}$');

  /// True when [value] is a valid 14–15 digit IMEI. Does not trim — callers
  /// should pass an already-trimmed value.
  static bool isValidImei(String value) => _imeiPattern.hasMatch(value);

  /// `Form` field validator for a required IMEI (e.g. IMEI1).
  static String? imei(String? value, {String label = 'IMEI'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '$label is required';
    }
    if (!isValidImei(trimmed)) {
      return 'Must be 14–15 digits';
    }
    return null;
  }

  /// `Form` field validator for an optional IMEI (e.g. IMEI2).
  static String? optionalImei(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (!isValidImei(trimmed)) {
      return 'Must be 14–15 digits';
    }
    return null;
  }

  /// Lenient phone-number check: digits with an optional leading `+`,
  /// 7–15 digits total. Treats an empty value as valid — phone number is an
  /// optional field throughout this app; this only rejects malformed input,
  /// it does not make the field required.
  static String? phone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// `Form` field validator rejecting a negative price. Parses via the
  /// existing locale-aware [FormattingHelpers.parseLocaleDecimal].
  static String? nonNegativePrice(String? value, {String label = 'price'}) {
    final parsed = FormattingHelpers.parseLocaleDecimal(value ?? '', fallback: -1);
    return parsed < 0 ? 'Enter a valid $label' : null;
  }

  /// Generic required-text check, e.g. for brand/model/supplier/customer name
  /// fields.
  static String? requiredText(String? value, {String label = 'This field'}) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }
}
