import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

/// Maps internal errors to cashier-friendly snackbar messages.
class UserFacingErrors {
  UserFacingErrors._();

  static const String customerOverpaymentCode = 'customer_overpayment';
  static const String supplierOverpaymentCode = 'supplier_overpayment';
  static const String saleOverpaymentCode = 'sale_overpayment';

  static String customerOverpayment({required double maxReceivable}) {
    if (maxReceivable <= 0.009) {
      return 'This customer has no outstanding balance to collect.';
    }
    return 'You cannot receive more than ${FormattingHelpers.currencyPkr(maxReceivable)}. '
        'That is the full amount this customer owes.';
  }

  static String supplierOverpayment({required double maxPayable}) {
    if (maxPayable <= 0.009) {
      return 'This supplier has no outstanding balance to pay.';
    }
    return 'You cannot pay more than ${FormattingHelpers.currencyPkr(maxPayable)}. '
        'That is the full amount owed to this supplier.';
  }

  static String saleOverpayment({required double remainingBalance}) {
    if (remainingBalance <= 0.009) {
      return 'This invoice is already fully paid.';
    }
    return 'Payment is too high. Only ${FormattingHelpers.currencyPkr(remainingBalance)} '
        'is still due on this invoice.';
  }

  static String messageFor(
    Object error, {
    String? operation,
  }) {
    if (error is AppError) {
      if (error.code != 'unknown_error' &&
          error.code != 'operation_failed' &&
          error.message.trim().isNotEmpty &&
          !error.message.startsWith('Unexpected error')) {
        return error.message;
      }
      if (error.details != null) {
        final nested = messageFor(error.details!, operation: operation);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      return error.message;
    }

    if (error is StateError) {
      return _mapStateMessage(error.message);
    }

    if (error is FormatException) {
      return 'Enter a valid number or date and try again.';
    }

    if (operation != null && operation.isNotEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static String messageForAppError(AppError error, {String? operation}) {
    return messageFor(error, operation: operation);
  }

  static String _mapStateMessage(String raw) {
    final message = raw.trim();
    if (message.isEmpty) {
      return 'Something went wrong. Please try again.';
    }

    const exact = <String, String>{
      'Amount exceeds receivable outstanding balance.':
          'You cannot receive more than the customer owes. Lower the amount and try again.',
      'Amount exceeds payable outstanding balance.':
          'You cannot pay more than you owe this supplier. Lower the amount and try again.',
      'Customer has no receivable outstanding balance.':
          'This customer has no outstanding balance to collect.',
      'Supplier has no payable outstanding balance.':
          'This supplier has no outstanding balance to pay.',
      'Payment cannot exceed remaining balance.':
          'Payment is higher than the invoice balance. Enter a smaller amount.',
      'This sale is already fully paid.':
          'This invoice is already fully paid.',
      'Payment amount must be greater than zero.':
          'Enter an amount greater than zero.',
      'Amount must be greater than zero.':
          'Enter an amount greater than zero.',
      'Invalid amount.':
          'Enter a valid amount.',
      'Payment method must be cash, card, or bank.':
          'Choose cash, card, or bank transfer.',
      'Credit payment method is not allowed for settlement.':
          'Credit cannot be used to settle an account balance. Choose cash, card, or bank.',
      'Collected amount cannot exceed the final cost.':
          'Payment is higher than the repair balance due.',
      'Sale not found.':
          'Sale invoice was not found. Refresh and try again.',
      'Ledger posting service is unavailable.':
          'Account ledger is not available right now. Restart the app and try again.',
    };

    final mapped = exact[message];
    if (mapped != null) {
      return mapped;
    }

    if (message.toLowerCase().contains('exceed')) {
      return 'The amount is too high. Enter a smaller amount and try again.';
    }

    return message;
  }
}
