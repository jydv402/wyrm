import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';
import 'package:wyrm_desk/routing/app_router.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: WyrmDeskApp()));
}

class WyrmDeskApp extends ConsumerWidget {
  const WyrmDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly boot the embedded background web remote server.
    ref.watch(webServerProvider);

    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'Wyrm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: settings.minTextScaleFactor,
              maxScaleFactor: settings.maxTextScaleFactor,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
