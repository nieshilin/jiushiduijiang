import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 语音传输收发器 — UDP 收发（WebRTC 信令 + 文字消息 + 通话开始/结束）
///
/// 音频编码/传输/解码由 WebRTC 引擎内部处理，不再经过本类。
/// 本类仅负责：
///   - UDP socket 管理
///   - WebRTC 信令消息转发（SDP/ICE）
///   - 通话开始/结束信号
///   - 文字消息收发
class VoiceTransceiver {
  RawDatagramSocket? _socket;
  final List<Device> _peers = [];

  // ── 通话信号回调 ──
  final void Function(String senderIp, String senderName)? onVoiceStart;
  final void Function(String senderIp)? onVoiceEnd;

  // ── 文字消息回调 ──
  final void Function(String senderIp, String senderId, String senderName, String message)? onMessage;

  // ── WebRTC 信令回调 ──
  /// 收到 SDP (offer/answer)
  final void Function(String senderIp, String deviceId, String sdp, bool isOffer)? onWrtcSdp;
  /// 收到 ICE candidate
  final void Function(String senderIp, String deviceId, String candidate, String sdpMid, int sdpMLineIndex)? onWrtcIce;
  /// 收到断开连接请求
  final void Function(String senderIp, String deviceId)? onWrtcBye;

  VoiceTransceiver({
    this.onVoiceStart,
    this.onVoiceEnd,
    this.onMessage,
    this.onWrtcSdp,
    this.onWrtcIce,
    this.onWrtcBye,
  });

  /// 当前对端数量
  int get peerCount => _peers.length;

  /// 启动语音收发服务
  Future<void> start(String localIp) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.voicePort,
        reuseAddress: true,
        reusePort: Platform.isIOS || Platform.isMacOS,
        ttl: 1,
      );
      _socket!.listen(_handleDatagram);
    } catch (e) {
      rethrow;
    }
  }

  /// 处理接收到的 UDP 数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    while (true) {
      final datagram = _socket?.receive();
      if (datagram == null) break;

      try {
        _processDatagram(datagram.data, datagram.address.address);
      } catch (e) {
        // 忽略解析错误的包
      }
    }
  }

  /// 解析单个数据报
  void _processDatagram(Uint8List data, String senderIp) {
    // 所有数据现在都是文本协议（WebRTC 音频走自己的 SRTP 通道）
    String asString;
    try {
      asString = utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return;
    }

    // ── 通话开始 ──
    if (asString.startsWith(AppConstants.prefixVoiceStart)) {
      final parts = asString.split(':');
      final senderName = parts.length > 2 ? parts[2] : 'Unknown';
      onVoiceStart?.call(senderIp, senderName);
      return;
    }

    // ── 通话结束 ──
    if (asString.startsWith(AppConstants.prefixVoiceEnd)) {
      onVoiceEnd?.call(senderIp);
      return;
    }

    // ── 文字消息 ──
    if (asString.startsWith(AppConstants.prefixMessage)) {
      final firstColon = asString.indexOf(':');
      final afterPrefix = asString.substring(firstColon + 1);
      final secondColon = afterPrefix.indexOf(':');
      if (secondColon < 0) return;
      final senderId = afterPrefix.substring(0, secondColon);
      final rest = afterPrefix.substring(secondColon + 1);
      final thirdColon = rest.indexOf(':');
      if (thirdColon < 0) return;
      final senderName = rest.substring(0, thirdColon);
      final messageContent = rest.substring(thirdColon + 1);
      if (messageContent.isNotEmpty) {
        onMessage?.call(senderIp, senderId, senderName, messageContent);
      }
      return;
    }

    // ── WebRTC SDP ──
    if (asString.startsWith(AppConstants.prefixWrtcSdp)) {
      final parts = asString.split(':');
      // JDHI_WTC:deviceId:type:base64Sdp
      if (parts.length < 4) return;
      final deviceId = parts[1];
      final type = parts[2]; // "offer" or "answer"
      final sdpB64 = parts.sublist(3).join(':'); // SDP 可能包含 ':'
      try {
        final sdp = utf8.decode(base64.decode(sdpB64));
        onWrtcSdp?.call(senderIp, deviceId, sdp, type == 'offer');
      } catch (_) {}
      return;
    }

    // ── WebRTC ICE candidate ──
    if (asString.startsWith(AppConstants.prefixWrtcIce)) {
      final parts = asString.split(':');
      // JDHI_WTI:deviceId:candidateB64:sdpMidB64:sdpMLineIndex
      if (parts.length < 5) return;
      final deviceId = parts[1];
      try {
        final candidate = utf8.decode(base64.decode(parts[2]));
        final sdpMid = utf8.decode(base64.decode(parts[3]));
        final sdpMLineIndex = int.tryParse(parts[4]) ?? 0;
        onWrtcIce?.call(senderIp, deviceId, candidate, sdpMid, sdpMLineIndex);
      } catch (_) {}
      return;
    }

    // ── WebRTC Bye ──
    if (asString.startsWith(AppConstants.prefixWrtcBye)) {
      final parts = asString.split(':');
      if (parts.length >= 2) {
        onWrtcBye?.call(senderIp, parts[1]);
      }
      return;
    }
  }

  // ── 发送方法 ──

  /// 发送原始信令消息（给指定设备）
  void sendSignalingTo(String deviceId, String message) {
    final data = utf8.encode(message);
    _sendToDevice(deviceId, data);
  }

  /// 发送通话开始信号
  void sendVoiceStart(String senderId, String senderName) {
    final msg = '${AppConstants.prefixVoiceStart}:$senderId:$senderName';
    _sendToAllPeers(utf8.encode(msg));
  }

  /// 发送通话结束信号
  void sendVoiceEnd(String senderId) {
    final msg = '${AppConstants.prefixVoiceEnd}:$senderId';
    _sendToAllPeers(utf8.encode(msg));
  }

  /// 发送文字消息
  void sendMessage(String senderId, String senderName, String message) {
    final truncated = message.length > AppConstants.maxMessageLength
        ? message.substring(0, AppConstants.maxMessageLength)
        : message;
    final msg =
        '${AppConstants.prefixMessage}:$senderId:$senderName:$truncated';
    _sendToAllPeers(utf8.encode(msg));
  }

  /// 更新对端设备列表
  void updatePeers(List<Device> peers, String localIp) {
    _peers.clear();
    _peers.addAll(peers.where((d) => d.address.address != localIp));
  }

  /// 向指定设备发送数据
  void _sendToDevice(String deviceId, List<int> data) {
    final peer = _peers.cast<Device?>().firstWhere(
      (d) => d?.id == deviceId,
      orElse: () => null,
    );
    if (peer == null) return;
    try {
      _socket?.send(data, peer.address, peer.voicePort);
    } catch (_) {}
  }

  /// 向所有对端发送数据
  void _sendToAllPeers(List<int> data) {
    for (final peer in _peers) {
      try {
        _socket?.send(data, peer.address, peer.voicePort);
      } catch (_) {}
    }
  }

  /// 停止服务
  Future<void> stop() async {
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
  }
}
