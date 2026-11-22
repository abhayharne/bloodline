import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/location_controller.dart';
import '../../core/models/blood_request.dart';
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
  final _notesController = TextEditingController();
  late final LocationController _locationController;

  String _selectedGroup = 'O-';
  int _units = 2;
  String _urgency = 'critical';
  String _selectedComponent = 'Whole blood';

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

  final List<String> _components = [
    'Whole blood',
    'Red cells',
    'Platelets',
    'Plasma',
    'Other',
  ];

  List<Map<String, dynamic>> _nearbyHospitals = [];
  String? _selectedHospital;
  bool _isOtherHospital = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null && user.lat != 0.0 && user.lng != 0.0) {
      _locationController = LocationController(
        initialLat: user.lat,
        initialLng: user.lng,
        initialLabel: user.areaName,
        initialSource: LocationSource.preset,
      );
    } else {
      _locationController = LocationController();
    }
    _locationController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestsProvider>().loadRequests(status: 'all');
      _loadHospitals();
    });
  }

  Future<void> _loadHospitals() async {
    try {
      final apiClient = context.read<ApiClient>();
      final user = context.read<AuthProvider>().currentUser;
      final lat = _locationController.latitude ?? user?.lat;
      final lng = _locationController.longitude ?? user?.lng;
      final list = await apiClient.getHospitals(lat: lat, lng: lng);
      if (mounted) {
        setState(() {
          _nearbyHospitals = list;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hospital directory unavailable. You can enter a hospital manually.')),
      );
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _hospitalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    final ok = await _locationController.fetchGpsLocation();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationController.displayText),
          backgroundColor: Colors.green,
        ),
      );
      // Reload hospitals with new GPS coordinates
      _loadHospitals();
    } else if (_locationController.lastError != null) {
      final err = _locationController.lastError!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.message),
          backgroundColor: Colors.orange.shade800,
          action: err.actionLabel != null
              ? SnackBarAction(
                  label: err.actionLabel!,
                  textColor: Colors.white,
                  onPressed: () => _locationController.handleAction(),
                )
              : null,
        ),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final requestsProvider = context.read<RequestsProvider>();

    final user = auth.currentUser;
    final lat = _locationController.latitude ?? ((user != null && user.lat != 0.0) ? user.lat : 21.1458);
    final lng = _locationController.longitude ?? ((user != null && user.lng != 0.0) ? user.lng : 79.0882);

    final resp = await requestsProvider.createRequest(
      bloodGroup: _selectedGroup,
      units: _units,
      hospital: _hospitalController.text.trim(),
      urgency: _urgency,
      lat: lat,
      lng: lng,
      component: _selectedComponent,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (!mounted) return;
    if (resp != null) {
      await requestsProvider.loadRequests(status: 'all');
      if (!mounted) return;
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

  Future<void> _confirmAndFulfill(BloodRequest req) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Request Fulfilled?'),
        content: Text(
          'Mark emergency request for ${req.hospital} (${req.bloodGroup}) as fulfilled and close the room?',
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

    final requestsProvider = context.read<RequestsProvider>();
    final success = await requestsProvider.fulfillRequest(req.id);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request marked as fulfilled. Room is closed.'),
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

                    // Component dropdown
                    DropdownButtonFormField<String>(
                      key: const Key('component_dropdown'),
                      value: _selectedComponent,
                      decoration: const InputDecoration(
                        labelText: 'Blood Component',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.colorize),
                      ),
                      items: _components
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedComponent = v);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Hospital picker (searchable / selectable backed by GET /hospitals)
                    if (_nearbyHospitals.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: const Key('hospital_picker_dropdown'),
                        value: _selectedHospital,
                        decoration: const InputDecoration(
                          labelText: 'Select Hospital (nearest first)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        isExpanded: true,
                        items: [
                          ..._nearbyHospitals.map((h) {
                            final name = h['name'].toString();
                            final dist = h['distance_km'] != null ? ' (${(h['distance_km'] as num).toStringAsFixed(1)} km)' : '';
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text('$name$dist', overflow: TextOverflow.ellipsis),
                            );
                          }),
                          const DropdownMenuItem<String>(
                            value: 'Other (type a name)',
                            child: Text('Other (type a name)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedHospital = val;
                            if (val == 'Other (type a name)') {
                              _isOtherHospital = true;
                              _hospitalController.text = '';
                            } else {
                              _isOtherHospital = false;
                              _hospitalController.text = val;
                              final h = _nearbyHospitals.firstWhere((e) => e['name'] == val, orElse: () => {});
                              if (h['lat'] != null && h['lng'] != null) {
                                _locationController.setPreset(val, (h['lat'] as num).toDouble(), (h['lng'] as num).toDouble());
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Hospital input
                    TextFormField(
                      controller: _hospitalController,
                      decoration: InputDecoration(
                        labelText: 'Hospital / Delivery Location',
                        hintText: _isOtherHospital ? 'Type hospital name' : null,
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.local_hospital),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Optional notes field
                    TextFormField(
                      key: const Key('notes_field'),
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Special instructions (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    // Location Controller section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Request Location',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (_locationController.source == LocationSource.gps)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('GPS Live', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current: ${_locationController.displayText}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            key: const Key('requester_gps_button'),
                            onPressed: _fetchGpsLocation,
                            icon: _locationController.isFetching
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.my_location, size: 16),
                            label: Text(_locationController.isFetching ? 'Detecting GPS…' : 'Use Device GPS Location'),
                          ),
                        ],
                      ),
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
                        ButtonSegment(value: 'critical', label: Text('Critical')),
                        ButtonSegment(value: 'urgent', label: Text('Urgent')),
                        ButtonSegment(value: 'planned', label: Text('Planned')),
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
                  child: Column(
                    children: [
                      ListTile(
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
                        trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (req.isOpen)
                          TextButton(
                            onPressed: () => _confirmAndFulfill(req),
                            child: const Text(
                              'Mark fulfilled',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BloodRequestChatScreen(request: req),
                            ),
                          );
                        },
                      ),
                      if (req.isOpen)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                label: const Text('Open Room'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BloodRequestChatScreen(request: req),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                                icon: const Icon(Icons.check_circle, size: 16),
                                label: const Text('Mark fulfilled'),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Mark Request Fulfilled?'),
                                      content: Text('Mark request at ${req.hospital} as fulfilled and close the room?'),
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
                                  if (confirm == true && context.mounted) {
                                    await context.read<RequestsProvider>().fulfillRequest(req.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
