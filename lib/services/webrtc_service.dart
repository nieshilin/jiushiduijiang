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

  // ── 信令发送回调（由 voice_transceiver 注入） ──
  void Function(String deviceId, String message)? onSendSignaling;

  // ── 通话状态回调 ──
  void Function(String deviceId, String deviceName)? onRemoteVoiceStart;
  void Function(String deviceId)? onRemoteVoiceEnd;
  void Function(String deviceId)? onRemoteAudioActive; // 实际收到音频包

  // ── 状态 ──
  bool _initialized = false;
  String _localDeviceId = '';

  bool get isSending => _localTrackEnabled;
  bool get isInitialized => _initialized;

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
          'sampleRate': 16000,
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

      // 2. 配置扬声器（音频会话已激活，确保 iOS 可用）
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Helper.setSpeakerphoneOn(true);
        _log('🔊 扬声器已开启');
      }

      _localAudioTrack = audioTracks.first;
      _localAudioTrack!.enabled = false; // 初始静音（PTT 未按下）
      _initialized = true;
      _log('✅ WebRTC 初始化完成 — 麦克风就绪');
    } catch (e) {
      _log('❌ WebRTC 初始化失败: $e');
    }
  }

  /// 设备上线 → 建立 PeerConnection
  Future<void> onDeviceOnline(String deviceId, String deviceName) async {
    if (!_initialized || kIsWeb) return;
    if (_peers.containsKey(deviceId)) return;

    _log('🔗 建立连接: $deviceName ($deviceId)');
    final peer = _WebRTCPeer(deviceId: deviceId, deviceName: deviceName);
    _peers[deviceId] = peer;

    try {
      // 创建 PeerConnection（纯 LAN，无 ICE 服务器）
      peer.pc = await createPeerConnection({
        'iceServers': [],
        'iceTransportPolicy': 'all',
      });

      // 添加本地音频轨道（unified plan 下自动创建 transceiver）
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          peer.pc!.addTrack(track, _localStream!);
        }
        _log('📤 已添加本地音频轨道 (${_localStream!.getAudioTracks().length} 条)');
      }

      // ★ 远程音频轨道回调 — 使用 onTrack 替代已废弃的 onAddStream
      peer.pc!.onTrack = (RTCTrackEvent event) {
        _log('📻 收到远程音频轨道: ${peer.deviceName}, kind=${event.track.kind}');
        if (event.track.kind == 'audio') {
          peer.remoteAudioTrack = event.track;
          peer.streamReady = true;
          onRemoteAudioActive?.call(deviceId);

          // 监听轨道结束
          event.track.onEnded = () {
            _log('🔇 远程音频轨道结束: ${peer.deviceName}');
          };
        }
      };

      // ICE 候选 → 信令发送
      peer.pc!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendIceCandidate(deviceId, candidate);
      };

      // 连接状态变化
      peer.pc!.onConnectionState = (RTCPeerConnectionState state) {
        _log('📡 连接状态 [${peer.deviceName}]: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          // 失败后尝试重建
          _peers.remove(deviceId);
          peer.pc?.close();
          peer.pc = null;
        }
      };

      // ICE 连接状态
      peer.pc!.onIceConnectionState = (RTCIceConnectionState state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          _log('✅ ICE 已连接: ${peer.deviceName}');
          peer.connected = true;
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _log('❌ ICE 连接失败: ${peer.deviceName}');
          peer.connected = false;
        }
      };

      // 根据 deviceId 决定 polite/impolite 角色，发起协商
      final isPolite = _localDeviceId.compareTo(deviceId) > 0;
      peer.isPolite = isPolite;

      if (!isPolite) {
        // Impolite peer 主动发起 offer
        await _createAndSendOffer(deviceId);
      }
      // Polite peer 等待对端发 offer

    } catch (e) {
      _log('❌ 建立连接失败 [$deviceName]: $e');
      _peers.remove(deviceId);
    }
  }

  /// 设备下线 → 关闭连接
  void onDeviceOffline(String deviceId) {
    final peer = _peers.remove(deviceId);
    if (peer != null) {
      _log('🔌 断开连接: ${peer.deviceName}');
      peer.pc?.close();
      peer.pc = null;
    }
  }

  /// PTT 按下 → 开始发送音频
  void startSending() {
    if (!_initialized || _localTrackEnabled) return;
    _localTrackEnabled = true;
    _localAudioTrack?.enabled = true;
    _log('🎤 PTT 按下 — 开始发送音频');
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
    final peer = _peers[deviceId];
    if (peer == null || peer.pc == null) {
      _log('⚠️ 收到未连接设备的 SDP: $deviceId');
      return;
    }

    try {
      final description = RTCSessionDescription(
        sdp,
        isOffer ? 'offer' : 'answer',
      );

      if (isOffer) {
        // 收到 offer
        if (peer.makingOffer) {
          // 冲突：双方同时发了 offer
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

        // 创建 answer
        final answer = await peer.pc!.createAnswer();
        await peer.pc!.setLocalDescription(answer);
        _sendSdp(deviceId, answer.sdp!, false);
      } else {
        // 收到 answer
        peer.settingRemote = true;
        await peer.pc!.setRemoteDescription(description);
        peer.settingRemote = false;
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
    if (peer == null || peer.pc == null) return;

    try {
      await peer.pc!.addCandidate(
        RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
      );
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
