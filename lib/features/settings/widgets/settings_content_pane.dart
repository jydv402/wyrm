import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/settings/widgets/app_updates_section.dart';
import 'package:wyrm_desk/features/settings/widgets/appearance_section.dart';
import 'package:wyrm_desk/features/settings/widgets/clock_calendar_section.dart';
import 'package:wyrm_desk/features/settings/widgets/data_backup_section.dart';
import 'package:wyrm_desk/features/settings/widgets/display_section.dart';
import 'package:wyrm_desk/features/settings/widgets/network_section.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';

/// Scrollable content pane containing grouped Dusk Glass panels for each category.
class SettingsContentPane extends ConsumerWidget {
  const SettingsContentPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutConfig = ref.watch(cardLayoutProvider);
    final isNightstand = layoutConfig.clock == CardSize.nightstand;

    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = 'http://$ipAddress:$serverPort';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisplaySection(isNightstand: isNightstand),
          const SizedBox(height: 16),
          const ClockCalendarSection(),
          const SizedBox(height: 16),
          const AppearanceSection(),
          const SizedBox(height: 16),
          const NetworkSection(),
          const SizedBox(height: 16),
          DataBackupSection(serverUrl: serverUrl),
          const SizedBox(height: 16),
          const AppUpdatesSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
