import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/data/app_database.dart';

/// Single write path and data persistence repository for dashboard card layout.
class CardLayoutRepository {
  const CardLayoutRepository();

  /// Loads card layout configuration from the database.
  Future<CardLayoutConfig> loadLayout() async {
    final raw = await AppDatabase.readSection('layout');
    return raw is Map<String, dynamic>
        ? CardLayoutConfig.fromJson(raw)
        : const CardLayoutConfig();
  }

  /// Persists the updated card layout configuration to the database.
  Future<void> saveLayout(CardLayoutConfig config) async {
    await AppDatabase.writeSection('layout', config.toJson());
  }
}

/// Provider exposing the [CardLayoutRepository].
final cardLayoutRepositoryProvider = Provider<CardLayoutRepository>((ref) {
  return const CardLayoutRepository();
});
