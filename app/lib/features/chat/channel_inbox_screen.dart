import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import '../../core/models/blood_request.dart';
import '../../core/providers/requests_provider.dart';
import 'blood_request_chat_screen.dart';

class ChannelInboxScreen extends StatelessWidget {
  const ChannelInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!NCEngine.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Chat Rooms'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Chat offline — Connect to chat server in Debug Settings'),
        ),
      );
    }

    final requestsProvider = context.watch<RequestsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Chat Rooms'),
        centerTitle: true,
      ),
      body: ChannelPage(
        onItemTap: (channel, index, ctx) {
          // Find matching BloodRequest by channelId if available
          final channelId = channel.channelId;
          final match = requestsProvider.requests.firstWhere(
            (r) => r.channelId == channelId || 'req${r.id}' == channelId,
            orElse: () => BloodRequest(
              id: channelId.replaceFirst('req', ''),
              bloodGroup: 'Blood Request',
              units: 1,
              hospital: 'Chat Room ($channelId)',
              urgency: 'high',
              status: 'open',
              channelId: channelId,
            ),
          );

          Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => BloodRequestChatScreen(request: match),
            ),
          );
        },
      ),
    );
  }
}
