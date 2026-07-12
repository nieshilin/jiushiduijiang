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
import 'package:jiudhiduijiang/services/background_service.dart';
import 'package:jiudhiduijiang/services/audio_conflict_service.dart';

/// 对讲状态
enum TalkStatus { idle, transmitting, receiving }

/// 连接状态
enum ConnectionStatus { disconnected, connecting, connected }

/// 对讲机核心控制器 — 统一管理所有服务与状态
class WalkieController extends ChangeNotifier with WidgetsBindingObserver {
  late final DiscoveryService _discovery;
  late final VoiceTransceiver _transceiver;
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
    _discovery = DiscoveryService(deviceId: _deviceId, deviceName: _deviceName);
    _transceiver = VoiceTransceiver(
      onAudioData: _onRemoteAudioData,
      onVoiceStart: _onRemoteVoiceStart,
      onVoiceEnd: _onRemoteVoiceEnd,
      onMessage: _onRemoteMessage,
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

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int get unreadCount => _unreadCount;
  int get messageCount => _messages.length;

  /// 平均信号质量 (0~4)，基于所有在线设备
  int get averageSignalQuality {
    final online = _devices.where((d) => d.isOnline).toList();
    if (online.isEmpty) return 0;
    final avg = online.map((d) => d.signalQuality).reduce((a, b) => a + b) / online.length;
    return avg.round();
  }

  /// 初始化
  Future<void> init() async {
    // 注册生命周期观察者（监听 App 前后台切换）
    WidgetsBinding.instance.addObserver(this);

    _connStatus = ConnectionStatus.connecting;
    _log('正在初始化...');
    notifyListeners();

    // 加载历史消息
    final savedMessages = await loadMessages();
    _messages.addAll(savedMessages);

    // 设置音频回调
    _audio.onAudioData = _onLocalAudioData;
    await _audio.setVolume(_volume);

    if (kIsWeb) {
      // Web 端不支持 dart:io 的 UDP 网络功能，仅初始化 UI
      _localIp = 'Web';
      _log('Web 预览模式 — 网络功能不可用');
      _connStatus = ConnectionStatus.connected;
      notifyListeners();
      return;
    }

    // 请求权限
    await _requestPermissions();

    // 启动语音收发
    await _transceiver.start(_localIp);

    // 启动设备发现
    await _discovery.start();
    _localIp = _discovery.localIp;

    // 监听设备列表
    _discovery.deviceStream.listen((devices) {
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

    // 初始化后台服务和音频冲突检测
    _initBackgroundAndConflict();
  }

  /// 初始化后台服务和音频冲突检测
  Future<void> _initBackgroundAndConflict() async {
    // 音频冲突检测
    _audioConflictPauseEnabled = await loadAudioConflictPause();
    _audioConflict.onConflictStart = _onAudioConflictStart;
    _audioConflict.onConflictEnd = _onAudioConflictEnd;
    if (_audioConflictPauseEnabled) {
      await _audioConflict.start();
    }

    // 后台服务
    final bgEnabled = await loadBackgroundEnabled();
    if (bgEnabled) {
      await startBackgroundService();
    }
  }

  /// 音频冲突开始 — 来电/通话时暂停对讲
  void _onAudioConflictStart() {
    if (_talkStatus != TalkStatus.idle) {
      _audioConflict.saveState(
        transmitting: _talkStatus == TalkStatus.transmitting,
        receiving: _talkStatus == TalkStatus.receiving,
      );
      // 如果正在通话，强制停止
      if (_talkStatus == TalkStatus.transmitting) {
        ptUp();
      }
      _isPausedByConflict = true;
      _log('检测到来电，已暂停对讲');
      notifyListeners();
    }
  }

  /// 音频冲突结束 — 通话结束后恢复
  void _onAudioConflictEnd() {
    if (_isPausedByConflict) {
      _isPausedByConflict = false;
      _log('通话结束，对讲已恢复');
      notifyListeners();
    }
  }

  /// 设置音频冲突暂停开关
  Future<void> setAudioConflictPause(bool enabled) async {
    _audioConflictPauseEnabled = enabled;
    if (enabled) {
      await _audioConflict.start();
    } else {
      _audioConflict.stop();
    }
  }

  /// 启动后台服务
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

  /// 停止后台服务
  Future<void> stopBackgroundService() async {
    await _bgService.stopService();
  }

  /// 更新后台通知内容
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

  /// 请求系统权限
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
      // iOS: 先查当前状态，避免已授权用户误触发请求
      final currentStatus = await Permission.microphone.status;
      _log('麦克风权限状态: $currentStatus');

      if (currentStatus.isGranted) {
        _setMicPermissionDenied(false);
        return;
      }

      if (currentStatus.isRestricted || currentStatus.isPermanentlyDenied) {
        // 受限或永久拒绝：直接标记为拒绝，不再弹系统弹窗
        _setMicPermissionDenied(true);
        return;
      }

      // 尚未请求，尝试弹系统授权弹窗
      final requestedStatus = await Permission.microphone.request();
      _log('麦克风请求结果: $requestedStatus');
      _setMicPermissionDenied(!requestedStatus.isGranted);
      return;
    }

    // Windows 不需要显式权限请求
  }

  /// 统一设置麦克风权限拒绝标志，仅在变化时通知 UI
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

  /// App 生命周期变化 — 从设置页返回时重新检查权限
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckMicPermission();
    }
  }

  /// 重新检查麦克风权限（从设置页返回后调用）
  Future<void> _recheckMicPermission() async {
    final status = await Permission.microphone.status;
    _log('App 恢复前台，麦克风权限状态: $status');

    _setMicPermissionDenied(!status.isGranted);

    if (_micPermissionDenied) {
      // 权限仍被拒绝，通知 UI 重新引导用户
      onPermissionRecheck?.call();
    }
  }

  /// 打开系统应用设置页（引导用户手动授权）
  Future<void> goToSystemSettings() async {
    await openAppSettings();
  }

  // ── PTT 控制 ──

  /// PTT 按下 — 开始通话
  Future<void> ptDown() async {
    if (_talkStatus != TalkStatus.idle) return;

    _talkStatus = TalkStatus.transmitting;
    notifyListeners();

    // 震动反馈
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    }

    // 通知对端通话开始
    _transceiver.sendVoiceStart(_deviceId, _deviceName);

    // 开始录音
    try {
      await _audio.startRecording();
      _log('正在讲话... (对端 ${_transceiver.peerCount} 台)');
    } catch (e) {
      _log('❌ 录音启动失败: $e');
      _talkStatus = TalkStatus.idle;
      notifyListeners();
    }
  }

  /// PTT 松开 — 结束通话
  Future<void> ptUp() async {
    if (_talkStatus != TalkStatus.transmitting) return;

    await _audio.stopRecording();

    // 通知对端通话结束
    _transceiver.sendVoiceEnd(_deviceId);

    _talkStatus = TalkStatus.idle;
    notifyListeners();
  }

  // ── 音频回调 ──

  /// 本机 Opus 编码数据 → 发送给对端
  void _onLocalAudioData(Uint8List opusData) {
    _transceiver.sendAudioData(opusData);
  }

  /// 收到对端 Opus 语音数据 → 解码播放
  void _onRemoteAudioData(String senderIp, Uint8List opusData) {
    if (_talkStatus == TalkStatus.transmitting) return; // 半双工：发送时不接收
    _audio.enqueueAudioData(senderIp, opusData);
  }

  /// 收到对端通话开始信号
  void _onRemoteVoiceStart(String senderIp, String senderName) {
    if (_talkStatus == TalkStatus.transmitting) return; // 半双工
    _talkStatus = TalkStatus.receiving;
    _receivingFrom = senderName;
    _audio.onVoiceStartReceived(senderIp);
    notifyListeners();
  }

  /// 收到对端通话结束信号
  void _onRemoteVoiceEnd(String senderIp) {
    if (_talkStatus != TalkStatus.receiving) return;
    _audio.onVoiceEndReceived(senderIp);
    _talkStatus = TalkStatus.idle;
    _receivingFrom = '';
    notifyListeners();
  }

  // ── 文字消息 ──

  /// 发送文字消息
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

  /// 收到对端文字消息
  void _onRemoteMessage(String senderIp, String senderId, String senderName, String message) {
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
    // 收到消息时震动提醒
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
    updateBackgroundNotification();
    _saveMessages();
    notifyListeners();
  }

  /// 标记消息已读
  void markMessagesRead() {
    _unreadCount = 0;
    notifyListeners();
  }

  /// 清空消息
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

  /// 启动页开关持久化（默认开启）
  static const _keySplashEnabled = 'splash_enabled';

  static Future<bool> loadSplashEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySplashEnabled) ?? true;
  }

  static Future<void> saveSplashEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySplashEnabled, enabled);
  }

  // ── 后台运行 & 通知持久化 ──
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

  /// 保存消息列表到本地存储
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 只保存最近 _maxStoredMessages 条
      final toSave = _messages.length > _maxStoredMessages
          ? _messages.sublist(_messages.length - _maxStoredMessages)
          : _messages;
      final jsonList = toSave.map((m) => m.toJsonString()).toList();
      await prefs.setStringList(_keyMessages, jsonList);
    } catch (_) {
      // 保存失败静默处理
    }
  }

  /// 从本地存储加载历史消息
  static Future<List<ChatMessage>> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyMessages);
      if (jsonList == null || jsonList.isEmpty) return [];
      return jsonList
          .map((str) => ChatMessage.fromJsonString(str))
          .toList();
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
    _transceiver.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
