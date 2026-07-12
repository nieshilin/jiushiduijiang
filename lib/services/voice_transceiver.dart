import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 语音数据传输收发器 — UDP 收发
class VoiceTransceiver {
  RawDatagramSocket? _socket;
  final List<Device> _peers = [];

  // 收到语音数据回调
  final void Function(String senderIp, Uint8List pcmData)? onAudioData;
  // 收到通话开始信号回调
  final void Function(String senderIp, String senderName)? onVoiceStart;
  // 收到通话结束信号回调
  final void Function(String senderIp)? onVoiceEnd;

  int _seqNum = 0;

  VoiceTransceiver({
    this.onAudioData,
    this.onVoiceStart,
    this.onVoiceEnd,
  });

  /// 启动语音收发服务
  Future<void> start(String localIp) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.voicePort,
        reuseAddress: true,
      );
      _socket!.listen(_handleDatagram);
    } catch (e) {
      rethrow;
    }
  }

  /// 处理接收到的 UDP 数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    final data = datagram.data;
    final senderIp = datagram.address.address;

    // 检查是否为文本控制消息
    if (data.length < 8) return;

    // 尝试解析为文本消息
    final asString = String.fromCharCodes(data);
    if (asString.startsWith(AppConstants.prefixVoiceStart)) {
      // 通话开始信号: JDHI_VS:senderId:senderName
      final parts = asString.split(':');
      final senderName = parts.length > 2 ? parts[2] : 'Unknown';
      onVoiceStart?.call(senderIp, senderName);
      return;
    }

    if (asString.startsWith(AppConstants.prefixVoiceEnd)) {
      // 通话结束信号: JDHI_VE:senderId
      onVoiceEnd?.call(senderIp);
      return;
    }

    // 二进制语音数据: [4字节magic][4字节seq][PCM数据]
    if (data.length >= 8) {
      final magic = data.buffer.asByteData().getUint32(0, Endian.little);
      if (magic == 0x4456444A) {
        // "JDVD" in little-endian
        final pcmData = data.sublist(8);
        if (pcmData.isNotEmpty) {
          onAudioData?.call(senderIp, pcmData);
        }
      }
    }
  }

  /// 更新对端设备列表
  void updatePeers(List<Device> peers, String localIp) {
    _peers.clear();
    _peers.addAll(peers.where((d) => d.address.address != localIp));
  }

  /// 发送通话开始信号
  void sendVoiceStart(String senderId, String senderName) {
    final msg = '${AppConstants.prefixVoiceStart}:$senderId:$senderName';
    final data = utf8.encode(msg);
    _sendToAllPeers(data);
  }

  /// 发送通话结束信号
  void sendVoiceEnd(String senderId) {
    final msg = '${AppConstants.prefixVoiceEnd}:$senderId';
    final data = utf8.encode(msg);
    _sendToAllPeers(data);
  }

  /// 发送语音 PCM 数据
  void sendAudioData(Uint8List pcmData) {
    if (pcmData.isEmpty) return;

    // 分包发送（每个包不超过 maxPacketSize）
    int offset = 0;
    while (offset < pcmData.length) {
      final remaining = pcmData.length - offset;
      final chunkSize =
          remaining > (AppConstants.maxPacketSize - 8)
              ? (AppConstants.maxPacketSize - 8)
              : remaining;

      // 构建数据包: [4字节magic][4字节seq][PCM数据]
      final packet = Uint8List(8 + chunkSize);
      final byteData = packet.buffer.asByteData();
      byteData.setUint32(0, 0x4456444A, Endian.little); // "JDVD"
      byteData.setUint32(4, _seqNum++, Endian.little);
      packet.setRange(8, 8 + chunkSize, pcmData, offset);

      _sendToAllPeers(packet);

      offset += chunkSize;
    }
  }

  /// 向所有对端发送数据
  void _sendToAllPeers(List<int> data) {
    for (final peer in _peers) {
      try {
        _socket?.send(data, peer.address, peer.voicePort);
      } catch (_) {
        // 发送失败静默处理
      }
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
