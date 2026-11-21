/// Pure rule functions for user donor ranks based on donation count.
/// As defined in docs/API-addendum-v2.md:
/// Ranks by donation_count:
///   1  "First Drop"      (key: first_drop)
///   3  "Helper"          (key: helper)
///   5  "Silver Lifeline" (key: silver_lifeline)
///   10 "Gold Lifeline"   (key: gold_lifeline)
///   25 "Lifesaver"       (key: lifesaver)
class RankDefinition {
  final String key;
  final String label;
  final int minDonations;
  final String description;

  const RankDefinition({
    required this.key,
    required this.label,
    required this.minDonations,
    required this.description,
  });
}

const List<RankDefinition> kRankDefinitions = [
  RankDefinition(
    key: 'first_drop',
    label: 'First Drop',
    minDonations: 1,
    description: 'First step to saving lives',
  ),
  RankDefinition(
    key: 'helper',
    label: 'Helper',
    minDonations: 3,
    description: 'Stepping up for the community',
  ),
  RankDefinition(
    key: 'silver_lifeline',
    label: 'Silver Lifeline',
    minDonations: 5,
    description: 'Dedicated life saver',
  ),
  RankDefinition(
    key: 'gold_lifeline',
    label: 'Gold Lifeline',
    minDonations: 10,
    description: 'Community champion',
  ),
  RankDefinition(
    key: 'lifesaver',
    label: 'Lifesaver',
    minDonations: 25,
    description: 'Legendary donor',
  ),
];

/// Calculates the donor rank for a given donation count.
/// Returns null if [donationCount] is less than 1.
RankDefinition? calculateRank(int donationCount) {
  RankDefinition? result;
  for (final rank in kRankDefinitions) {
    if (donationCount >= rank.minDonations) {
      result = rank;
    }
  }
  return result;
}

/// Returns the next rank milestone after [donationCount],
/// or null if the donor has reached the highest rank.
RankDefinition? getNextRank(int donationCount) {
  for (final rank in kRankDefinitions) {
    if (donationCount < rank.minDonations) {
      return rank;
    }
  }
  return null;
}
