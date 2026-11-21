import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/slot_registry.dart';
import '../../core/providers/auth_provider.dart';
import '../requester/requester_screen.dart';
import '../donor/donor_screen.dart';
import '../bank/bank_screen.dart';
import '../chat/channel_inbox_screen.dart';
import '../auth/profile_screen.dart';
import '../debug/debug_screen.dart';

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
    final user = auth.currentUser;
    final role = user?.role ?? 'donor';
    final homeCards = SlotRegistry.instance.homeCards;

    final dashboardBody = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

    final tabs = [
      dashboardBody,
      const ChannelInboxScreen(),
      const ProfileScreen(),
    ];

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
          // Debug screen icon
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Debug & Token Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: tabs,
      ),
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
