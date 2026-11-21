import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_derived.dart';
import '../../core/providers/auth_provider.dart';

/// Home dashboard card for donor ranks.
/// Renders "{n} donations, {rank}" as specified in task B9.
class RanksHomeCard extends StatelessWidget {
  final int? donationCount;
  final String? rankLabel;

  const RanksHomeCard({
    super.key,
    this.donationCount,
    this.rankLabel,
  });

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
      key: const Key('ranks_home_card'),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.red.shade700,
              Colors.red.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.military_tech,
                color: Colors.amber,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count donations, $rank',
                    key: const Key('ranks_home_card_text'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Every drop brings hope and saves lives.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
