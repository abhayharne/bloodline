import 'package:flutter/widgets.dart';
import 'models/blood_request.dart';

typedef RoomHeaderBadgeBuilder = Widget Function(
    BuildContext context, BloodRequest request);

/// Registry allowing decoupled features or plugins to contribute UI widgets into
/// core slots:
/// - [homeCards]: Rendered on the Home/Dashboard screen
/// - [profileSections]: Rendered on the Profile screen
/// - [roomHeaderBadges]: Rendered inside the BloodRequest chat room header
///
/// In the core build, this registry is empty by default.
class SlotRegistry {
  SlotRegistry._();
  static final SlotRegistry instance = SlotRegistry._();

  final List<WidgetBuilder> _homeCards = [];
  final List<WidgetBuilder> _profileSections = [];
  final List<RoomHeaderBadgeBuilder> _roomHeaderBadges = [];

  List<WidgetBuilder> get homeCards => List.unmodifiable(_homeCards);
  List<WidgetBuilder> get profileSections => List.unmodifiable(_profileSections);
  List<RoomHeaderBadgeBuilder> get roomHeaderBadges =>
      List.unmodifiable(_roomHeaderBadges);

  void registerHomeCard(WidgetBuilder builder) {
    _homeCards.add(builder);
  }

  void registerProfileSection(WidgetBuilder builder) {
    _profileSections.add(builder);
  }

  void registerRoomHeaderBadge(RoomHeaderBadgeBuilder builder) {
    _roomHeaderBadges.add(builder);
  }

  void clear() {
    _homeCards.clear();
    _profileSections.clear();
    _roomHeaderBadges.clear();
  }
}
