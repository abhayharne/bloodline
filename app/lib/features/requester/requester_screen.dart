import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/requests_provider.dart';
import '../chat/blood_request_chat_screen.dart';

class RequesterScreen extends StatefulWidget {
  const RequesterScreen({super.key});

  @override
  State<RequesterScreen> createState() => _RequesterScreenState();
}

class _RequesterScreenState extends State<RequesterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController(text: 'City Hospital, Nagpur');
  String _selectedGroup = 'O-';
  int _units = 2;
  String _urgency = 'critical';

  final List<String> _bloodGroups = [
    'O-',
    'O+',
    'A-',
    'A+',
    'B-',
    'B+',
    'AB-',
    'AB+',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestsProvider>().loadRequests(status: 'all');
    });
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final requestsProvider = context.read<RequestsProvider>();

    final user = auth.currentUser;
    final lat = user?.lat != 0.0 ? user!.lat : 21.1458;
    final lng = user?.lng != 0.0 ? user!.lng : 79.0882;

    final resp = await requestsProvider.createRequest(
      bloodGroup: _selectedGroup,
      units: _units,
      hospital: _hospitalController.text.trim(),
      urgency: _urgency,
      lat: lat,
      lng: lng,
    );

    if (!mounted) return;
    if (resp != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Emergency Request Broadcasted!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Matched ${resp.matches.banks} blood bank(s) and ${resp.matches.donors} donor(s) nearby.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Room: ${resp.request.channelId}\n${resp.request.units} units of ${resp.request.bloodGroup} at ${resp.request.hospital}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('View Requests'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BloodRequestChatScreen(request: resp.request),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Enter Room'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsProvider = context.watch<RequestsProvider>();
    final myRequests = requestsProvider.requests;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // New Request Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.emergency, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'New Blood Request',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Blood group & units selector
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGroup,
                            decoration: const InputDecoration(
                              labelText: 'Blood Group',
                              border: OutlineInputBorder(),
                            ),
                            items: _bloodGroups
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedGroup = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _units,
                            decoration: const InputDecoration(
                              labelText: 'Units',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(10, (i) => i + 1)
                                .map((u) => DropdownMenuItem(value: u, child: Text('$u unit${u > 1 ? 's' : ''}')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _units = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hospital input
                    TextFormField(
                      controller: _hospitalController,
                      decoration: const InputDecoration(
                        labelText: 'Hospital / Delivery Location',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Urgency segmented buttons
                    const Text(
                      'Urgency Level',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'low', label: Text('Low')),
                        ButtonSegment(value: 'medium', label: Text('Med')),
                        ButtonSegment(value: 'high', label: Text('High')),
                        ButtonSegment(value: 'critical', label: Text('Critical')),
                      ],
                      selected: {_urgency},
                      onSelectionChanged: (set) => setState(() => _urgency = set.first),
                    ),
                    const SizedBox(height: 18),

                    // Broadcast button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: requestsProvider.isLoading ? null : _submitRequest,
                      icon: requestsProvider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.campaign),
                      label: Text(
                        requestsProvider.isLoading ? 'Broadcasting…' : 'Broadcast Blood Request',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // My Requests List Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Active Requests',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => requestsProvider.loadRequests(status: 'all'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (myRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('No requests created yet. Broadcast above!'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myRequests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final req = myRequests[index];
                final isClosed = req.isFulfilled || req.isCancelled;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.grey : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        req.bloodGroup,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Text(
                      req.hospital,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${req.units} units  •  ${req.urgency.toUpperCase()}  •  Status: ${req.status.toUpperCase()}',
                      style: TextStyle(
                        color: req.isOpen ? Colors.green.shade800 : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BloodRequestChatScreen(request: req),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
