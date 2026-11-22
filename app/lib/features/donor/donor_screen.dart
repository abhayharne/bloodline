import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/blood_request.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/requests_provider.dart';
import '../chat/blood_request_chat_screen.dart';

class DonorScreen extends StatefulWidget {
  const DonorScreen({super.key});

  @override
  State<DonorScreen> createState() => _DonorScreenState();
}

class _DonorScreenState extends State<DonorScreen> {
  String? _acceptingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestsProvider>().loadRequests(status: 'open');
    });
  }

  Future<void> _confirmAndRecordDonation(BloodRequest req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Donation'),
        content: Text(
          'Did you donate blood for this request at ${req.hospital}?',
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

    final requestsProvider = context.read<RequestsProvider>();
    final res = await requestsProvider.recordDonation(req.id);

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

  Future<void> _acceptAndOpen(BloodRequest request) async {
    setState(() => _acceptingId = request.id);
    final requestsProvider = context.read<RequestsProvider>();
    final channelId = await requestsProvider.acceptRequest(request.id);
    setState(() => _acceptingId = null);

    if (!mounted) return;
    if (channelId != null) {
      final joinedReq = request.copyWith(channelId: channelId, joined: true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BloodRequestChatScreen(request: joinedReq),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join request room')),
      );
    }
  }

  Color _getUrgencyBadgeColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'urgent':
        return Colors.deepOrange;
      case 'planned':
        return Colors.blueGrey;
      default:
        return Colors.amber.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final requestsProvider = context.watch<RequestsProvider>();
    final user = auth.currentUser;
    final requests = requestsProvider.requests;

    return RefreshIndicator(
      onRefresh: () => requestsProvider.loadRequests(status: 'open'),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Donor Status Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      user?.bloodGroup ?? 'O+',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to donate, ${user?.name ?? 'Hero'}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Matching requests near ${user?.areaName ?? 'Nagpur'}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emergency Requests Feed',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => requestsProvider.loadRequests(status: 'open'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (requestsProvider.isLoading && requests.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (requests.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No open emergency requests in your area right now.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'We will notify you immediately when someone matches your group.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final isAccepting = _acceptingId == req.id;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  req.bloodGroup,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.hospital,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${req.units} unit${req.units > 1 ? 's' : ''} needed  •  ${req.distanceKm != null ? '${req.distanceKm!.toStringAsFixed(1)} km away' : 'Nearby'}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getUrgencyBadgeColor(req.urgency).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _getUrgencyBadgeColor(req.urgency)),
                                ),
                                child: Text(
                                  req.urgency.toUpperCase(),
                                  style: TextStyle(
                                    color: _getUrgencyBadgeColor(req.urgency),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Action button
                          if (req.joined)
                            Builder(
                              builder: (ctx) {
                                final hasDonated = requestsProvider.isDonated(req.id);
                                return Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BloodRequestChatScreen(request: req),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.chat),
                                        label: const Text('Joined — Open Room'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (hasDonated)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.shade400),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Donated',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                        onPressed: () => _confirmAndRecordDonation(req),
                                        icon: const Icon(Icons.volunteer_activism, size: 16),
                                        label: const Text('I donated'),
                                      ),
                                  ],
                                );
                              },
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: isAccepting ? null : () => _acceptAndOpen(req),
                              icon: isAccepting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Icon(Icons.favorite),
                              label: Text(
                                isAccepting ? 'Joining Room…' : 'I Can Help (Accept & Join Room)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
