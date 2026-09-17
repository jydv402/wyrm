import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/home.dart';
import 'package:wyrm_desk/server/server.dart';

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
      title: 'Wyrm Desk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
