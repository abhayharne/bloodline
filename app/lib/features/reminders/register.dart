import 'package:flutter/widgets.dart';
import '../../core/features.dart';
import '../../core/slots.dart';
import 'reminders_home_card.dart';

export 'reminders_home_card.dart';

Widget _buildRemindersHomeCard(BuildContext context) =>
    const RemindersHomeCard();

/// Feature registration entry point for Reminders.
/// Registers home card "You may be eligible again" from /me derived fields
/// via SlotRegistry ONLY when features contains 'reminders'.
void registerRemindersFeature({
  Features? features,
  AppConfig? config,
  SlotRegistry? registry,
}) {
  final reg = registry ?? SlotRegistry.instance;
  final enabled = features?.hasReminders ??
      config?.hasFeature(Features.reminders) ??
      false;

  if (enabled) {
    if (!reg.homeCards.contains(_buildRemindersHomeCard)) {
      reg.registerHomeCard(_buildRemindersHomeCard);
    }
  }
}
