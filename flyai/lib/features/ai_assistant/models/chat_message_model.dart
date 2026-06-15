import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final String id;
  final String sessionId;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'role': role,
        'content': content,
      };

  @override
  List<Object?> get props => [id, sessionId, role, content, createdAt];
}
