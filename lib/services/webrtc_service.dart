import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTC 音频对讲服务
///
/// 架构：
///   预建立 PeerConnection（设备发现时）→ track.enabled 控制 PTT
///   信令通过 UDP unicast（voice_transceiver 转发）
///   纯 LAN 环境，无需 STUN/TURN
///
/// 信令消息格式：
///   JDHI_WTC:deviceId:type:base64data   — SDP offer/answer
///   JDHI_WTI:deviceId:candidate:sdpMid:sdpMLineIndex  — ICE candidate
///   JDHI_WTB:deviceId  — 关闭连接
class WebRTCService {
  // ── 本地音频 ──
  MediaStream? _localStream;
  MediaStreamTrack? _localAudioTrack;
  bool _localTrackEnabled = false;

  // ── 对端连接 ──
  final Map<String, _WebRTCPeer> _peers = {};

  // ── 缓冲：收到 offer 时对端尚未发现 → 暂存待处理 ──
  final Map<String, _PendingOffer> _pendingOffers = {};

  // ── 信令发送回调（由 voice_transceiver 注入） ──
  void Function(String deviceId, String message)? onSendSignaling;

  // ── 通话状态回调 ──
  void Function(String deviceId, String deviceName)? onRemoteVoiceStart;
  void Function(String deviceId)? onRemoteVoiceEnd;
  void Function(String deviceId)? onRemoteAudioActive; // 实际收到音频包

  // ── WebRTC 媒体连接状态回调（与 UDP 信令区分） ──
  void Function(int connectedCount)? onConnectionCountChanged;

  // ── 状态 ──
  bool _initialized = false;
  String _localDeviceId = '';

  bool get isSending => _localTrackEnabled;
  bool get isInitialized => _initialized;

  /// WebRTC ICE 已建立连接的对端数量（不是 UDP 信令，是媒体通道）
  int get connectedPeerCount =>
      _peers.values.where((p) => p.connected).length;

  /// 初始化：获取麦克风流 + 配置扬声器
  Future<void> init({
    required String deviceId,
    required String deviceName,
  }) async {
    if (_initialized) return;
    _localDeviceId = deviceId;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      // 1. 获取麦克风流（激活音频会话）
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (_localStream == null) {
        _log('❌ getUserMedia 返回 null');
        return;
      }

      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isEmpty) {
        _log('❌ 无音频轨道');
        return;
      }

      _localAudioTrack = audioTracks.first;
      _localAudioTrack!.enabled = false; // 初始静音（PTT 未按下）

      // 2. 配置扬声器（音频会话已由 getUserMedia 激活）
      await _configureSpeakerphone(true);

      _initialized = true;
      _log('✅ WebRTC 初始化完成 — 麦克风就绪 (trackId=${_localAudioTrack!.id})');
    } catch (e) {
      _log('❌ WebRTC 初始化失败: $e');
    }
  }

  /// 配置扬声器模式（内部方法，带错误处理）
  Future<void> _configureSpeakerphone(bool on) async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await Helper.setSpeakerphoneOn(on);
        _log('🔊 扬声器已${on ? "开启" : "关闭"}');
      } catch (e) {
        _log('⚠️ 扬声器设置失败 (可能缺权限): $e');
      }
    }
  }

  // ── 设备生命周期管理 ──

  /// 设备上线 → 建立 PeerConnection
  /// 返回 true 表示新建了连接
  Future<bool> onDeviceOnline(String deviceId, String deviceName) async {
    if (!_initialized || kIsWeb) return false;
    if (_peers.containsKey(deviceId)) return false;

    _log('🔗 建立连接: $deviceName ($deviceId)');
    final peer = _WebRTCPeer(deviceId: deviceId, deviceName: deviceName);
    _peers[deviceId] = peer;

    try {
      await _setupPeerConnection(deviceId, peer);

      // 确定角色并发起协商
      peer.isPolite = _localDeviceId.compareTo(deviceId) > 0;

      // ★ 检查是否有缓冲的 offer（信令先于发现到达）
      final pending = _pendingOffers.remove(deviceId);
      if (pending != null) {
        _log('📨 处理缓冲 offer: $deviceId (信令先于发现到达)');
        await onSdpReceived(deviceId, pending.sdp, true);
        return true; // 不再主动发 offer（对方的 offer 已处理）
      }

      if (!peer.isPolite) {
        // Impolite peer 主动发起 offer
        await _createAndSendOffer(deviceId);
      }
      // Polite peer 等待对端发 offer

      return true;
    } catch (e) {
      _log('❌ 建立连接失败 [$deviceName]: $e');
      _peers.remove(deviceId);
      _notifyConnectionCount();
      return false;
    }
  }

  /// 设备下线 → 关闭连接
  void onDeviceOffline(String deviceId) {
    final peer = _peers.remove(deviceId);
    _pendingOffers.remove(deviceId); // 清理缓冲
    if (peer != null) {
      _log('🔌 断开连接: ${peer.deviceName}');
      peer.pc?.close();
      peer.pc = null;
      _notifyConnectionCount();
    }
  }

  /// 同步设备列表：移除已下线的对端，新建新上线的对端
  void syncFromDeviceList(List<String> onlineDeviceIds) {
    // 清理僵尸连接
    final stale = _peers.keys.where((id) => !onlineDeviceIds.contains(id)).toList();
    for (final id in stale) {
      _log('🧹 清理僵尸连接: $id (设备已离线)');
      onDeviceOffline(id);
    }
    // 清理僵尸缓冲
    final stalePending = _pendingOffers.keys
        .where((id) => !onlineDeviceIds.contains(id))
        .toList();
    for (final id in stalePending) {
      _pendingOffers.remove(id);
    }
  }

  /// 创建一个 PeerConnection 并配置回调
  Future<void> _setupPeerConnection(String deviceId, _WebRTCPeer peer) async {
    // 创建 PeerConnection（纯 LAN，无 ICE 服务器）
    peer.pc = await createPeerConnection({
      'iceServers': [],
      'iceTransportPolicy': 'all',
      'sdpSemantics': 'unified-plan',
    });

    _log('  📶 PeerConnection 已创建: $deviceId');

    // 添加本地音频轨道（unified plan 下自动创建 transceiver）
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        peer.pc!.addTrack(track, _localStream!);
      }
      _log('  📤 已添加本地音频轨道 (${_localStream!.getAudioTracks().length} 条)');
    }

    // ★ 远程音频轨道回调 — unified plan 必须用 onTrack
    peer.pc!.onTrack = (RTCTrackEvent event) {
      _log('📻 收到远程音频轨道: ${peer.deviceName}, kind=${event.track.kind}, id=${event.track.id}');
      if (event.track.kind == 'audio') {
        peer.remoteAudioTrack = event.track;
        peer.streamReady = true;
        onRemoteAudioActive?.call(deviceId);
        _log('📻 远程音频轨道已就绪, 应由 WebRTC 引擎自动播放');

        event.track.onEnded = () {
          _log('🔇 远程音频轨道结束: ${peer.deviceName}');
        };
      }
    };

    // ICE 候选 → 信令发送
    peer.pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _log('  🧊 ICE 候选: ${peer.deviceName} type=${candidate.candidate!.split(' ').first}');
        _sendIceCandidate(deviceId, candidate);
      }
    };

    // 连接状态变化
    peer.pc!.onConnectionState = (RTCPeerConnectionState state) {
      _log('📡 连接状态 [${peer.deviceName}]: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _log('✅ WebRTC 媒体连接已建立: ${peer.deviceName}');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _log('❌ 连接断开: ${peer.deviceName} ($state)');
        final wasConnected = peer.connected;
        peer.connected = false;
        if (wasConnected) _notifyConnectionCount();
      }
    };

    // ★ ICE 连接状态 — 关键：这是媒体通道真正建立的信号
    peer.pc!.onIceConnectionState = (RTCIceConnectionState state) {
      _log('🧊 ICE 状态 [${peer.deviceName}]: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _log('✅ ICE 已连接 — 媒体通道就绪: ${peer.deviceName}');
        peer.connected = true;
        // ★ 连接建立后重设扬声器（确保音频路由正确）
        _configureSpeakerphone(true);
        _notifyConnectionCount();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _log('❌ ICE 连接失败: ${peer.deviceName} (WebRTC 音频将无法到达)');
        peer.connected = false;
        _notifyConnectionCount();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _log('⚠️ ICE 断开: ${peer.deviceName}');
        peer.connected = false;
        _notifyConnectionCount();
      }
    };

    // ICE 收集完成
    peer.pc!.onIceGatheringState = (RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _log('  🧊 ICE 收集完成: ${peer.deviceName}');
      }
    };

    // 信令状态
    peer.pc!.onSignalingState = (RTCSignalingState state) {
      _log('  📝 信令状态 [${peer.deviceName}]: $state');
    };
  }

  void _notifyConnectionCount() {
    onConnectionCountChanged?.call(connectedPeerCount);
  }

  // ── PTT 控制 ──

  /// PTT 按下 → 开始发送音频
  void startSending() {
    if (!_initialized || _localTrackEnabled) return;
    _localTrackEnabled = true;
    _localAudioTrack?.enabled = true;
    _log('🎤 PTT 按下 — 开始发送音频 (track enabled: ${_localAudioTrack?.enabled})');
  }

  /// PTT 松开 → 停止发送音频
  void stopSending() {
    if (!_localTrackEnabled) return;
    _localTrackEnabled = false;
    _localAudioTrack?.enabled = false;
    _log('🔇 PTT 松开 — 停止发送音频');
  }

  /// 当前在线对端数量
  int get peerCount => _peers.length;

  // ── 信令处理 ──

  /// 收到 SDP（offer 或 answer）
  Future<void> onSdpReceived(String deviceId, String sdp, bool isOffer) async {
    var peer = _peers[deviceId];

    // ★ 收到 offer 但对端尚未发现 → 缓冲等待
    if (peer == null && isOffer) {
      _log('📨 缓冲 offer: $deviceId (对端尚未发现，等待 mDNS...)');
      _pendingOffers[deviceId] = _PendingOffer(sdp: sdp, timestamp: DateTime.now());
      return;
    }

    if (peer == null || peer.pc == null) {
      _log('⚠️ 收到未连接设备的 SDP: $deviceId (isOffer=$isOffer)');
      return;
    }

    try {
      final description = RTCSessionDescription(
        sdp,
        isOffer ? 'offer' : 'answer',
      );

      if (isOffer) {
        _log('📥 收到 SDP offer: ${peer.deviceName} (${sdp.length} bytes)');
        if (peer.makingOffer) {
          if (peer.isPolite) {
            _log('🔄 协商冲突，polite 方回滚');
            await _rollbackAndAccept(deviceId, description);
          } else {
            _log('🔄 协商冲突，impolite 方忽略');
          }
          return;
        }

        peer.settingRemote = true;
        await peer.pc!.setRemoteDescription(description);
        peer.settingRemote = false;

        final answer = await peer.pc!.createAnswer();
        await peer.pc!.setLocalDescription(answer);
        _sendSdp(deviceId, answer.sdp!, false);
        _log('📤 发送 SDP answer: ${peer.deviceName}');
      } else {
        _log('📥 收到 SDP answer: ${peer.deviceName}');
        peer.settingRemote = true;
        await peer.pc!.setRemoteDescription(description);
        peer.settingRemote = false;
        _log('✅ SDP 协商完成: ${peer.deviceName}');
      }
    } catch (e) {
      _log('❌ SDP 处理失败 [$deviceId]: $e');
    }
  }

  /// 收到 ICE candidate
  Future<void> onIceCandidateReceived(
    String deviceId,
    String candidate,
    String sdpMid,
    int sdpMLineIndex,
  ) async {
    final peer = _peers[deviceId];
    if (peer == null || peer.pc == null) {
      return;
    }

    try {
      await peer.pc!.addCandidate(
        RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
      );
      _log('  🧊 ICE 候选已添加: ${peer.deviceName} type=${candidate.split(' ').first}');
    } catch (e) {
      _log('❌ ICE candidate 添加失败 [$deviceId]: $e');
    }
  }

  /// 收到断开连接请求
  void onByeReceived(String deviceId) {
    onDeviceOffline(deviceId);
  }

  // ── 内部方法 ──

  /// 创建并发送 SDP offer
  Future<void> _createAndSendOffer(String deviceId) async {
    final peer = _peers[deviceId];
    if (peer == null || peer.pc == null) return;

    try {
      peer.makingOffer = true;
      final offer = await peer.pc!.createOffer();
      await peer.pc!.setLocalDescription(offer);
      peer.makingOffer = false;

      _log('📤 发送 SDP offer: ${peer.deviceName} (${offer.sdp!.length} bytes)');
      _sendSdp(deviceId, offer.sdp!, true);
    } catch (e) {
      peer.makingOffer = false;
      _log('❌ 创建 offer 失败 [$deviceId]: $e');
    }
  }

  /// Polite peer 回滚自己的 offer，接受对方的
  Future<void> _rollbackAndAccept(
    String deviceId,
    RTCSessionDescription remoteOffer,
  ) async {
    final peer = _peers[deviceId];
    if (peer == null || peer.pc == null) return;

    try {
      await peer.pc!.setLocalDescription(
        RTCSessionDescription('', 'rollback'),
      );
      peer.makingOffer = false;

      peer.settingRemote = true;
      await peer.pc!.setRemoteDescription(remoteOffer);
      peer.settingRemote = false;

      final answer = await peer.pc!.createAnswer();
      await peer.pc!.setLocalDescription(answer);
      _sendSdp(deviceId, answer.sdp!, false);
    } catch (e) {
      _log('❌ 回滚协商失败 [$deviceId]: $e');
    }
  }

  /// 发送 SDP 到对端
  void _sendSdp(String deviceId, String sdp, bool isOffer) {
    final type = isOffer ? 'offer' : 'answer';
    final encoded = base64.encode(utf8.encode(sdp));
    onSendSignaling?.call(deviceId, 'JDHI_WTC:$deviceId:$type:$encoded');
  }

  /// 发送 ICE candidate 到对端
  void _sendIceCandidate(String deviceId, RTCIceCandidate candidate) {
    final cand = base64.encode(utf8.encode(candidate.candidate ?? ''));
    final mid = base64.encode(utf8.encode(candidate.sdpMid ?? ''));
    final mline = candidate.sdpMLineIndex ?? 0;
    onSendSignaling?.call(
      deviceId,
      'JDHI_WTI:$deviceId:$cand:$mid:$mline',
    );
  }

  /// 释放所有资源
  Future<void> dispose() async {
    for (final peer in _peers.values) {
      peer.pc?.close();
      peer.pc = null;
    }
    _peers.clear();
    _pendingOffers.clear();

    _localAudioTrack?.stop();
    _localAudioTrack = null;
    _localStream?.dispose();
    _localStream = null;
    _initialized = false;
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[WebRTC] $msg');
  }
}

/// 缓冲的 SDP offer（信令先于 mDNS 发现到达）
class _PendingOffer {
  final String sdp;
  final DateTime timestamp;
  _PendingOffer({required this.sdp, required this.timestamp});
}

/// 单个对端的 WebRTC 连接状态
class _WebRTCPeer {
  final String deviceId;
  final String deviceName;

  RTCPeerConnection? pc;
  MediaStream? remoteStream;
  MediaStreamTrack? remoteAudioTrack;
  bool streamReady = false;
  bool connected = false;

  // Perfect negotiation 状态
  bool isPolite = false;
  bool makingOffer = false;
  bool settingRemote = false;

  _WebRTCPeer({required this.deviceId, required this.deviceName});
}
