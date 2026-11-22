import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/requests_provider.dart';
import 'providers/notifications_provider.dart';
import '../features/auth/login_screen.dart';

/// Shows a confirm dialog and, if confirmed:
/// - clears stored token and user
/// - disconnects Nexconn
/// - resets providers (RequestsProvider, NotificationsProvider)
/// - returns to LoginScreen
Future<void> confirmAndLogout(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Logout'),
      content: const Text(
        'Are you sure you want to log out? This will disconnect chat and return to the login screen.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    await context.read<AuthProvider>().logout();
    try {
      context.read<RequestsProvider>().reset();
    } catch (_) {}
    try {
      context.read<NotificationsProvider>().reset();
    } catch (_) {}
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
