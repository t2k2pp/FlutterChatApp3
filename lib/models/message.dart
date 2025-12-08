import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  Message({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toApiFormat() {
    return {
      'role': role == MessageRole.user
          ? 'user'
          : role == MessageRole.assistant
              ? 'assistant'
              : 'system',
      'content': content,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: MessageRole.values.firstWhere((e) => e.name == json['role']),
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
