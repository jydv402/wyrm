import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/core/core.dart';
import 'package:wyrm_desk/home/home.dart';

void main() {
  runApp(const ProviderScope(child: WyrmDeskApp()));
}

class WyrmDeskApp extends StatelessWidget {
  const WyrmDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wyrm Desk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
