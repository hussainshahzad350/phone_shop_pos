import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current top-level route path, kept in sync by the navigation shell.
///
/// Screens that stay alive inside the indexed-stack shell (Sales, Purchases)
/// listen to this so they can clear transient input (e.g. typed payment
/// amounts) when the user navigates away from them.
final currentRoutePathProvider = StateProvider<String>((ref) => '/');
