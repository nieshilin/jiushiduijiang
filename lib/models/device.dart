import 'dart:io';

import 'package:jiudhiduijiang/utils/constants.dart';

/// 局域网设备模型
class Device {
  final String id;
  String name;
  final InternetAddress address;
  final int voicePort;
  DateTime lastSeen;
  bool isSpeaking;

  /// 心跳接收计数（用于计算丢包率）
  int heartbeatCount = 0;

  /// 最近一次心跳到达时的延迟估算（毫秒），-1 表示未知
  int latencyMs = -1;

  /// 信号质量等级 0~4（0=无信号, 4=极好）
  int get signalQuality {
    final secs = DateTime.now().difference(lastSeen).inSeconds;
    if (secs >= AppConstants.deviceTimeout) return 0;
    if (heartbeatCount < 1) return 1;
    // 综合心跳时效 + 延迟计算质量
    if (secs <= 3 && (latencyMs < 0 || latencyMs <= 50)) return 4;
    if (secs <= 5 && (latencyMs < 0 || latencyMs <= 100)) return 3;
    if (secs <= 7) return 2;
    return 1;
  }

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
