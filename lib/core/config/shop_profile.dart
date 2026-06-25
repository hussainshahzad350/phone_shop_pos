import 'dart:convert';

import 'package:phone_shop_pos/core/constants/app_constants.dart';

/// Editable shop identity used as the "letterhead" on receipts and invoices.
///
/// This is intentionally separate from `BusinessProfile` (which describes the
/// shop *vertical*, e.g. mobile vs repair). [ShopProfile] holds the free-form
/// contact details a shop owner edits from the Settings screen — shop name,
/// phone, email, address — so these are never hard-coded.
class ShopProfile {
  const ShopProfile({
    required this.shopName,
    required this.phone,
    required this.email,
    required this.address,
    this.footerNote,
  });

  final String shopName;
  final String phone;
  final String email;
  final String address;

  /// Optional line printed near the bottom of a receipt (e.g. return policy).
  final String? footerNote;

  /// Sensible default before the owner has configured anything. The shop name
  /// falls back to the app display name so an unconfigured receipt still shows
  /// something meaningful, while the contact lines stay empty (and are omitted
  /// from the receipt) until the owner fills them in.
  factory ShopProfile.unconfigured() {
    return const ShopProfile(
      shopName: AppConstants.appDisplayName,
      phone: '',
      email: '',
      address: '',
      footerNote: null,
    );
  }

  ShopProfile copyWith({
    String? shopName,
    String? phone,
    String? email,
    String? address,
    String? footerNote,
    bool clearFooterNote = false,
  }) {
    return ShopProfile(
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      footerNote: clearFooterNote ? null : footerNote ?? this.footerNote,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'shopName': shopName,
      'phone': phone,
      'email': email,
      'address': address,
      'footerNote': footerNote,
    };
  }

  String encode() => jsonEncode(toJson());

  /// Parses a persisted JSON string, returning `null` on any malformed input so
  /// callers can safely fall back to defaults.
  static ShopProfile? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final shopName = (decoded['shopName'] as String?)?.trim() ?? '';
      if (shopName.isEmpty) {
        return null;
      }
      final footer = (decoded['footerNote'] as String?)?.trim();
      return ShopProfile(
        shopName: shopName,
        phone: (decoded['phone'] as String?)?.trim() ?? '',
        email: (decoded['email'] as String?)?.trim() ?? '',
        address: (decoded['address'] as String?)?.trim() ?? '',
        footerNote: (footer == null || footer.isEmpty) ? null : footer,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is ShopProfile &&
        other.shopName == shopName &&
        other.phone == phone &&
        other.email == email &&
        other.address == address &&
        other.footerNote == footerNote;
  }

  @override
  int get hashCode => Object.hash(shopName, phone, email, address, footerNote);
}
