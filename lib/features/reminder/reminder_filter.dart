/// View filter applied to the reminders list in dashboard and editor surfaces.
enum ReminderFilter {
  /// Show all reminders regardless of status or recurrence.
  all('All'),

  /// Show only enabled reminders.
  active('Active'),

  /// Show only repeating reminders (`daily`, `weekdays`, `custom`).
  recurring('Recurring');

  const ReminderFilter(this.label);

  /// Human-readable display label for filter pills.
  final String label;
}
