import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_derived.dart';
import '../../core/providers/auth_provider.dart';

/// Profile screen section displaying donor ranks and milestone badges.
class RanksProfileSection extends StatelessWidget {
  final int? donationCount;
  final String? rankLabel;

  const RanksProfileSection({
    super.key,
    this.donationCount,
    this.rankLabel,
  });

  static const List<Map<String, dynamic>> _milestones = [
    {
      'count': 1,
      'key': 'first_drop',
      'label': 'First Drop',
      'icon': Icons.water_drop
    },
    {
      'count': 3,
      'key': 'helper',
      'label': 'Helper',
      'icon': Icons.volunteer_activism
    },
    {
      'count': 5,
      'key': 'silver_lifeline',
      'label': 'Silver Lifeline',
      'icon': Icons.shield
    },
    {
      'count': 10,
      'key': 'gold_lifeline',
      'label': 'Gold Lifeline',
      'icon': Icons.star
    },
    {
      'count': 25,
      'key': 'lifesaver',
      'label': 'Lifesaver',
      'icon': Icons.emoji_events
    },
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final derived = auth.derived;
    final count = donationCount ?? derived?.donationCount ?? 0;
    final rank = rankLabel ??
        derived?.rank?.label ??
        UserRank.fromDonationCount(count)?.label ??
        (count > 0 ? 'Donor' : 'New Donor');

    return Card(
      key: const Key('ranks_profile_section'),
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
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Donor Rank & Badges',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                // Rank badge chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        rank,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$count lifetime donations completed',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rank Milestones:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _milestones.map((m) {
                final requiredCount = m['count'] as int;
                final isUnlocked = count >= requiredCount;
                return Chip(
                  avatar: Icon(
                    m['icon'] as IconData,
                    size: 16,
                    color: isUnlocked ? Colors.red.shade700 : Colors.grey,
                  ),
                  label: Text(
                    '${m['label']} (${m['count']})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isUnlocked ? FontWeight.bold : FontWeight.normal,
                      color: isUnlocked ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  backgroundColor:
                      isUnlocked ? Colors.red.shade50 : Colors.grey.shade200,
                  side: BorderSide(
                    color:
                        isUnlocked ? Colors.red.shade200 : Colors.grey.shade300,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
