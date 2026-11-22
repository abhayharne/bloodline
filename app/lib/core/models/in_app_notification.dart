import '../scaffold_messenger.dart';

class InAppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;

  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.read = false,
  });

  /// Defensively parse created_at: null or empty must not throw;
  /// surfaces any other parse error in a SnackBar.
  static DateTime? parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed == null) {
      showParseErrorSnackBar(str);
      return null;
    }
    return parsed;
  }

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: parseCreatedAt(json['created_at']),
      read: json['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'created_at': createdAt?.toIso8601String(),
      'read': read,
    };
  }

  InAppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? read,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}
