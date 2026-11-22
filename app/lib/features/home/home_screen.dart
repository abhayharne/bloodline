import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/slot_registry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/config_provider.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/auth_dialogs.dart';
import '../requester/requester_screen.dart';
import '../donor/donor_screen.dart';
import '../bank/bank_screen.dart';
import '../chat/channel_inbox_screen.dart';
import '../auth/profile_screen.dart';
import '../debug/debug_screen.dart';
import '../notifications/notification_banner.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  Widget _buildRoleDashboard(String role) {
    switch (role) {
      case 'requester':
        return const RequesterScreen();
      case 'bank':
        return const BankScreen();
      case 'donor':
      default:
        return const DonorScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    try {
      context.watch<ConfigProvider>();
    } catch (_) {}
    final user = auth.currentUser;
    final role = user?.role ?? 'donor';
    final homeCards = SlotRegistry.instance.homeCards;

    final dashboardBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (auth.apiClient.mockMode) ...[
            Container(
              key: const Key('demo_mode_banner_home'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Text(
                    'Demo mode (offline data)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // In-app notification banner (server-driven copy)
          const NotificationBanner(),

          // SlotRegistry homeCards (empty in core build)
          if (homeCards.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: homeCards.map((b) => b(context)).toList(),
              ),
            ),
          ],

          // Main role view
          _buildRoleDashboard(role),
        ],
      ),
    );

    Widget activeBody;
    switch (_currentTabIndex) {
      case 1:
        activeBody = const ChannelInboxScreen();
        break;
      case 2:
        activeBody = const ProfileScreen();
        break;
      case 0:
      default:
        activeBody = dashboardBody;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                user?.bloodGroup ?? (role == 'bank' ? 'BANK' : 'BLOOD'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                user?.name ?? 'BloodLine',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Notifications bell with unread badge
          Consumer<NotificationsProvider>(
            builder: (context, notifProv, _) {
              final unread = notifProv.unreadCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          // Settings & Accessibility
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Accessibility',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // Role switch quick popup menu
          PopupMenuButton<String>(
            tooltip: 'Switch Role',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (newRole) {
              if (user != null) {
                auth.updateProfile(user.copyWith(role: newRole));
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'donor', child: Text('Switch to Donor')),
              const PopupMenuItem(value: 'requester', child: Text('Switch to Requester')),
              const PopupMenuItem(value: 'bank', child: Text('Switch to Blood Bank')),
            ],
          ),
          // Debug screen icon (only in demo mode)
          if (auth.apiClient.mockMode)
            IconButton(
              key: const Key('home_debug_button'),
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Debug & Token Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugScreen()),
                );
              },
            ),
          // Logout button
          IconButton(
            key: const Key('home_logout_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => confirmAndLogout(context),
          ),
        ],
      ),
      body: activeBody,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chat Rooms',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
