import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/auth_dialogs.dart';

/// Settings & Accessibility screen providing user control over app typography
/// scaling (TextScaler) and platform accessibility integrations.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Accessibility'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _buildSectionHeader(context, 'Accessibility'),
          SwitchListTile(
            key: const Key('large_font_switch'),
            secondary: const Icon(Icons.text_fields),
            title: const Text(
              'Large Text (1.3x)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Enlarge text across BloodLine for enhanced legibility using Flutter TextScaler.',
            ),
            value: settings.isLargeFont,
            onChanged: (val) => settings.setLargeFont(val),
          ),
          const Divider(),
          // Live font scale preview card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Legibility Preview (${settings.textScaleFactor.toStringAsFixed(1)}x)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Emergency O- Blood Needed: 2 units required at City Hospital.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.isLargeFont
                          ? 'Large text mode is active.'
                          : 'Standard text scale is active.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Voice-to-Text section with platform notice
          ListTile(
            key: const Key('voice_to_text_tile'),
            leading: const Icon(Icons.mic_off_outlined, color: Colors.grey),
            title: const Text(
              'Voice to Text',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              settings.voiceToTextStatus,
              style: const TextStyle(fontSize: 13),
            ),
            trailing: Chip(
              label: const Text(
                'Setup Required',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.orange.shade100,
              visualDensity: VisualDensity.compact,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Voice-to-text requires microphone permissions and native platform speech services.',
                  ),
                ),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'About BloodLine'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0 (Hackathon Build)'),
          ),
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Nexconn Chat Infrastructure'),
            subtitle: Text('AreaCode: SG (Singapore Data Center)'),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Account'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              key: const Key('settings_logout_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => confirmAndLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
