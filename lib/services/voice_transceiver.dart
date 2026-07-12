import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 语音数据传输收发器 — UDP 收发（Opus 语音 + 文字消息）
class VoiceTransceiver {
  RawDatagramSocket? _socket;
  final List<Device> _peers = [];

  // 收到 Opus 语音数据回调
  final void Function(String senderIp, Uint8List opusData)? onAudioData;
  // 收到通话开始信号回调
  final void Function(String senderIp, String senderName)? onVoiceStart;
  // 收到通话结束信号回调
  final void Function(String senderIp)? onVoiceEnd;
  // 收到文字消息回调
  final void Function(String senderIp, String senderId, String senderName, String message)? onMessage;
  // 丢包统计回调
  final void Function(String senderIp, int lostPackets, int totalPackets)? onPacketLoss;

  int _seqNum = 0;

  // ── 每个发送者的序列号追踪 ──
  final Map<String, int> _lastSeq = {};       // senderIp -> 上次收到的 seq
  final Map<String, int> _lostPackets = {};   // senderIp -> 累计丢包数
  final Map<String, int> _totalPackets = {};  // senderIp -> 累计收到的包数
  // jitter buffer: 每个发送者的待排序包队列
  final Map<String, List<_VoicePacket>> _jitterBuffer = {};
  // 每个发送者的 jitter 刷新定时器
  final Map<String, Timer> _jitterTimers = {};

  VoiceTransceiver({
    this.onAudioData,
    this.onVoiceStart,
    this.onVoiceEnd,
    this.onMessage,
    this.onPacketLoss,
  });

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

    // 循环读取所有可用数据报，防止丢包
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
    if (data.length < 4) return;

    // 先检查二进制 Opus 语音数据包
    if (data.length >= 8) {
      // 检查 magic "JOPE" (JDHI Opus Encoded)
      // little-endian: J(4A) O(4F) P(50) E(45)
      if (data[0] == 0x4A && data[1] == 0x4F &&
          data[2] == 0x50 && data[3] == 0x45) {
        // 解析序列号
        final byteData = data.buffer.asByteData(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final seq = byteData.getUint32(4, Endian.little);
        final opusData = data.sublist(8);
        if (opusData.isNotEmpty) {
          _handleVoicePacket(senderIp, seq, opusData);
        }
        return;
      }
    }

    // 非二进制包，尝试解析为文本控制消息
    String asString;
    try {
      asString = utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return;
    }

    if (asString.startsWith(AppConstants.prefixVoiceStart)) {
      final parts = asString.split(':');
      final senderName = parts.length > 2 ? parts[2] : 'Unknown';
      // 通话开始时重置该发送者的 seq 追踪
      _lastSeq.remove(senderIp);
      _lostPackets.remove(senderIp);
      _totalPackets.remove(senderIp);
      onVoiceStart?.call(senderIp, senderName);
      return;
    }

    if (asString.startsWith(AppConstants.prefixVoiceEnd)) {
      // 通话结束时刷新 jitter buffer
      _flushJitterBuffer(senderIp);
      _jitterTimers[senderIp]?.cancel();
      _jitterTimers.remove(senderIp);
      onVoiceEnd?.call(senderIp);
      return;
    }

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
  }

  /// 处理收到的语音包 — 检测丢包 + jitter buffer 排序
  void _handleVoicePacket(String senderIp, int seq, Uint8List audioData) {
    _totalPackets[senderIp] = (_totalPackets[senderIp] ?? 0) + 1;

    final lastSeq = _lastSeq[senderIp];
    if (lastSeq != null) {
      // 检测丢包：期望 seq = lastSeq + 1
      final expected = lastSeq + 1;
      if (seq > expected) {
        // 有丢包
        final lost = seq - expected;
        _lostPackets[senderIp] = (_lostPackets[senderIp] ?? 0) + lost;
        onPacketLoss?.call(
          senderIp,
          _lostPackets[senderIp]!,
          _totalPackets[senderIp]!,
        );
      }
      // seq < lastSeq 说明是乱序/重复包，忽略丢包检测
    }
    _lastSeq[senderIp] = seq;

    // 加入 jitter buffer
    _jitterBuffer.putIfAbsent(senderIp, () => []);
    _jitterBuffer[senderIp]!.add(_VoicePacket(seq, audioData));

    // 启动 jitter 定时器（50ms 后刷新，等待可能的乱序包）
    _jitterTimers[senderIp]?.cancel();
    _jitterTimers[senderIp] = Timer(
      const Duration(milliseconds: 50),
      () => _flushJitterBuffer(senderIp),
    );

    // 如果 buffer 积累超过 10 个包，立即刷新
    if (_jitterBuffer[senderIp]!.length >= 10) {
      _flushJitterBuffer(senderIp);
    }
  }

  /// 刷新 jitter buffer — 按 seq 排序后交给播放器
  void _flushJitterBuffer(String senderIp) {
    final buffer = _jitterBuffer[senderIp];
    if (buffer == null || buffer.isEmpty) return;

    // 按 seq 排序
    buffer.sort((a, b) => a.seq.compareTo(b.seq));

    // 合并所有 PCM 数据
    int totalLen = 0;
    for (final pkt in buffer) {
      totalLen += pkt.data.length;
    }
    final merged = Uint8List(totalLen);
    int offset = 0;
    for (final pkt in buffer) {
      merged.setRange(offset, offset + pkt.data.length, pkt.data);
      offset += pkt.data.length;
    }

    buffer.clear();
    onAudioData?.call(senderIp, merged);
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

  /// 发送文字消息
  void sendMessage(String senderId, String senderName, String message) {
    final truncated = message.length > AppConstants.maxMessageLength
        ? message.substring(0, AppConstants.maxMessageLength)
        : message;
    final msg = '${AppConstants.prefixMessage}:$senderId:$senderName:$truncated';
    final data = utf8.encode(msg);
    _sendToAllPeers(data);
  }

  /// 发送 Opus 语音数据
  /// 每个 Opus 包封装为一个 UDP 包：[4B magic "JOPE"][4B seq][Opus data]
  void sendAudioData(Uint8List opusData) {
    if (opusData.isEmpty) return;

    // Opus 帧通常 20-80 bytes，远小于 maxPacketSize，无需分包
    // 但保留安全检查：如果数据超长则分包
    int offset = 0;
    while (offset < opusData.length) {
      final remaining = opusData.length - offset;
      final chunkSize = remaining > (AppConstants.maxPacketSize - 8)
          ? (AppConstants.maxPacketSize - 8)
          : remaining;

      final packet = Uint8List(8 + chunkSize);
      final byteData = packet.buffer.asByteData();
      // magic "JOPE" little-endian: 0x45504F4A
      byteData.setUint32(0, AppConstants.opusMagic, Endian.little);
      byteData.setUint32(4, _seqNum++, Endian.little);
      packet.setRange(8, 8 + chunkSize, opusData, offset);

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
    // 清理 jitter buffer
    for (final timer in _jitterTimers.values) {
      timer.cancel();
    }
    _jitterTimers.clear();
    _jitterBuffer.clear();
    _lastSeq.clear();
    _lostPackets.clear();
    _totalPackets.clear();

    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stop();
  }
}

/// 语音数据包（用于 jitter buffer 排序）
class _VoicePacket {
  final int seq;
  final Uint8List data;

  _VoicePacket(this.seq, this.data);
}
