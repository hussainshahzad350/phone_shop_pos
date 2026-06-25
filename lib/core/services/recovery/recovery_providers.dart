import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/config/supabase_config.dart';
import 'package:phone_shop_pos/core/services/recovery/email_recovery_service.dart';
import 'package:phone_shop_pos/core/services/recovery/otp_client.dart';
import 'package:phone_shop_pos/core/services/recovery/supabase_otp_client.dart';
import 'package:phone_shop_pos/modules/auth/presentation/providers/local_pin_auth_providers.dart';

final otpClientProvider = Provider<OtpClient>((ref) {
  return SupabaseOtpClient(
    baseUrl: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
});

final emailRecoveryServiceProvider = Provider<EmailRecoveryService>((ref) {
  return EmailRecoveryService(
    otpClient: ref.watch(otpClientProvider),
    authService: ref.watch(localPinAuthServiceProvider),
  );
});
