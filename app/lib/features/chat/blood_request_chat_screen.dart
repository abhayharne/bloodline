import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import '../../core/models/blood_request.dart';
import '../../core/slot_registry.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/requests_provider.dart';

Color getUrgencyColor(String urgency) {
  switch (urgency.toLowerCase()) {
    case 'critical':
      return Colors.red.shade700;
    case 'high':
      return Colors.deepOrange;
    case 'medium':
      return Colors.amber.shade800;
    case 'low':
    default:
      return Colors.blueGrey;
  }
}

/// RequestSummaryHeader presents the blood request's metadata, urgency,
/// hospital, closed room banner, fulfill button, and extension badges.
class RequestSummaryHeader extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onFulfill;
  final bool isFulfilling;

  const RequestSummaryHeader({
    super.key,
    required this.request,
    this.onFulfill,
    this.isFulfilling = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isRequester = auth.currentUser?.role == 'requester' ||
        auth.currentUser?.name == request.requesterName;
    final isClosed = request.isFulfilled || request.isCancelled;
    final badges = SlotRegistry.instance.roomHeaderBadges;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Closed Room Banner
          if (isClosed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.grey.shade800,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Request Fulfilled — This room is closed',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Details summary row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Blood group pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.bloodGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Hospital & units
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.hospital,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${request.units} unit${request.units > 1 ? 's' : ''} needed  •  ${request.requesterName ?? 'Requester'}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Urgency chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getUrgencyColor(request.urgency).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: getUrgencyColor(request.urgency)),
                  ),
                  child: Text(
                    request.urgency.toUpperCase(),
                    style: TextStyle(
                      color: getUrgencyColor(request.urgency),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Fulfill action button for requester
                if (isRequester && !isClosed) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: isFulfilling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 20),
                    tooltip: 'Mark Fulfilled',
                    onPressed: isFulfilling ? null : onFulfill,
                  ),
                ],
              ],
            ),
          ),

          // SlotRegistry roomHeaderBadges (empty by default in core build)
          if (badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Wrap(
                spacing: 8,
                children: badges.map((b) => b(context, request)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class BloodRequestChatScreen extends StatefulWidget {
  final BloodRequest request;

  const BloodRequestChatScreen({
    super.key,
    required this.request,
  });

  @override
  State<BloodRequestChatScreen> createState() => _BloodRequestChatScreenState();
}

class _BloodRequestChatScreenState extends State<BloodRequestChatScreen> {
  late BloodRequest _currentRequest;
  bool _isFulfilling = false;

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
  }

  @override
  void didUpdateWidget(covariant BloodRequestChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request != oldWidget.request) {
      _currentRequest = widget.request;
    }
  }

  Future<void> _confirmAndFulfill() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Request Fulfilled?'),
        content: const Text(
          'This will notify all members in the chat room and mark the request as fulfilled and closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Mark Fulfilled'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isFulfilling = true);
    final requestsProvider = context.read<RequestsProvider>();
    final success = await requestsProvider.fulfillRequest(_currentRequest.id);
    setState(() => _isFulfilling = false);

    if (!mounted) return;
    if (success) {
      setState(() {
        _currentRequest = _currentRequest.copyWith(status: 'fulfilled');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request marked as fulfilled. Room is now closed.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark fulfilled. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = BaseChannel(ChannelType.group, _currentRequest.channelId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRequest.hospital),
        actions: [
          if (_currentRequest.isOpen)
            TextButton.icon(
              onPressed: _confirmAndFulfill,
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              label: const Text('Fulfill', style: TextStyle(color: Colors.green)),
            ),
        ],
      ),
      body: Column(
        children: [
          RequestSummaryHeader(
            request: _currentRequest,
            onFulfill: _confirmAndFulfill,
            isFulfilling: _isFulfilling,
          ),
          Expanded(
            child: ChatPage(
              channel: channel,
            ),
          ),
        ],
      ),
    );
  }
}
