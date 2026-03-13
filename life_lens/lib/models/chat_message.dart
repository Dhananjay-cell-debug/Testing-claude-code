class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isDaily; // true = this is the daily brief message

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isDaily = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'is_daily': isDaily ? 1 : 0,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    role: map['role'] as String,
    content: map['content'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    isDaily: (map['is_daily'] as int) == 1,
  );
}
