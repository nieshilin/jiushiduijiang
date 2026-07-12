/// 音频会话辅助服务
///
/// WebRTC 接管了麦克风采集、Opus 编解码、网络传输、jitter buffer 和音频播放，
/// 本类仅作为音频会话配置和状态管理的轻量封装。
class AudioService {
  bool _isMuted = false;
  double _volume = 0.7;

  bool get isMuted => _isMuted;
  double get volume => _volume;

  /// 设置音量 (0.0 ~ 1.0) — WebRTC 会自动路由到扬声器
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    // flutter_webrtc 在 iOS/Android 上自动管理音频会话和扬声器路由，
    // 音量由系统音量键控制，此处仅做状态记录。
  }

  /// 设置静音
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
  }

  void dispose() {
    // 无需清理资源（WebRTC 管理所有音频资源）
  }
}
