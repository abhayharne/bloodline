import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';

/// Home card for donor reminders: "You may be eligible again"
/// Powered by /me derived fields and donor eligibility rules.
///
/// Follows docs/COPY.md tone:
/// - eligible_again: "Your blood has had {days} days to recharge. Ready to be somebody's hero again?"
/// - soft_snooze: "No pressure. We'll check back next month."
/// - Never guilt-tripping, shame, or fear.
class RemindersHomeCard extends StatefulWidget {
  final bool? eligible;
  final DateTime? nextEligibleAt;
  final int? rechargeDays;
  final VoidCallback? onTap;

  const RemindersHomeCard({
    super.key,
    this.eligible,
    this.nextEligibleAt,
    this.rechargeDays,
    this.onTap,
  });

  @override
  State<RemindersHomeCard> createState() => _RemindersHomeCardState();
}

class _RemindersHomeCardState extends State<RemindersHomeCard> {
  bool _snoozed = false;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_snoozed) {
      return const SizedBox.shrink();
    }

    AuthProvider? auth;
    try {
      auth = context.watch<AuthProvider>();
    } catch (_) {}

    final user = auth?.currentUser;
    // Reminders are tailored for individual donors
    if (user != null && user.role == 'bank') {
      return const SizedBox.shrink();
    }

    final derived = auth?.derived;
    final isEligible = widget.eligible ?? derived?.eligible ?? true;
    final nextDate = widget.nextEligibleAt ?? derived?.nextEligibleAt;

    int? days = widget.rechargeDays;
    if (days == null && user?.lastDonationDate != null) {
      days = DateTime.now().difference(user!.lastDonationDate!).inDays;
      if (days < 0) days = 0;
    }

    final headline = isEligible
        ? 'You may be eligible again'
        : 'Resting & recharging';

    final body = isEligible
        ? (days != null && days > 0
            ? 'Your blood has had $days days to recharge. Ready to be somebody\'s hero again?'
            : 'Your blood has recharged. Ready to be somebody\'s hero again?')
        : (nextDate != null
            ? 'Next eligible on ${_formatDate(nextDate)}. Thank you for saving lives!'
            : 'Take some rest. We will notify you when you are eligible to donate again.');

    return Card(
      key: const Key('reminders_home_card'),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isEligible
                ? [
                    Colors.teal.shade700,
                    Colors.teal.shade900,
                  ]
                : [
                    Colors.blueGrey.shade700,
                    Colors.blueGrey.shade900,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEligible
                        ? Icons.volunteer_activism
                        : Icons.battery_charging_full,
                    color: isEligible ? Colors.tealAccent : Colors.amberAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        key: const Key('reminders_home_card_headline'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        key: const Key('reminders_home_card_body'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('reminders_home_card_snooze'),
                  onPressed: () {
                    setState(() {
                      _snoozed = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No pressure. We\'ll check back next month.',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Text(
                    'Remind me later',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  key: const Key('reminders_home_card_cta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isEligible
                        ? Colors.teal.shade900
                        : Colors.blueGrey.shade900,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    if (widget.onTap != null) {
                      widget.onTap!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Check open requests below to find patients in need!',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isEligible ? "I'm ready" : 'View details',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
