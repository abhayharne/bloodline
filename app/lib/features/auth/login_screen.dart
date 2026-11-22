import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import 'profile_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91 98765 43210');
  final _nameController = TextEditingController(text: 'Ravi');
  String _selectedRole = 'donor'; // 'requester' | 'donor' | 'bank'
  bool _otpSent = false;
  bool _isDemo = true;
  final _otpController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _isDemo = res['demo'] == true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mock OTP sent! Auto-filled: 123456'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _onVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-digit OTP')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      final res = await authProvider.verifyOtp(phone: phone, otp: otp);
      if (!mounted) return;

      if (res['is_new'] == false && authProvider.isAuthenticated) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }

      // If user is new, proceed to complete profile registration
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            initialPhone: phone,
            initialName: name.isNotEmpty ? name : null,
            initialRole: _selectedRole,
            initialOtp: otp,
            isNewUser: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _quickLogin(String name, String role, String bloodGroup) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      name: name,
      role: role,
      phone: '+91 99000 11223',
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (authProvider.apiClient.mockMode) ...[
                Container(
                  key: const Key('demo_mode_banner'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade600),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demo mode (offline data)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // App logo / Title
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bloodtype,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'BloodLine',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Emergency blood-request coordination',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 36),

              // Role selection pills
              const Text(
                'I am joining as a:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'donor',
                    label: Text('Donor'),
                    icon: Icon(Icons.favorite),
                  ),
                  ButtonSegment(
                    value: 'requester',
                    label: Text('Requester'),
                    icon: Icon(Icons.emergency),
                  ),
                  ButtonSegment(
                    value: 'bank',
                    label: Text('Bank'),
                    icon: Icon(Icons.local_hospital),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (set) {
                  setState(() => _selectedRole = set.first);
                },
              ),

              const SizedBox(height: 24),

              // Name input
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name / Organization',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // Phone number input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_otpSent,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  suffixIcon: _otpSent
                      ? IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => setState(() => _otpSent = false),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              if (!_otpSent) ...[
                FilledButton.icon(
                  onPressed: authProvider.isLoading ? null : _onSendOtp,
                  icon: const Icon(Icons.sms),
                  label: const Text('Get Mock OTP'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ] else ...[
                // Mock OTP Verification field
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isDemo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'demo mode, code 123456',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Text(
                        'Enter 6-digit Mock OTP',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '123456',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: authProvider.isLoading ? null : _onVerifyOtp,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Verify & Continue'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Complete Profile Directly Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        initialPhone: _phoneController.text.trim(),
                        initialName: _nameController.text.trim(),
                        initialRole: _selectedRole,
                        isNewUser: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_ind),
                label: const Text('New User? Complete Full Profile'),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Quick demo shortcuts
              const Text(
                '⚡ One-Tap Demo Profiles:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.person, size: 16, color: Colors.red),
                    label: const Text('Asha (Donor O+)'),
                    onPressed: () => _quickLogin('Asha', 'donor', 'O+'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.emergency, size: 16, color: Colors.orange),
                    label: const Text('Ravi (Requester O-)'),
                    onPressed: () => _quickLogin('Ravi', 'requester', 'O-'),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.local_hospital, size: 16, color: Colors.blue),
                    label: const Text('City Hospital Bank'),
                    onPressed: () => _quickLogin('City Hospital Bank', 'bank', 'all'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
