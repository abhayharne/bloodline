import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import '../../core/nexconn_service.dart';
import '../../core/providers/auth_provider.dart';
import '../auth/login_screen.dart';

/// Debug & Development tools screen
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _tokenController = TextEditingController();
  final _urlController = TextEditingController();
  bool _connecting = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _urlController.text = auth.apiClient.baseUrl;
    _tokenController.text = auth.nexconnToken ?? '';
    _status = NexconnService.instance.isConnected
        ? 'Connected as: ${NexconnService.instance.connectedUserId}'
        : 'Disconnected';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connectToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() => _status = 'Paste a user token first');
      return;
    }

    setState(() {
      _connecting = true;
      _status = 'Connecting…';
    });

    final ok = await NexconnService.instance.connect(token);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _status = ok
          ? 'Connected: ${NexconnService.instance.connectedUserId}'
          : 'Failed to connect';
    });
  }

  void _openSpikeChannel() {
    final channel = BaseChannel(ChannelType.group, 'blspike1795251938');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Spike Room (blspike1795251938)')),
          body: ChatPage(channel: channel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isConnected = NexconnService.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer & Debug Tools'),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log Out',
              onPressed: () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isConnected ? Colors.green : Colors.orange),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 20),

            // Backend API Base URL
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Backend Base URL',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () {
                    auth.apiClient.baseUrl = _urlController.text.trim();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Base URL updated')),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mock Mode Switch
            SwitchListTile(
              title: const Text('Force In-Memory Mock Mode'),
              subtitle: const Text('Simulate all backend API endpoints locally'),
              value: auth.apiClient.mockMode,
              onChanged: (val) {
                setState(() => auth.apiClient.mockMode = val);
              },
            ),

            const Divider(height: 32),

            // Nexconn Token Tester
            const Text(
              'Nexconn Token Connection Test',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Nexconn user token',
                hintText: 'Paste token issued by backend spike',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _connecting ? null : _connectToken,
              icon: _connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.power),
              label: Text(_connecting ? 'Connecting…' : 'Connect Token'),
            ),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openSpikeChannel,
              icon: const Icon(Icons.science),
              label: const Text('Open Spike Room (blspike1795251938)'),
            ),

            const SizedBox(height: 24),
            if (isConnected)
              TextButton.icon(
                onPressed: () async {
                  await NexconnService.instance.disconnect();
                  setState(() => _status = 'Disconnected');
                },
                icon: const Icon(Icons.power_off, color: Colors.red),
                label: const Text('Disconnect SDK', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
