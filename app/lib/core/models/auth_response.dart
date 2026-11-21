import 'user.dart';

class AuthResponse {
  final User user;
  final String token;
  final String nexconnToken;

  const AuthResponse({
    required this.user,
    required this.token,
    required this.nexconnToken,
  });

  /// Factory constructor that safely ignores unknown fields
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'];
    final user = userMap is Map<String, dynamic>
        ? User.fromJson(userMap)
        : User.fromJson(json);

    return AuthResponse(
      user: user,
      token: json['token']?.toString() ?? '',
      nexconnToken: json['nexconn_token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'token': token,
        'nexconn_token': nexconnToken,
      };
}
