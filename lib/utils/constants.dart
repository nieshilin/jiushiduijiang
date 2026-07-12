/// 全局常量定义
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = '就是对讲';

  /// 设备发现 UDP 广播端口
  static const int discoveryPort = 45670;

  /// 语音数据 UDP 端口
  static const int voicePort = 45671;

  /// 心跳间隔（秒）
  static const int heartbeatInterval = 3;

  /// 设备超时离线判定（秒）
  static const int deviceTimeout = 9;

  /// 音频采样率
  static const int sampleRate = 16000;

  /// 音频声道数
  static const int numChannels = 1;

  /// 音频位深
  static const int bitsPerSample = 16;

  /// UDP 单包最大音频数据长度
  static const int maxPacketSize = 1400;

  /// 协议消息前缀
  static const String prefixDiscovery = 'JDHI_DISC';
  static const String prefixResponse = 'JDHI_RESP';
  static const String prefixHeartbeat = 'JDHI_HB';
  static const String prefixVoiceStart = 'JDHI_VS';
  static const String prefixVoiceData = 'JDHI_VD';
  static const String prefixVoiceEnd = 'JDHI_VE';
  static const String prefixLeave = 'JDHI_LEAVE';
  static const String prefixMessage = 'JDHI_MSG';
  static const String prefixPing = 'JDHI_PNG';
  static const String prefixPong = 'JDHI_POG';

  /// 文字消息最大长度
  static const int maxMessageLength = 500;

  /// 信号质量检测间隔（秒）
  static const int qualityCheckInterval = 3;
}
