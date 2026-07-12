import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:jiudhiduijiang/models/device.dart';
import 'package:jiudhiduijiang/services/audio_service.dart';
import 'package:jiudhiduijiang/services/discovery_service.dart';
import 'package:jiudhiduijiang/services/voice_transceiver.dart';

/// 对讲状态
enum TalkStatus { idle, transmitting, receiving }

/// 连接状态
enum ConnectionStatus { disconnected, connecting, connected }

/// 对讲机核心控制器 — 统一管理所有服务与状态
class WalkieController extends ChangeNotifier {
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

  WalkieController({String? deviceId, String? deviceName})
      : _deviceId = deviceId ?? const Uuid().v4(),
        _deviceName = deviceName ?? '对讲机-${DateTime.now().millisecondsSinceEpoch % 10000}' {
    _audio = AudioService();
    _discovery = DiscoveryService(deviceId: _deviceId, deviceName: _deviceName);
    _transceiver = VoiceTransceiver(
      onAudioData: _onRemoteAudioData,
      onVoiceStart: _onRemoteVoiceStart,
      onVoiceEnd: _onRemoteVoiceEnd,
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

  /// 初始化
  Future<void> init() async {
    _connStatus = ConnectionStatus.connecting;
    _log('正在初始化...');
    notifyListeners();

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
  }

  /// 请求系统权限
  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await [
        Permission.microphone,
        Permission.location, // Android 需要位置信息才能扫描局域网
      ].request();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.microphone.request();
    }
    // Windows 不需要显式权限请求
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
    await _audio.startRecording();
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

  /// 本机录音数据 → 发送给对端
  void _onLocalAudioData(Uint8List pcmData) {
    _transceiver.sendAudioData(pcmData);
  }

  /// 收到对端语音数据 → 加入播放队列
  void _onRemoteAudioData(String senderIp, Uint8List pcmData) {
    if (_talkStatus == TalkStatus.transmitting) return; // 半双工：发送时不接收
    _audio.enqueueAudioData(senderIp, pcmData);
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

  void _log(String msg) {
    _lastLog = msg;
    notifyListeners();
  }

  @override
  void dispose() {
    _audio.dispose();
    _transceiver.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
