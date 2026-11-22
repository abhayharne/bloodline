import 'blood_request.dart';

class BloodRequestMatches {
  final int banks;
  final int donors;

  const BloodRequestMatches({required this.banks, required this.donors});

  factory BloodRequestMatches.fromJson(Map<String, dynamic> json) {
    return BloodRequestMatches(
      banks: (json['banks'] as num?)?.toInt() ?? 0,
      donors: (json['donors'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'banks': banks, 'donors': donors};
}

class BloodRequestResponse {
  final BloodRequest request;
  final BloodRequestMatches matches;

  const BloodRequestResponse({
    required this.request,
    required this.matches,
  });

  /// Factory constructor that safely ignores unknown fields
  factory BloodRequestResponse.fromJson(Map<String, dynamic> json) {
    final reqJson = json['request'] is Map<String, dynamic>
        ? json['request'] as Map<String, dynamic>
        : json;
    final matchesJson = json['matches'] is Map<String, dynamic>
        ? json['matches'] as Map<String, dynamic>
        : <String, dynamic>{};

    return BloodRequestResponse(
      request: BloodRequest.fromJson(reqJson),
      matches: BloodRequestMatches.fromJson(matchesJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'matches': matches.toJson(),
      };
}
