import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/features/home/homepage.dart';
import 'package:wyrm_desk/server/server_provider.dart';

void main() {
  runApp(const ProviderScope(child: WyrmDeskApp()));
}

class WyrmDeskApp extends ConsumerWidget {
  const WyrmDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly boot the embedded background web remote server.
    ref.watch(webServerProvider);

    return MaterialApp(
      title: 'Wyrm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
