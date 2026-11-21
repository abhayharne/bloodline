import 'package:flutter/material.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';

/// Debug screen for the P0 spike:
/// – Paste a Nexconn user token (test1 or test2)
/// – Connect to the cluster
/// – Open the ChannelPage (conversation list)
/// – Or jump directly into the spike channel blspike1795251938
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _tokenController = TextEditingController();
  String _status = 'Disconnected';
  bool _connected = false;
  bool _connecting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _setStatus('Paste a user token first');
      return;
    }

    setState(() {
      _connecting = true;
      _status = 'Connecting…';
    });

    try {
      await NCEngine.connect(
        ConnectParams(token: token),
        (String? userId, NCError? error) {
          if (!mounted) return;
          if (error?.isSuccess == true) {
            setState(() {
              _connected = true;
              _connecting = false;
              _status = 'Connected as: $userId';
            });
          } else {
            setState(() {
              _connecting = false;
              _status = 'Failed: code=${error?.code}, msg=${error?.message}';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _status = 'Error: $e';
        });
      }
    }
  }

  void _setStatus(String s) => setState(() => _status = s);

  void _openChannelList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Channels')),
          body: ChannelPage(
            onItemTap: (channel, index, ctx) {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ChatPage(channel: channel),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openSpikeChannel() {
    // Open the channel created by the backend spike directly
    final channel = BaseChannel(ChannelType.group, 'blspike1795251938');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BloodLine Debug'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _connected
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _connected ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _connected
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Token input
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Nexconn user token',
                hintText: 'Paste test1 or test2 token here',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              maxLines: 2,
              enabled: !_connected,
            ),

            const SizedBox(height: 16),

            // Connect button
            if (!_connected)
              FilledButton.icon(
                onPressed: _connecting ? null : _connect,
                icon: _connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.power),
                label: Text(_connecting ? 'Connecting…' : 'Connect'),
              ),

            if (_connected) ...[
              const SizedBox(height: 8),

              // Channel list button
              FilledButton.icon(
                onPressed: _openChannelList,
                icon: const Icon(Icons.list),
                label: const Text('Open Channel List'),
              ),

              const SizedBox(height: 12),

              // Spike channel shortcut
              OutlinedButton.icon(
                onPressed: _openSpikeChannel,
                icon: const Icon(Icons.science),
                label: const Text('Open Spike Room (blspike1795251938)'),
              ),

              const SizedBox(height: 24),

              // Disconnect
              TextButton.icon(
                onPressed: () async {
                  await NCEngine.disconnect();
                  if (mounted) {
                    setState(() {
                      _connected = false;
                      _status = 'Disconnected';
                      _tokenController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
