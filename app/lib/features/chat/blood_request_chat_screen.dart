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
  final VoidCallback? onDonated;
  final bool isDonating;
  final bool hasDonated;

  const RequestSummaryHeader({
    super.key,
    required this.request,
    this.onFulfill,
    this.isFulfilling = false,
    this.onDonated,
    this.isDonating = false,
    this.hasDonated = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isRequester = auth.currentUser?.role == 'requester' ||
        auth.currentUser?.name == request.requesterName;
    final isDonor = auth.currentUser?.role == 'donor';
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
              color: Colors.grey.shade900,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Request Fulfilled — This room is closed (read-only)',
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
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: isFulfilling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 16),
                    label: const Text(
                      'Mark fulfilled',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isFulfilling ? null : onFulfill,
                  ),
                ],
                // Donor I donated button or Donated badge
                if (isDonor) ...[
                  const SizedBox(width: 8),
                  if (hasDonated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volunteer_activism, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Donated',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: isDonating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.volunteer_activism, size: 16),
                      label: const Text(
                        'I donated',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isDonating ? null : onDonated,
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
  bool _isDonating = false;

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

  Future<void> _confirmAndRecordDonation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Donation'),
        content: Text(
          'Did you donate blood for this request at ${_currentRequest.hospital}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.volunteer_activism),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Yes, I donated'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDonating = true);
    final requestsProvider = context.read<RequestsProvider>();
    final res = await requestsProvider.recordDonation(_currentRequest.id);
    setState(() => _isDonating = false);

    if (!mounted) return;
    if (res != null) {
      final count = res['donation_count'] ?? 1;
      try {
        if (count is num) {
          context.read<AuthProvider>().updateDonationCount(count.toInt());
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you! Your donation was recorded. You just helped up to 3 people. (Total: $count)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to record donation. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
    final auth = context.watch<AuthProvider>();
    final requestsProvider = context.watch<RequestsProvider>();
    final isRequester = auth.currentUser?.role == 'requester' ||
        auth.currentUser?.name == _currentRequest.requesterName;
    final isDonor = auth.currentUser?.role == 'donor';
    final hasDonated = requestsProvider.isDonated(_currentRequest.id);
    final isClosed = _currentRequest.isFulfilled || _currentRequest.isCancelled;
    final channel = BaseChannel(ChannelType.group, _currentRequest.channelId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRequest.hospital),
        actions: [
          if (isRequester && _currentRequest.isOpen)
            TextButton.icon(
              onPressed: _isFulfilling ? null : _confirmAndFulfill,
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              label: const Text('Mark fulfilled', style: TextStyle(color: Colors.green)),
            ),
          if (isDonor && !hasDonated && _currentRequest.isOpen)
            TextButton.icon(
              onPressed: _isDonating ? null : _confirmAndRecordDonation,
              icon: const Icon(Icons.volunteer_activism, color: Colors.red),
              label: const Text('I donated', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: Column(
        children: [
          RequestSummaryHeader(
            request: _currentRequest,
            onFulfill: _confirmAndFulfill,
            isFulfilling: _isFulfilling,
            onDonated: _confirmAndRecordDonation,
            isDonating: _isDonating,
            hasDonated: hasDonated,
          ),
          if (isClosed)
            Container(
              key: const ValueKey('closed_room_readonly_banner'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.amber.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Text(
                    'This request is fulfilled. Room is closed and read-only.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Builder(
              builder: (ctx) {
                bool hasEngine = false;
                try {
                  hasEngine = NCEngine.isInitialized &&
                      Provider.of<EngineProvider?>(ctx, listen: false) != null;
                } catch (_) {
                  hasEngine = false;
                }

                if (!hasEngine) {
                  return Center(
                    child: Text('Chat messages for ${channel.channelId}'),
                  );
                }

                return IgnorePointer(
                  ignoring: isClosed,
                  child: ChatPage(
                    channel: channel,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
