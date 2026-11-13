import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wyrm_desk/theme/theme.dart';
import 'package:wyrm_desk/widgets/dusk_glass_button.dart';
import 'package:wyrm_desk/widgets/dusk_glass_panel.dart';
import 'package:wyrm_desk/widgets/dusk_glass_pill.dart';
import 'package:wyrm_desk/widgets/dusk_glass_segmented_control.dart';
import 'package:wyrm_desk/data/app_database.dart';
import 'package:wyrm_desk/data/database_service.dart';
import 'package:wyrm_desk/server/server_provider.dart';
import 'package:wyrm_desk/server/web_server.dart';
import 'package:wyrm_desk/features/display/display_state.dart';
import 'package:wyrm_desk/config/card_layout_state.dart';
import 'package:wyrm_desk/features/network/network_info.dart';
import 'package:wyrm_desk/features/network/network_modal.dart';
import 'package:wyrm_desk/config/app_settings_state.dart';

/// Fullscreen Dusk Glass settings page for Wyrm Desk.
///
/// Clean, unified fullscreen view presenting all application preferences,
/// display controls, time/calendar conventions, and web companion status
/// with responsive layout and atmospheric ambient backdrops.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Opens the settings page as a fullscreen modal route.
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final displayState = ref.watch(displayProvider);
    final layoutConfig = ref.watch(cardLayoutProvider);
    final isNightstand = layoutConfig.clock == CardSize.nightstand;

    final ipAsync = ref.watch(localIpProvider);
    final ipAddress = ipAsync.value ?? '127.0.0.1';
    final server = ref.watch(webServerProvider);
    final serverPort = server.port ?? ShelfWebServer.defaultPort;
    final serverUrl = 'http://$ipAddress:$serverPort';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient Dusk Glow Backdrop
          const Positioned.fill(
            child: IgnorePointer(child: _SettingsAmbientBackdrop()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation Bar
                  _buildTopBar(context),

                  const SizedBox(height: 16),

                  // Main Content: Centered responsive scrollable column
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: _buildContentPane(
                          context: context,
                          ref: ref,
                          settings: settings,
                          notifier: notifier,
                          displayState: displayState,
                          isNightstand: isNightstand,
                          ipAddress: ipAddress,
                          serverUrl: serverUrl,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top navigation bar with back button, branded title, and close action.
  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        DuskGlassButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          size: 40.0,
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 14),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.glacierAccent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.glacierAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: AppColors.glacierAccent,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Ambient display, clock preferences, and companion server',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DuskGlassButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          size: 40.0,
          icon: const Icon(
            Icons.close_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Scrollable content pane containing grouped Dusk Glass panels for each category.
  Widget _buildContentPane({
    required BuildContext context,
    required WidgetRef ref,
    required AppSettingsConfig settings,
    required AppSettingsNotifier notifier,
    required DisplayState displayState,
    required bool isNightstand,
    required String ipAddress,
    required String serverUrl,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Display & Brightness
          _buildDisplaySection(
            ref: ref,
            displayState: displayState,
            isNightstand: isNightstand,
          ),

          const SizedBox(height: 16),

          // Section 2: Clock & Calendar
          _buildClockCalendarSection(settings: settings, notifier: notifier),

          const SizedBox(height: 16),

          // Section 3: Card Appearance
          _buildAppearanceSection(settings: settings, notifier: notifier),

          const SizedBox(height: 16),

          // Section 4: Web Remote Companion
          _buildNetworkSection(
            context: context,
            ref: ref,
            ipAddress: ipAddress,
            serverUrl: serverUrl,
          ),

          const SizedBox(height: 16),

          // Section 5: Data & Backups
          _buildDataBackupSection(
            context: context,
            ref: ref,
            serverUrl: serverUrl,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Section 1: Display & Brightness panel
  Widget _buildDisplaySection({
    required WidgetRef ref,
    required DisplayState displayState,
    required bool isNightstand,
  }) {
    final pct = (displayState.brightness * 100).round();

    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            icon: Icons.brightness_6_rounded,
            title: 'Display & Brightness',
            subtitle: 'Screen intensity and ambient nightstand behavior',
          ),
          const SizedBox(height: 18),

          // Brightness Slider Row
          _buildSettingRow(
            icon: Icons.brightness_medium_rounded,
            title: 'Brightness',
            subtitle: 'Screen intensity of the tablet ambient display',
            trailing: SizedBox(
              width: 240,
              child: Row(
                children: [
                  const Icon(
                    Icons.brightness_5_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        activeTrackColor: AppColors.glacierAccent,
                        inactiveTrackColor: AppColors.lineStrong,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: displayState.brightness.clamp(0.05, 1.0),
                        min: 0.05,
                        max: 1.0,
                        onChanged: (val) {
                          ref.read(displayProvider.notifier).setBrightness(val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.well,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line, width: 1.0),
                    ),
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nightstand Mode Toggle
          _buildSettingRow(
            icon: Icons.bedtime_rounded,
            title: 'Nightstand Mode',
            subtitle: 'Pitch-black ultra-low glare glowing clock for bedtime',
            trailing: Switch.adaptive(
              value: isNightstand,
              activeThumbColor: const Color(0xFFFF9500),
              activeTrackColor: const Color(0xFFFF9500).withValues(alpha: 0.35),
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.well,
              onChanged: (val) {
                ref
                    .read(cardLayoutProvider.notifier)
                    .setCardSize(
                      DashboardCardType.clock,
                      val ? CardSize.nightstand : CardSize.small,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Section 2: Clock & Calendar panel
  Widget _buildClockCalendarSection({
    required AppSettingsConfig settings,
    required AppSettingsNotifier notifier,
  }) {
    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            icon: Icons.schedule_rounded,
            title: 'Clock & Calendar',
            subtitle: 'Time format and calendar week start conventions',
          ),
          const SizedBox(height: 18),

          // 24-Hour Time Format
          _buildSettingRow(
            icon: Icons.access_time_filled_rounded,
            title: 'Time Format',
            subtitle:
                'Choose between 12-hour AM/PM and 24-hour military format',
            trailing: SizedBox(
              width: 220,
              child: DuskGlassSegmentedControl<bool>(
                values: const [false, true],
                selectedValue: settings.is24HourFormat,
                labelBuilder: (v) => v ? '24-hour' : '12-hour',
                onValueChanged: (v) => notifier.set24HourFormat(v),
                activeColor: AppColors.glacierAccent,
                activeTextColor: AppColors.glacierInk,
                height: 38,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Week Starts On
          _buildSettingRow(
            icon: Icons.calendar_view_week_rounded,
            title: 'Week Starts On',
            subtitle: 'First day of the week in calendar and habit cards',
            trailing: SizedBox(
              width: 220,
              child: DuskGlassSegmentedControl<bool>(
                values: const [false, true],
                selectedValue: settings.startWeekOnMonday,
                labelBuilder: (v) => v ? 'Monday' : 'Sunday',
                onValueChanged: (v) => notifier.setStartWeekOnMonday(v),
                activeColor: AppColors.glacierAccent,
                activeTextColor: AppColors.glacierInk,
                height: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 3: Card Appearance panel
  Widget _buildAppearanceSection({
    required AppSettingsConfig settings,
    required AppSettingsNotifier notifier,
  }) {
    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            icon: Icons.palette_rounded,
            title: 'Card Appearance',
            subtitle: 'Typography scale for tasks, habits, and cards',
          ),
          const SizedBox(height: 18),

          // Card Font Size Slider
          _buildSettingRow(
            icon: Icons.format_size_rounded,
            title: 'Card Font Size',
            subtitle:
                'Scale checklist item and habit typography (${settings.cardFontSize.toInt()} pt)',
            trailing: SizedBox(
              width: 240,
              child: Row(
                children: [
                  const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        activeTrackColor: AppColors.glacierAccent,
                        inactiveTrackColor: AppColors.lineStrong,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        value: settings.cardFontSize.clamp(11.0, 22.0),
                        min: 11.0,
                        max: 22.0,
                        divisions: 11,
                        onChanged: (val) => notifier.setCardFontSize(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.well,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line, width: 1.0),
                    ),
                    child: Text(
                      '${settings.cardFontSize.toInt()} pt',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Live Font Size Preview Tile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.rust.fill.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.rustAccent, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.rustAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Live Preview: ${settings.cardFontSize.toInt()} pt',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: settings.cardFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                DuskGlassPill.priority('HIGH'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 4: Web Remote Companion panel
  Widget _buildNetworkSection({
    required BuildContext context,
    required WidgetRef ref,
    required String ipAddress,
    required String serverUrl,
  }) {
    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            icon: Icons.wifi_rounded,
            title: 'Web Remote Companion',
            subtitle: 'Control and sync Wyrm Desk wirelessly from any browser',
          ),
          const SizedBox(height: 18),

          // Server Status and QR Action Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.glacierAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glacierAccent,
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Server Running',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    DuskGlassButton(
                      onPressed: () =>
                          NetworkConnectionModal.show(context, ref),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Show QR',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: AppColors.glacierAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serverUrl,
                          style: const TextStyle(
                            color: AppColors.glacierAccent,
                            fontSize: 13.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 5: Data & Backups panel
  Widget _buildDataBackupSection({
    required BuildContext context,
    required WidgetRef ref,
    required String serverUrl,
  }) {
    return DuskGlassPanel(
      tone: AppColors.glacier,
      borderRadius: 26.0,
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            icon: Icons.storage_rounded,
            title: 'Data & Backups',
            subtitle: 'Backup or restore dashboard data between release and test versions',
          ),
          const SizedBox(height: 18),

          // Export Backup Row
          _buildSettingRow(
            icon: Icons.upload_file_rounded,
            title: 'Export to Downloads',
            subtitle:
                'Saves ${AppDatabase.backupFileName} to device Downloads folder',
            trailing: DuskGlassButton(
              onPressed: () async {
                final path = await AppDatabase.exportToDownloads();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        path != null
                            ? 'Database exported to $path'
                            : 'Failed to export backup.',
                      ),
                      backgroundColor: path != null
                          ? AppColors.surfaceElevated
                          : AppColors.accentRed,
                    ),
                  );
                }
              },
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              label: const Text(
                'Export',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Import Backup Row
          _buildSettingRow(
            icon: Icons.download_rounded,
            title: 'Import from Downloads',
            subtitle:
                'Restores ${AppDatabase.backupFileName} and updates all cards',
            trailing: DuskGlassButton(
              onPressed: () async {
                final modified = await AppDatabase.getDownloadsBackupModified();
                if (!context.mounted) return;

                if (modified == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No ${AppDatabase.backupFileName} found in Downloads.',
                      ),
                      backgroundColor: AppColors.accentRed,
                    ),
                  );
                  return;
                }

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surfaceElevated,
                    title: const Text(
                      'Restore Database?',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    content: Text(
                      'This will replace your current tasks, habits, calendar, and settings with the backup from Downloads (${modified.toLocal().toString().split('.').first}). Continue?',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Restore',
                          style: TextStyle(color: AppColors.glacierAccent),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  final success = await ref
                      .read(databaseServiceProvider)
                      .importFromDownloadsAndReload();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Database successfully restored from Downloads!'
                              : 'Failed to restore database.',
                        ),
                        backgroundColor: success
                            ? AppColors.surfaceElevated
                            : AppColors.accentRed,
                      ),
                    );
                  }
                }
              },
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              label: const Text(
                'Import',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Tip banner on Web Remote backup transfer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.well,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.0),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_rounded,
                  size: 16,
                  color: AppColors.glacierAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: You can also download or upload backups wirelessly from any computer or phone browser at $serverUrl',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.glacierAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.glacierAccent.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: AppColors.glacierAccent, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.well,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 460;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.glacierAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            );
          }

          return Row(
            children: [
              Icon(icon, size: 20, color: AppColors.glacierAccent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          );
        },
      ),
    );
  }
}

/// Ambient glow background matching Wyrm Desk canvas.
class _SettingsAmbientBackdrop extends StatelessWidget {
  const _SettingsAmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SettingsBackdropPainter());
  }
}

class _SettingsBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Void base
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    // Glow 1: Top-Left Slate / Amber glow
    final glow1Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.9),
        radius: 0.95,
        colors: [
          AppColors.glacier.accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow1Paint);

    // Glow 2: Bottom-Right Rust / Ember glow
    final glow2Paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, 0.95),
        radius: 0.85,
        colors: [
          AppColors.rust.accent.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glow2Paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
