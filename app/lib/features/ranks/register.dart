import 'package:flutter/widgets.dart';
import '../../core/features.dart';
import '../../core/slots.dart';
import 'ranks_home_card.dart';
import 'ranks_profile_section.dart';

export 'ranks_home_card.dart';
export 'ranks_profile_section.dart';

Widget _buildRanksHomeCard(BuildContext context) => const RanksHomeCard();
Widget _buildRanksProfileSection(BuildContext context) =>
    const RanksProfileSection();

/// Feature registration entry point for Ranks.
/// Registers rank badge section in profile and a home card ("{n} donations, {rank}")
/// via SlotRegistry ONLY when features contains 'ranks'.
void registerRanksFeature({
  Features? features,
  AppConfig? config,
  SlotRegistry? registry,
}) {
  final reg = registry ?? SlotRegistry.instance;
  final enabled =
      features?.hasRanks ?? config?.hasFeature(Features.ranks) ?? false;

  if (enabled) {
    if (!reg.homeCards.contains(_buildRanksHomeCard)) {
      reg.registerHomeCard(_buildRanksHomeCard);
    }
    if (!reg.profileSections.contains(_buildRanksProfileSection)) {
      reg.registerProfileSection(_buildRanksProfileSection);
    }
  }
}

