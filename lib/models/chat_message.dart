import 'dart:convert';

/// 文字消息模型
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });

  /// 格式化时间 HH:MM
  String get timeString {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 序列化为 JSON Map
  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isMe': isMe,
      };

  /// 从 JSON Map 反序列化
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        senderId: json['senderId'] as String? ?? '',
        senderName: json['senderName'] as String? ?? 'Unknown',
        content: json['content'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        ),
        isMe: json['isMe'] as bool? ?? false,
      );

  /// 序列化为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串反序列化
  static ChatMessage fromJsonString(String jsonStr) =>
      ChatMessage.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
