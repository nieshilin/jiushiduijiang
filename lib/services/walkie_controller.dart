import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:jiudhiduijiang/models/device.dart';
import 'package:jiudhiduijiang/models/chat_message.dart';
import 'package:jiudhiduijiang/services/audio_service.dart';
import 'package:jiudhiduijiang/services/discovery_service.dart';
import 'package:jiudhiduijiang/services/voice_transceiver.dart';
import 'package:jiudhiduijiang/services/webrtc_service.dart';
import 'package:jiudhiduijiang/services/background_service.dart';
import 'package:jiudhiduijiang/services/audio_conflict_service.dart';

/// 对讲状态
enum TalkStatus { idle, transmitting, receiving }

/// 连接状态
enum ConnectionStatus { disconnected, connecting, connected }

/// 对讲机核心控制器 — 统一管理所有服务与状态
///
/// 音频路径：Mic → WebRTC(getUserMedia) → Opus(内置) → SRTP → ... → WAV(无)
/// WebRTC 引擎内部处理音频采集、编码、传输、jitter buffer、解码和播放，
/// walkie_controller 仅负责控制流和信令协调。
class WalkieController extends ChangeNotifier with WidgetsBindingObserver {
  late final DiscoveryService _discovery;
  late final VoiceTransceiver _transceiver;
  late final WebRTCService _webrtc;
  late final AudioService _audio;

  final String _deviceId;
  String _deviceName;
  String _localIp = '';

  // ── 状态 ──
  TalkStatus _talkStatus = TalkStatus.idle;
  ConnectionStatus _connStatus = ConnectionStatus.disconnected;
  List<Device> _devices = [];
  double _volume = 0.7;
  bool _isMuted = false;
  String _receivingFrom = '';
  String _lastLog = '';
  int _webrtcConnectedCount = 0;

  // ── 消息列表 ──
  final List<ChatMessage> _messages = [];
  int _unreadCount = 0;

  /// 消息持久化 key
  static const _keyMessages = 'chat_messages';
  /// 最大保存消息条数
  static const int _maxStoredMessages = 200;

  // ── 后台服务 & 音频冲突 ──
  final BackgroundService _bgService = BackgroundService();
  final AudioConflictService _audioConflict = AudioConflictService();
  bool _audioConflictPauseEnabled = true;
  bool _isPausedByConflict = false;

  // ── 权限状态 ──
  bool _micPermissionDenied = false;

  /// 权限重新检查回调（从设置页返回后仍被拒绝时通知 UI）
  void Function()? onPermissionRecheck;

  WalkieController({String? deviceId, String? deviceName})
      : _deviceId = deviceId ?? const Uuid().v4(),
        _deviceName = deviceName ?? '对讲机-${DateTime.now().millisecondsSinceEpoch % 10000}' {
    _audio = AudioService();
    _webrtc = WebRTCService();
    _discovery = DiscoveryService(deviceId: _deviceId, deviceName: _deviceName);
    _transceiver = VoiceTransceiver(
      onVoiceStart: _onRemoteVoiceStart,
      onVoiceEnd: _onRemoteVoiceEnd,
      onMessage: _onRemoteMessage,
      onWrtcSdp: _onWrtcSdp,
      onWrtcIce: _onWrtcIce,
      onWrtcBye: _onWrtcBye,
    );
  }

  // ── Getters ──
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get localIp => _localIp;
  TalkStatus get talkStatus => _talkStatus;
  ConnectionStatus get connStatus => _connStatus;
  List<Device> get devices => _devices;
  int get onlineCount => _devices.where((d) => d.isOnline).length;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  String get receivingFrom => _receivingFrom;
  String get lastLog => _lastLog;
  bool get isPTTActive => _talkStatus == TalkStatus.transmitting;
  bool get micPermissionDenied => _micPermissionDenied;
  int get webrtcConnectedCount => _webrtcConnectedCount;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int get unreadCount => _unreadCount;
  int get messageCount => _messages.length;

  /// 平均信号质量 (0~4)，基于所有在线设备
  int get averageSignalQuality {
    final online = _devices.where((d) => d.isOnline).toList();
    if (online.isEmpty) return 0;
    final avg =
        online.map((d) => d.signalQuality).reduce((a, b) => a + b) / online.length;
    return avg.round();
  }

  /// 初始化
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    _connStatus = ConnectionStatus.connecting;
    _log('正在初始化...');
    notifyListeners();

    // 加载历史消息
    final savedMessages = await loadMessages();
    _messages.addAll(savedMessages);

    await _audio.setVolume(_volume);

    if (kIsWeb) {
      _localIp = 'Web';
      _log('Web 预览模式 — 网络功能不可用');
      _connStatus = ConnectionStatus.connected;
      notifyListeners();
      return;
    }

    // 请求权限
    await _requestPermissions();

    // 初始化 WebRTC（麦克风采集 + 编解码引擎）
    await _webrtc.init(deviceId: _deviceId, deviceName: _deviceName);

    // 信令转发：WebRTC → UDP
    _webrtc.onSendSignaling = (deviceId, message) {
      _transceiver.sendSignalingTo(deviceId, message);
    };

    // WebRTC 远程音频事件（可选，主要靠 voice_start/voice_end 协调状态）
    _webrtc.onRemoteAudioActive = (deviceId) {
      // 远程音频到达，可触发 UI 反馈
    };

    // WebRTC 媒体连接数变化 → 更新 UI
    _webrtc.onConnectionCountChanged = (count) {
      _webrtcConnectedCount = count;
      notifyListeners();
    };

    // 启动语音收发（用于信令 + 文字消息 + 通话信号）
    await _transceiver.start(_localIp);

    // 启动设备发现
    await _discovery.start();
    _localIp = _discovery.localIp;

    // 监听设备列表 → WebRTC 建立/断开连接
    _discovery.deviceStream.listen((devices) {
      _syncPeersWithWebRTC(devices);
      _devices = devices;
      _transceiver.updatePeers(devices, _localIp);
      _connStatus = ConnectionStatus.connected;
      notifyListeners();
    });

    _discovery.logStream.listen((msg) {
      _log(msg);
    });

    _log('就绪 — 本机IP: $_localIp');
    _connStatus = ConnectionStatus.connected;
    notifyListeners();

    _initBackgroundAndConflict();
  }

  /// 同步设备列表到 WebRTC 连接
  void _syncPeersWithWebRTC(List<Device> currentDevices) {
    // 获取当前在线设备 ID 列表（排除本机）
    final onlineIds = currentDevices
        .where((d) => d.isOnline && d.address.address != _localIp)
        .map((d) => d.id)
        .toList();

    // 清理已离线的僵尸 WebRTC 连接
    _webrtc.syncFromDeviceList(onlineIds);

    // 自动为新上线设备建立 WebRTC 连接
    for (final device in currentDevices) {
      if (device.isOnline && device.address.address != _localIp) {
        _webrtc.onDeviceOnline(device.id, device.name);
      }
    }
  }

  /// 初始化后台服务和音频冲突检测
  Future<void> _initBackgroundAndConflict() async {
    _audioConflictPauseEnabled = await loadAudioConflictPause();
    _audioConflict.onConflictStart = _onAudioConflictStart;
    _audioConflict.onConflictEnd = _onAudioConflictEnd;
    if (_audioConflictPauseEnabled) {
      await _audioConflict.start();
    }

    final bgEnabled = await loadBackgroundEnabled();
    if (bgEnabled) {
      await startBackgroundService();
    }
  }

  void _onAudioConflictStart() {
    if (_talkStatus != TalkStatus.idle) {
      _audioConflict.saveState(
        transmitting: _talkStatus == TalkStatus.transmitting,
        receiving: _talkStatus == TalkStatus.receiving,
      );
      if (_talkStatus == TalkStatus.transmitting) {
        ptUp();
      }
      _isPausedByConflict = true;
      _log('检测到来电，已暂停对讲');
      notifyListeners();
    }
  }

  void _onAudioConflictEnd() {
    if (_isPausedByConflict) {
      _isPausedByConflict = false;
      _log('通话结束，对讲已恢复');
      notifyListeners();
    }
  }

  Future<void> setAudioConflictPause(bool enabled) async {
    _audioConflictPauseEnabled = enabled;
    if (enabled) {
      await _audioConflict.start();
    } else {
      _audioConflict.stop();
    }
  }

  Future<void> startBackgroundService() async {
    final notifEnabled = await loadNotificationEnabled();
    if (notifEnabled) {
      await _bgService.requestNotificationPermission();
    }
    await _bgService.startService(
      title: '就是对讲',
      content: '对讲机运行中 — $onlineCount 台设备在线',
    );
  }

  Future<void> stopBackgroundService() async {
    await _bgService.stopService();
  }

  void updateBackgroundNotification() {
    if (_bgService.isRunning) {
      _bgService.updateNotification(
        title: '就是对讲',
        content: _talkStatus == TalkStatus.transmitting
            ? '正在通话...'
            : _talkStatus == TalkStatus.receiving
                ? '$_receivingFrom 正在讲话'
                : '对讲机运行中 — $onlineCount 台设备在线',
      );
    }
  }

  // ── 权限 ──

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final results = await [
        Permission.microphone,
        Permission.location,
        Permission.phone,
      ].request();
      final micStatus = results[Permission.microphone];
      _setMicPermissionDenied(!(micStatus?.isGranted ?? false));
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final currentStatus = await Permission.microphone.status;
      _log('麦克风权限状态: $currentStatus');

      if (currentStatus.isGranted) {
        _setMicPermissionDenied(false);
        return;
      }

      if (currentStatus.isRestricted || currentStatus.isPermanentlyDenied) {
        _setMicPermissionDenied(true);
        return;
      }

      final requestedStatus = await Permission.microphone.request();
      _log('麦克风请求结果: $requestedStatus');
      _setMicPermissionDenied(!requestedStatus.isGranted);
      return;
    }
  }

  void _setMicPermissionDenied(bool denied) {
    if (_micPermissionDenied == denied) return;
    _micPermissionDenied = denied;
    if (denied) {
      _log('麦克风权限被拒绝');
    } else {
      _log('麦克风权限已授予');
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckMicPermission();
    }
  }

  Future<void> _recheckMicPermission() async {
    final status = await Permission.microphone.status;
    _log('App 恢复前台，麦克风权限状态: $status');
    _setMicPermissionDenied(!status.isGranted);
    if (_micPermissionDenied) {
      onPermissionRecheck?.call();
    }
  }

  Future<void> goToSystemSettings() async {
    await openAppSettings();
  }

  // ── PTT 控制 ──

  /// PTT 按下 — 开始通话
  Future<void> ptDown() async {
    if (_talkStatus != TalkStatus.idle) return;

    _talkStatus = TalkStatus.transmitting;
    notifyListeners();

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    }

    // 通知对端通话开始
    _transceiver.sendVoiceStart(_deviceId, _deviceName);

    // 启用 WebRTC 音频轨道 → 开始发送音频
    _webrtc.startSending();

    _log('正在讲话... (对端 ${_webrtc.peerCount} 台)');
  }

  /// PTT 松开 — 结束通话
  Future<void> ptUp() async {
    if (_talkStatus != TalkStatus.transmitting) return;

    // 禁用 WebRTC 音频轨道 → 停止发送音频
    _webrtc.stopSending();

    // 通知对端通话结束
    _transceiver.sendVoiceEnd(_deviceId);

    _talkStatus = TalkStatus.idle;
    notifyListeners();
  }

  // ── WebRTC 信令回调 ──

  /// 收到 SDP（offer 或 answer）
  void _onWrtcSdp(String senderIp, String deviceId, String sdp, bool isOffer) {
    _webrtc.onSdpReceived(deviceId, sdp, isOffer);
  }

  /// 收到 ICE candidate
  void _onWrtcIce(
    String senderIp,
    String deviceId,
    String candidate,
    String sdpMid,
    int sdpMLineIndex,
  ) {
    _webrtc.onIceCandidateReceived(deviceId, candidate, sdpMid, sdpMLineIndex);
  }

  /// 收到断开连接请求
  void _onWrtcBye(String senderIp, String deviceId) {
    _webrtc.onByeReceived(deviceId);
  }

  // ── 通话信号回调 ──

  /// 收到对端通话开始信号
  void _onRemoteVoiceStart(String senderIp, String senderName) {
    if (_talkStatus == TalkStatus.transmitting) return; // 半双工
    _talkStatus = TalkStatus.receiving;
    _receivingFrom = senderName;
    // WebRTC 自动播放远程音频，无需手动操作
    notifyListeners();
  }

  /// 收到对端通话结束信号
  void _onRemoteVoiceEnd(String senderIp) {
    if (_talkStatus != TalkStatus.receiving) return;
    _talkStatus = TalkStatus.idle;
    _receivingFrom = '';
    notifyListeners();
  }

  // ── 文字消息 ──

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final msg = ChatMessage(
      id: '${_deviceId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _deviceId,
      senderName: _deviceName,
      content: trimmed,
      timestamp: DateTime.now(),
      isMe: true,
    );
    _messages.add(msg);
    _transceiver.sendMessage(_deviceId, _deviceName, trimmed);
    _saveMessages();
    notifyListeners();
  }

  void _onRemoteMessage(
      String senderIp, String senderId, String senderName, String message) {
    final msg = ChatMessage(
      id: '${senderId}_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      content: message,
      timestamp: DateTime.now(),
      isMe: false,
    );
    _messages.add(msg);
    _unreadCount++;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
    updateBackgroundNotification();
    _saveMessages();
    notifyListeners();
  }

  void markMessagesRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _unreadCount = 0;
    _saveMessages();
    notifyListeners();
  }

  // ── 音量控制 ──

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _audio.setVolume(_volume);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _audio.setMuted(_isMuted);
    notifyListeners();
  }

  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _audio.setMuted(_isMuted);
    notifyListeners();
  }

  // ── 设备名称 ──

  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    _discovery.deviceName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', name);
    await _discovery.rediscover();
    notifyListeners();
  }

  // ── 持久化 ──

  static Future<String> loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_name') ?? '';
  }

  static Future<String> loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id') ?? '';
    if (id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  static const _keySplashEnabled = 'splash_enabled';

  static Future<bool> loadSplashEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySplashEnabled) ?? true;
  }

  static Future<void> saveSplashEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySplashEnabled, enabled);
  }

  static const _keyBackgroundEnabled = 'background_enabled';
  static const _keyNotificationEnabled = 'notification_enabled';
  static const _keyAudioConflictPause = 'audio_conflict_pause';

  static Future<bool> loadBackgroundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundEnabled) ?? true;
  }

  static Future<void> saveBackgroundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundEnabled, enabled);
  }

  static Future<bool> loadNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationEnabled) ?? true;
  }

  static Future<void> saveNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationEnabled, enabled);
  }

  static Future<bool> loadAudioConflictPause() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAudioConflictPause) ?? true;
  }

  static Future<void> saveAudioConflictPause(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAudioConflictPause, enabled);
  }

  // ── 消息持久化 ──

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _messages.length > _maxStoredMessages
          ? _messages.sublist(_messages.length - _maxStoredMessages)
          : _messages;
      final jsonList = toSave.map((m) => m.toJsonString()).toList();
      await prefs.setStringList(_keyMessages, jsonList);
    } catch (_) {}
  }

  static Future<List<ChatMessage>> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyMessages);
      if (jsonList == null || jsonList.isEmpty) return [];
      return jsonList.map((str) => ChatMessage.fromJsonString(str)).toList();
    } catch (_) {
      return [];
    }
  }

  void _log(String msg) {
    _lastLog = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioConflict.dispose();
    _bgService.stopService();
    _audio.dispose();
    _webrtc.dispose();
    _transceiver.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
