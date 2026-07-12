import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
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

  // ── 缓冲：信令先于 mDNS 发现到达 ──
  final Map<String, _PendingOffer> _pendingOffers = {};
  final Map<String, List<_PendingIce>> _pendingIceCandidates = {};

  // ── 信令发送回调（由 voice_transceiver 注入） ──
  void Function(String deviceId, String message)? onSendSignaling;

  // ── 通话状态回调 ──
  void Function(String deviceId, String deviceName)? onRemoteVoiceStart;
  void Function(String deviceId)? onRemoteVoiceEnd;
  void Function(String deviceId)? onRemoteAudioActive;

  // ── WebRTC 媒体连接状态回调 ──
  void Function(int connectedCount)? onConnectionCountChanged;

  // ── 状态 ──
  bool _initialized = false;
  String _localDeviceId = '';

  bool get isSending => _localTrackEnabled;
  bool get isInitialized => _initialized;

  /// WebRTC ICE 已建立连接的对端数量
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
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (_localStream == null) {
        _log('getUserMedia returned null');
        return;
      }

      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isEmpty) {
        _log('no audio tracks');
        return;
      }

      _localAudioTrack = audioTracks.first;
      _localAudioTrack!.enabled = false; // PTT 未按下时静音

      // 配置扬声器（音频会话已由 getUserMedia 激活）
      await _configureSpeakerphone(true);

      _initialized = true;
      _log('WebRTC init ok (trackId=${_localAudioTrack!.id})');
    } catch (e) {
      _log('WebRTC init failed: $e');
    }
  }

  /// 配置扬声器模式
  Future<void> _configureSpeakerphone(bool on) async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await Helper.setSpeakerphoneOn(on);
        _log('speakerphone ${on ? "on" : "off"}');
      } catch (e) {
        _log('speakerphone failed: $e');
      }
    }
  }

  // ── 设备生命周期管理 ──

  /// 设备上线 → 建立 PeerConnection
  Future<bool> onDeviceOnline(String deviceId, String deviceName) async {
    if (!_initialized || kIsWeb) return false;
    if (_peers.containsKey(deviceId)) return false;

    _log('connect: $deviceName ($deviceId)');
    final peer = _WebRTCPeer(deviceId: deviceId, deviceName: deviceName);
    _peers[deviceId] = peer;

    try {
      await _setupPeerConnection(deviceId, peer);

      // 确定角色
      peer.isPolite = _localDeviceId.compareTo(deviceId) > 0;

      // ★ 处理缓冲的 ICE 候选（信令先于发现到达）
      final pendingIce = _pendingIceCandidates.remove(deviceId);
      if (pendingIce != null && pendingIce.isNotEmpty) {
        _log('process ${pendingIce.length} buffered ICE candidates: $deviceId');
        for (final pic in pendingIce) {
          await _addIceCandidateSafe(deviceId, peer, pic.candidate, pic.sdpMid, pic.sdpMLineIndex);
        }
      }

      // ★ 检查是否有缓冲的 offer
      final pending = _pendingOffers.remove(deviceId);
      if (pending != null) {
        _log('process buffered offer: $deviceId');
        await onSdpReceived(deviceId, pending.sdp, true);
        return true;
      }

      if (!peer.isPolite) {
        await _createAndSendOffer(deviceId);
      }

      return true;
    } catch (e) {
      _log('connect failed [$deviceName]: $e');
      _peers.remove(deviceId);
      _notifyConnectionCount();
      return false;
    }
  }

  /// 设备下线 → 关闭连接
  void onDeviceOffline(String deviceId) {
    final peer = _peers.remove(deviceId);
    _pendingOffers.remove(deviceId);
    _pendingIceCandidates.remove(deviceId);
    if (peer != null) {
      _log('disconnect: ${peer.deviceName}');
      peer.pc?.close();
      peer.pc = null;
      _notifyConnectionCount();
    }
  }

  /// 同步设备列表：移除已下线的对端
  void syncFromDeviceList(List<String> onlineDeviceIds) {
    final stale = _peers.keys.where((id) => !onlineDeviceIds.contains(id)).toList();
    for (final id in stale) {
      _log('cleanup stale: $id');
      onDeviceOffline(id);
    }
    final stalePending = _pendingOffers.keys
        .where((id) => !onlineDeviceIds.contains(id))
        .toList();
    for (final id in stalePending) {
      _pendingOffers.remove(id);
    }
    final staleIce = _pendingIceCandidates.keys
        .where((id) => !onlineDeviceIds.contains(id))
        .toList();
    for (final id in staleIce) {
      _pendingIceCandidates.remove(id);
    }
  }

  /// 创建 PeerConnection 并配置回调
  Future<void> _setupPeerConnection(String deviceId, _WebRTCPeer peer) async {
    peer.pc = await createPeerConnection({
      'iceServers': [],
      'iceTransportPolicy': 'all',
      'sdpSemantics': 'unified-plan',
    });

    _log('  PeerConnection created: $deviceId');

    // 添加本地音频轨道
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        peer.pc!.addTrack(track, _localStream!);
      }
      _log('  local audio track added');
    }

    // ★ onTrack — unified plan 远程音频轨道到达
    peer.pc!.onTrack = (RTCTrackEvent event) {
      _log('  onTrack: kind=${event.track.kind}, id=${event.track.id}, streams=${event.streams.length}');

      if (event.track.kind == 'audio') {
        // ★ 显式启用远程音频轨道
        event.track.enabled = true;
        peer.remoteAudioTrack = event.track;

        // ★ 保存远程流引用（防止 GC 回收导致音频停止）
        if (event.streams.isNotEmpty) {
          peer.remoteStream = event.streams.first;
          _log('  remote stream saved (${event.streams.length} streams)');
        }

        peer.streamReady = true;
        onRemoteAudioActive?.call(deviceId);
        _log('  remote audio track ready + enabled');

        event.track.onEnded = () {
          _log('  remote track ended: ${peer.deviceName}');
        };
      }
    };

    // ICE 候选 → 信令发送
    peer.pc!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _log('  ICE candidate: ${peer.deviceName} ${candidate.candidate!.split(' ').first}');
        _sendIceCandidate(deviceId, candidate);
      }
    };

    // 连接状态
    peer.pc!.onConnectionState = (RTCPeerConnectionState state) {
      _log('  conn state [${peer.deviceName}]: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _log('  WebRTC connected: ${peer.deviceName}');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _log('  conn lost: ${peer.deviceName} ($state)');
        final wasConnected = peer.connected;
        peer.connected = false;
        if (wasConnected) _notifyConnectionCount();
      }
    };

    // ★ ICE 连接状态 — 媒体通道真正建立的信号
    peer.pc!.onIceConnectionState = (RTCIceConnectionState state) {
      _log('  ICE state [${peer.deviceName}]: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _log('  ICE connected: ${peer.deviceName}');
        peer.connected = true;
        _configureSpeakerphone(true);
        _notifyConnectionCount();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _log('  ICE FAILED: ${peer.deviceName}');
        peer.connected = false;
        _notifyConnectionCount();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _log('  ICE disconnected: ${peer.deviceName}');
        peer.connected = false;
        _notifyConnectionCount();
      }
    };

    peer.pc!.onIceGatheringState = (RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _log('  ICE gathering complete: ${peer.deviceName}');
      }
    };

    peer.pc!.onSignalingState = (RTCSignalingState state) {
      _log('  signaling [${peer.deviceName}]: $state');
    };
  }

  void _notifyConnectionCount() {
    onConnectionCountChanged?.call(connectedPeerCount);
  }

  // ── PTT 控制 ──

  void startSending() {
    if (!_initialized || _localTrackEnabled) return;
    _localTrackEnabled = true;
    _localAudioTrack?.enabled = true;
    _log('PTT down (track enabled=${_localAudioTrack?.enabled})');
  }

  void stopSending() {
    if (!_localTrackEnabled) return;
    _localTrackEnabled = false;
    _localAudioTrack?.enabled = false;
    _log('PTT up (track enabled=false)');
  }

  int get peerCount => _peers.length;

  // ── 信令处理 ──

  /// 收到 SDP（offer 或 answer）
  Future<void> onSdpReceived(String deviceId, String sdp, bool isOffer) async {
    var peer = _peers[deviceId];

    // ★ 收到 offer 但对端尚未发现 → 缓冲
    if (peer == null && isOffer) {
      _log('buffer offer: $deviceId (not discovered yet)');
      _pendingOffers[deviceId] = _PendingOffer(sdp: sdp, timestamp: DateTime.now());
      return;
    }

    if (peer == null || peer.pc == null) {
      _log('SDP from unknown device: $deviceId (isOffer=$isOffer)');
      return;
    }

    try {
      final description = RTCSessionDescription(
        sdp,
        isOffer ? 'offer' : 'answer',
      );

      if (isOffer) {
        _log('SDP offer recv: ${peer.deviceName} (${sdp.length} bytes)');

        if (peer.makingOffer) {
          if (peer.isPolite) {
            _log('glare, polite rollback');
            await _rollbackAndAccept(deviceId, description);
          } else {
            _log('glare, impolite ignore');
          }
          return;
        }

        peer.settingRemote = true;
        await peer.pc!.setRemoteDescription(description);
        peer.settingRemote = false;
        peer.remoteDescriptionSet = true;

        // ★ 处理缓冲的 ICE 候选（在 setRemoteDescription 之前到达的）
        await _flushPendingCandidates(deviceId, peer);

        final answer = await peer.pc!.createAnswer();
        await peer.pc!.setLocalDescription(answer);
        _sendSdp(deviceId, answer.sdp!, false);
        _log('SDP answer sent: ${peer.deviceName}');
      } else {
        _log('SDP answer recv: ${peer.deviceName}');
        peer.settingRemote = true;
        await peer.pc!.setRemoteDescription(description);
        peer.settingRemote = false;
        peer.remoteDescriptionSet = true;

        // ★ 处理缓冲的 ICE 候选
        await _flushPendingCandidates(deviceId, peer);

        _log('SDP negotiation done: ${peer.deviceName}');
      }
    } catch (e) {
      _log('SDP failed [$deviceId]: $e');
      peer.settingRemote = false;
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

    // ★ 对端尚未发现 → 缓冲 ICE 候选
    if (peer == null || peer.pc == null) {
      _log('buffer ICE: $deviceId (not discovered yet)');
      _pendingIceCandidates.putIfAbsent(deviceId, () => []);
      _pendingIceCandidates[deviceId]!.add(
        _PendingIce(candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex),
      );
      return;
    }

    await _addIceCandidateSafe(deviceId, peer, candidate, sdpMid, sdpMLineIndex);
  }

  /// 安全添加 ICE 候选（处理 remoteDescription 尚未设置的情况）
  Future<void> _addIceCandidateSafe(
    String deviceId,
    _WebRTCPeer peer,
    String candidate,
    String sdpMid,
    int sdpMLineIndex,
  ) async {
    // ★ 如果 remoteDescription 尚未设置，缓冲到 peer 内部
    if (!peer.remoteDescriptionSet) {
      _log('buffer ICE (no remote desc yet): ${peer.deviceName}');
      peer.pendingCandidates.add(
        _PendingIce(candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex),
      );
      return;
    }

    try {
      await peer.pc!.addCandidate(
        RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
      );
      _log('  ICE added: ${peer.deviceName} ${candidate.split(' ').first}');
    } catch (e) {
      _log('  ICE add failed [$deviceId]: $e');
    }
  }

  /// 刷新 peer 内部缓冲的 ICE 候选（在 setRemoteDescription 之后调用）
  Future<void> _flushPendingCandidates(String deviceId, _WebRTCPeer peer) async {
    if (peer.pendingCandidates.isEmpty) return;

    _log('flush ${peer.pendingCandidates.length} pending ICE: ${peer.deviceName}');
    final candidates = List<_PendingIce>.from(peer.pendingCandidates);
    peer.pendingCandidates.clear();

    for (final pic in candidates) {
      try {
        await peer.pc!.addCandidate(
          RTCIceCandidate(pic.candidate, pic.sdpMid, pic.sdpMLineIndex),
        );
        _log('  flushed ICE: ${peer.deviceName} ${pic.candidate.split(' ').first}');
      } catch (e) {
        _log('  flush ICE failed: $e');
      }
    }
  }

  /// 收到断开连接请求
  void onByeReceived(String deviceId) {
    onDeviceOffline(deviceId);
  }

  // ── 内部方法 ──

  Future<void> _createAndSendOffer(String deviceId) async {
    final peer = _peers[deviceId];
    if (peer == null || peer.pc == null) return;

    try {
      peer.makingOffer = true;
      final offer = await peer.pc!.createOffer();
      await peer.pc!.setLocalDescription(offer);
      peer.makingOffer = false;

      _log('SDP offer sent: ${peer.deviceName} (${offer.sdp!.length} bytes)');
      _sendSdp(deviceId, offer.sdp!, true);
    } catch (e) {
      peer.makingOffer = false;
      _log('create offer failed [$deviceId]: $e');
    }
  }

  /// Polite peer 回滚并接受对方的 offer
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
      peer.remoteDescriptionSet = true;

      // ★ 刷新缓冲的 ICE 候选
      await _flushPendingCandidates(deviceId, peer);

      final answer = await peer.pc!.createAnswer();
      await peer.pc!.setLocalDescription(answer);
      _sendSdp(deviceId, answer.sdp!, false);
    } catch (e) {
      _log('rollback failed [$deviceId]: $e');
      peer.settingRemote = false;
    }
  }

  void _sendSdp(String deviceId, String sdp, bool isOffer) {
    final type = isOffer ? 'offer' : 'answer';
    final encoded = base64.encode(utf8.encode(sdp));
    onSendSignaling?.call(deviceId, 'JDHI_WTC:$deviceId:$type:$encoded');
  }

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
    _pendingIceCandidates.clear();

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

/// 缓冲的 SDP offer
class _PendingOffer {
  final String sdp;
  final DateTime timestamp;
  _PendingOffer({required this.sdp, required this.timestamp});
}

/// 缓冲的 ICE candidate
class _PendingIce {
  final String candidate;
  final String sdpMid;
  final int sdpMLineIndex;
  _PendingIce({
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
  });
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

  // ★ remoteDescription 是否已设置（用于 ICE 候选缓冲判断）
  bool remoteDescriptionSet = false;

  // ★ peer 内部缓冲的 ICE 候选（remoteDescription 设置前到达的）
  final List<_PendingIce> pendingCandidates = [];

  // Perfect negotiation 状态
  bool isPolite = false;
  bool makingOffer = false;
  bool settingRemote = false;

  _WebRTCPeer({required this.deviceId, required this.deviceName});
}
