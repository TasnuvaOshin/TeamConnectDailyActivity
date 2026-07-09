import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_service.dart';
import 'api/session.dart';
import 'providers/auth_provider.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Third-party API bootstrap: load persisted base URL, then try to refresh
  // it from update/update.php (non-fatal when offline).
  final api = ApiService();
  await api.init();

  final store = SessionStore();
  final session = await store.load();

  runApp(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        sessionControllerProvider.overrideWith(
          (ref) => SessionController(api, store, session),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Daily Activity — ACI Motors',
      theme: buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
