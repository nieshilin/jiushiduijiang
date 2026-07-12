import 'dart:io';

/// 局域网设备模型
class Device {
  final String id;
  String name;
  final InternetAddress address;
  final int voicePort;
  DateTime lastSeen;
  bool isSpeaking;

  Device({
    required this.id,
    required this.name,
    required this.address,
    required this.voicePort,
    DateTime? lastSeen,
    this.isSpeaking = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// 是否在线（根据最后心跳时间判断）
  bool get isOnline {
    return DateTime.now().difference(lastSeen).inSeconds < 10;
  }

  @override
  bool operator ==(Object other) {
    if (other is Device) return id == other.id;
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Device($name@$address:$voicePort)';
}
