import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => throw UnimplementedError(
          'UI screens are intentionally not implemented yet.',
        ),
      ),
    ],
  );
});
