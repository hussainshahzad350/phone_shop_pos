import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';

import 'core/notifications/app_notifier.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.empty);
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: PhoneShopPosApp())),
    (error, stackTrace) {
      debugPrint('Unhandled startup/runtime error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

class PhoneShopPosApp extends ConsumerWidget {
  const PhoneShopPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appDatabaseProvider);
    final router = ref.watch(appRouterProvider);

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
            Text('Starting Phone Shop POS...'),
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
