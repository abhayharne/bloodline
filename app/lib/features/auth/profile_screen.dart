import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/slot_registry.dart';
import '../../core/location_service.dart';
import '../../core/location_controller.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/config_provider.dart';
import '../../core/auth_dialogs.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? initialPhone;
  final String? initialName;
  final String? initialRole;
  final String? initialOtp;
  final bool isNewUser;

  const ProfileScreen({
    super.key,
    this.initialPhone,
    this.initialName,
    this.initialRole,
    this.initialOtp,
    this.isNewUser = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _customAreaController;

  late String _role;
  String _bloodGroup = 'O+';
  String _sex = 'male';
  bool _donatedBefore = false;
  DateTime? _lastDonationDate;
  bool _consent = true;
  bool _canDonatePlatelets = false;

  late final LocationController _locationController;

  final List<String> _bloodGroups = [
    'O+',
    'O-',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final u = auth.currentUser;

    _role = widget.initialRole ?? u?.role ?? 'donor';
    _nameController = TextEditingController(text: widget.initialName ?? u?.name ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? u?.phone ?? '+91 98765 43210');
    _ageController = TextEditingController(text: u?.age != null ? u!.age.toString() : '26');
    _weightController = TextEditingController(text: u?.weight != null ? u!.weight.toString() : '68');
    _heightController = TextEditingController(text: u?.height != null ? u!.height.toString() : '172');
    _customAreaController = TextEditingController(text: u?.areaName ?? '');

    if (u != null) {
      _bloodGroup = u.bloodGroup ?? 'O+';
      _sex = u.sex ?? 'male';
      _donatedBefore = u.donatedBefore;
      _lastDonationDate = u.lastDonationDate;
      _consent = u.consent;
      _canDonatePlatelets = u.canDonatePlatelets;
      if (u.lat != 0.0 && u.lng != 0.0) {
        _locationController = LocationController(
          initialLat: u.lat,
          initialLng: u.lng,
          initialLabel: u.areaName,
          initialSource: LocationSource.preset,
        );
      } else {
        _locationController = LocationController();
      }
    } else {
      _locationController = LocationController();
    }
    _locationController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _customAreaController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    final success = await _locationController.fetchGpsLocation();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationController.displayText),
          backgroundColor: Colors.green,
        ),
      );
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

  void _onAreaSelected(TypedArea area) {
    _locationController.setPreset(area.name, area.lat, area.lng);
    _customAreaController.text = area.name;
  }

  Future<void> _pickLastDonationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _lastDonationDate = picked);
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'donor' && !_consent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donors must provide consent to be registered.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final name = _nameController.text.trim();
    final phone = normalizePhone(_phoneController.text.trim());
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final bloodGroup = _role == 'bank' ? null : _bloodGroup;
    final lat = _locationController.latitude ?? 0.0;
    final lng = _locationController.longitude ?? 0.0;
    final areaName = _locationController.displayText;

    bool success;
    if (widget.isNewUser || !authProvider.isAuthenticated) {
      success = await authProvider.signup(
        name: name,
        role: _role,
        bloodGroup: bloodGroup,
        lat: lat,
        lng: lng,
        phone: phone,
        age: age,
        weight: weight,
        height: height,
        sex: _sex,
        donatedBefore: _donatedBefore,
        lastDonationDate: _lastDonationDate,
        areaName: areaName,
        consent: _consent,
        otp: widget.initialOtp ?? '123456',
      );
      if (success && authProvider.currentUser != null) {
        await authProvider.updateProfile(
          authProvider.currentUser!.copyWith(canDonatePlatelets: _canDonatePlatelets),
        );
      }
    } else {
      final updated = authProvider.currentUser!.copyWith(
        name: name,
        role: _role,
        bloodGroup: bloodGroup,
        lat: lat,
        lng: lng,
        phone: phone,
        age: age,
        weight: weight,
        height: height,
        sex: _sex,
        donatedBefore: _donatedBefore,
        lastDonationDate: _lastDonationDate,
        areaName: areaName,
        consent: _consent,
        canDonatePlatelets: _canDonatePlatelets,
      );
      await authProvider.updateProfile(updated);
      success = true;
    }

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
      if (widget.isNewUser) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    try {
      context.watch<ConfigProvider>();
    } catch (_) {}
    final profileSlots = SlotRegistry.instance.profileSections;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNewUser ? 'Complete Profile' : 'Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic info section
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Basic Information',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      // Role picker
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'donor', child: Text('Donor')),
                          DropdownMenuItem(value: 'requester', child: Text('Requester')),
                          DropdownMenuItem(value: 'bank', child: Text('Blood Bank')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _role = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name / Organization *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      if (_role != 'bank') ...[
                        const SizedBox(height: 14),
                        // Blood group dropdown
                        DropdownButtonFormField<String>(
                          value: _bloodGroup,
                          decoration: const InputDecoration(
                            labelText: 'Blood Group *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.bloodtype, color: Colors.red),
                          ),
                          items: _bloodGroups.map((bg) {
                            return DropdownMenuItem(
                              value: bg,
                              child: Text(
                                bg,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _bloodGroup = val);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Health & Demographics Section (Name, Age, Weight, Height, Sex)
              if (_role != 'bank')
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Physical & Eligibility Info',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Age (yrs)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  final num = int.tryParse(v ?? '');
                                  if (num == null || num < 1 || num > 120) {
                                    return 'Valid age';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Weight (kg)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Height (cm)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Sex dropdown
                        DropdownButtonFormField<String>(
                          value: _sex,
                          decoration: const InputDecoration(
                            labelText: 'Sex',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.wc),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _sex = val);
                          },
                        ),
                        const SizedBox(height: 16),
                        // Donated before toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Donated blood before?'),
                          subtitle: Text(_donatedBefore
                              ? 'Experienced donor'
                              : 'First-time donor'),
                          value: _donatedBefore,
                          onChanged: (val) {
                            setState(() => _donatedBefore = val);
                          },
                        ),
                        // Last donation date picker
                        if (_donatedBefore) ...[
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month, color: Colors.red),
                            title: const Text('Last Donation Date'),
                            subtitle: Text(_lastDonationDate != null
                                ? '${_lastDonationDate!.day}/${_lastDonationDate!.month}/${_lastDonationDate!.year}'
                                : 'Select date (optional)'),
                            trailing: OutlinedButton(
                              onPressed: _pickLastDonationDate,
                              child: const Text('Pick Date'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Location Section: GPS with typed-area fallback
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Location Settings',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (_locationController.source == LocationSource.gps)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.gps_fixed, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'GPS Live',
                                    style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current: ${_locationController.displayText}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 14),
                      // GPS Button - ALWAYS ENABLED
                      FilledButton.tonalIcon(
                        key: const Key('use_device_gps_button'),
                        onPressed: _fetchGpsLocation,
                        icon: _locationController.isFetching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(_locationController.isFetching ? 'Detecting GPS…' : 'Use Device GPS Location'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customAreaController,
                        decoration: const InputDecoration(
                          labelText: 'Typed Area / Neighborhood (fallback)',
                          hintText: 'e.g. Sitabuldi, Civil Lines, Medical Square',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit_location_alt),
                        ),
                        onChanged: (val) {
                          _locationController.setTyped(val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Or choose a typed area preset (fallback):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kPopularAreas.take(6).map((area) {
                          final isSelected = _locationController.source == LocationSource.preset &&
                              _locationController.label == area.name;
                          return ChoiceChip(
                            label: Text(area.name.split(' (').first),
                            selected: isSelected,
                            onSelected: (_) => _onAreaSelected(area),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              if (_role == 'donor') ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('can_donate_platelets_tile'),
                          contentPadding: EdgeInsets.zero,
                          value: _canDonatePlatelets,
                          onChanged: (val) => setState(() => _canDonatePlatelets = val),
                          title: const Text(
                            'I can donate platelets/plasma',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: const Text(
                            'Available for apheresis / component donation',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const Divider(),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _consent,
                          onChanged: (val) => setState(() => _consent = val ?? false),
                          title: const Text(
                            'Donor Consent *',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: const Text(
                            'I agree to donate blood voluntarily and receive notifications',
                            style: TextStyle(fontSize: 13),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // SlotRegistry profileSections (rendered if any feature registers)
              for (final slotBuilder in profileSlots) ...[
                const SizedBox(height: 16),
                slotBuilder(context),
              ],

              const SizedBox(height: 28),

              // Submit Button
              FilledButton(
                onPressed: auth.isLoading ? null : _onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: auth.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.isNewUser ? 'Complete Registration' : 'Save Changes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              if (!widget.isNewUser) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.accessibility_new),
                  label: const Text('Settings & Accessibility'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('profile_logout_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () => confirmAndLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
