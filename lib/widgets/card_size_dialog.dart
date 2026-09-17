import 'package:flutter/material.dart';
import 'package:wyrm_desk/core/theme.dart';
import 'card_layout_state.dart';

/// Modal dialog allowing the user to select container dimensions for a dashboard card.
class CardSizeDialog extends StatelessWidget {
  /// The type of card being configured.
  final DashboardCardType cardType;

  /// Current sizing state of the clock card.
  final ClockCardSize currentClockSize;

  /// Whether the card is currently presented in full-screen mode.
  final bool isFullScreen;

  /// Callback fired when the clock card size changes.
  final ValueChanged<ClockCardSize>? onClockSizeSelected;

  /// Callback fired when a standard card toggles full-screen mode.
  final ValueChanged<bool>? onFullScreenToggled;

  const CardSizeDialog({
    super.key,
    required this.cardType,
    required this.currentClockSize,
    required this.isFullScreen,
    this.onClockSizeSelected,
    this.onFullScreenToggled,
  });

  /// Displays the modal dialog centered on the screen.
  static Future<void> show({
    required BuildContext context,
    required DashboardCardType cardType,
    required ClockCardSize currentClockSize,
    required bool isFullScreen,
    ValueChanged<ClockCardSize>? onClockSizeSelected,
    ValueChanged<bool>? onFullScreenToggled,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return CardSizeDialog(
          cardType: cardType,
          currentClockSize: currentClockSize,
          isFullScreen: isFullScreen,
          onClockSizeSelected: onClockSizeSelected,
          onFullScreenToggled: onFullScreenToggled,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _getCardTitle(cardType);

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: const BorderSide(
          color: AppColors.borderDark,
          width: 1.5,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Select container display size and viewport arrangement.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              if (cardType == DashboardCardType.clock)
                _buildClockOptions(context)
              else
                _buildStandardOptions(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the three-tier sizing options available specifically to the clock card.
  Widget _buildClockOptions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _buildOptionTile(
          context: context,
          title: 'Small',
          description: 'Default compact vertical card in the horizontal deck',
          isSelected: currentClockSize == ClockCardSize.small && !isFullScreen,
          onTap: () {
            Navigator.of(context).pop();
            onClockSizeSelected?.call(ClockCardSize.small);
          },
        ),
        _buildOptionTile(
          context: context,
          title: 'Medium',
          description: 'Expands horizontally to occupy half of the screen width',
          isSelected: currentClockSize == ClockCardSize.medium && !isFullScreen,
          onTap: () {
            Navigator.of(context).pop();
            onClockSizeSelected?.call(ClockCardSize.medium);
          },
        ),
        _buildOptionTile(
          context: context,
          title: 'Full Screen',
          description: 'Fills the entire screen area below the top navigation bar',
          isSelected: isFullScreen || currentClockSize == ClockCardSize.large,
          onTap: () {
            Navigator.of(context).pop();
            onClockSizeSelected?.call(ClockCardSize.large);
          },
        ),
      ],
    );
  }

  /// Builds two-tier sizing options for standard bento cards.
  Widget _buildStandardOptions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _buildOptionTile(
          context: context,
          title: 'Small',
          description: 'Default bento grid container placement',
          isSelected: !isFullScreen,
          onTap: () {
            Navigator.of(context).pop();
            onFullScreenToggled?.call(false);
          },
        ),
        _buildOptionTile(
          context: context,
          title: 'Full Screen',
          description: 'Fills the entire screen area below the top navigation bar',
          isSelected: isFullScreen,
          onTap: () {
            Navigator.of(context).pop();
            onFullScreenToggled?.call(true);
          },
        ),
      ],
    );
  }

  /// Constructs an individual interactive selection tile with retro styling.
  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cardYellow
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.borderDark,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textOnLight
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textOnLight.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? AppColors.textOnLight
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Resolves the human-readable display title for the specified card type.
  String _getCardTitle(DashboardCardType type) {
    switch (type) {
      case DashboardCardType.clock:
        return 'Clock Card Size';
      case DashboardCardType.habits:
        return 'Habits Card Size';
      case DashboardCardType.calendar:
        return 'Calendar Card Size';
      case DashboardCardType.tasks:
        return 'Tasks Card Size';
    }
  }
}
