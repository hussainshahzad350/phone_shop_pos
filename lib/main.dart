import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/routing/app_router.dart';
import 'package:phone_shop_pos/core/theme/app_theme.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        Zone.current.handleUncaughtError(
          details.exception,
          details.stack ?? StackTrace.empty,
        );
      };

      runApp(const ProviderScope(child: PhoneShopPosApp()));
    },
    (error, stackTrace) {
      debugPrint('Unhandled startup/runtime error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

class PhoneShopPosApp extends ConsumerStatefulWidget {
  const PhoneShopPosApp({super.key});

  @override
  ConsumerState<PhoneShopPosApp> createState() => _PhoneShopPosAppState();
}

class _PhoneShopPosAppState extends ConsumerState<PhoneShopPosApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final operations = ref.read(activeCriticalOperationsProvider);
    if (operations.isEmpty) {
      return AppExitResponse.exit;
    }

    final navigatorKey = ref.read(rootNavigatorKeyProvider);
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null) {
      return AppExitResponse.cancel;
    }

    final message = StringBuffer()
      ..writeln(
        'The app is still completing critical work. Closing now may interrupt the cashier workflow.',
      )
      ..writeln()
      ..writeln(
        'Any save that cannot finish should roll back safely, but the operator may need to retry printing or backup after reopening.',
      )
      ..writeln()
      ..writeln('Active operations:');
    for (final operation in operations) {
      message.writeln(
        '• ${operation.progressLabel ?? operation.label}',
      );
    }

    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AppConfirmationDialog(
        title: 'Close app during active work?',
        message: message.toString(),
        confirmLabel: 'Close App',
        cancelLabel: 'Stay Open',
      ),
    );
    return confirmed == true ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(appDatabaseProvider);

    if (startup.isLoading) {
      return MaterialApp(
        title: AppRuntimeConfig.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const _StartupLoadingScreen(),
      );
    }

    if (startup.hasError) {
      return MaterialApp(
        title: AppRuntimeConfig.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: _StartupErrorScreen(
          message: startup.error.toString(),
          onRetry: () {
            ref.invalidate(localDatabaseServiceProvider);
            ref.invalidate(appDatabaseProvider);
          },
        ),
      );
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppRuntimeConfig.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      scaffoldMessengerKey: AppNotifier.messengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Starting ${AppRuntimeConfig.appName}...'),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Startup recovery needed',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The app could not open required local resources. '
                    'Check database/backup folder permissions and retry.',
                  ),
                  const SizedBox(height: 10),
                  SelectableText(message, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Startup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
