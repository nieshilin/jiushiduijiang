import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 设备发现服务 — UDP 广播 + 心跳保活
class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;

  final String deviceId;
  String deviceName;
  String _localIp = '';

  final Map<String, Device> _devices = {};
  final StreamController<List<Device>> _deviceStream =
      StreamController<List<Device>>.broadcast();
  final StreamController<String> _logStream =
      StreamController<String>.broadcast();

  Stream<List<Device>> get deviceStream => _deviceStream.stream;
  Stream<String> get logStream => _logStream.stream;
  String get localIp => _localIp;
  List<Device> get devices => _devices.values.toList();
  int get onlineCount =>
      _devices.values.where((d) => d.isOnline).length;

  DiscoveryService({required this.deviceId, required this.deviceName});

  /// 初始化并启动发现服务
  Future<void> start() async {
    try {
      // 获取本机 IP
      _localIp = await NetworkInfo().getWifiIP() ?? '';
      if (_localIp.isEmpty) {
        _log('警告: 无法获取本机IP，尝试其他方式');
        _localIp = await _getLocalIpFallback();
      }
      _log('本机IP: $_localIp');

      // 绑定 UDP socket
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _socket!.listen(_handleDatagram);

      _log('发现服务已启动 (端口 ${AppConstants.discoveryPort})');

      // 发送初始发现广播
      await _sendDiscovery();

      // 启动心跳定时器
      _heartbeatTimer = Timer.periodic(
        Duration(seconds: AppConstants.heartbeatInterval),
        (_) => _sendHeartbeat(),
      );

      // 启动设备清理定时器
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _cleanupDevices(),
      );
    } catch (e) {
      _log('发现服务启动失败: $e');
      rethrow;
    }
  }

  /// 处理接收到的 UDP 数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram == null) return;

      // 过滤本机消息
      if (datagram.address.address == _localIp) return;

      final message = utf8.decode(datagram.data);
      _parseMessage(message, datagram.address);
    }
  }

  /// 解析协议消息
  void _parseMessage(String message, InternetAddress senderAddr) {
    final parts = message.split(':');
    if (parts.length < 2) return;

    final prefix = parts[0];
    final senderId = parts[1];

    switch (prefix) {
      case AppConstants.prefixDiscovery:
        // 收到发现请求，回复自己的信息
        final senderName = parts.length > 2 ? parts[2] : 'Unknown';
        _addOrUpdateDevice(senderId, senderName, senderAddr);
        _sendResponse();
        break;

      case AppConstants.prefixResponse:
        final senderName = parts.length > 2 ? parts[2] : 'Unknown';
        _addOrUpdateDevice(senderId, senderName, senderAddr);
        break;

      case AppConstants.prefixHeartbeat:
        // 更新最后在线时间
        final device = _devices[senderId];
        if (device != null) {
          device.lastSeen = DateTime.now();
        } else {
          // 收到未知设备心跳，添加它并发送发现请求
          final senderName = parts.length > 2 ? parts[2] : 'Unknown';
          _addOrUpdateDevice(senderId, senderName, senderAddr);
          _sendDiscovery();
        }
        break;

      case AppConstants.prefixLeave:
        _devices.remove(senderId);
        _notifyDevices();
        _log('设备离线: $senderId');
        break;
    }
  }

  /// 添加或更新设备
  void _addOrUpdateDevice(
    String id,
    String name,
    InternetAddress address,
  ) {
    if (id == deviceId) return; // 忽略自己

    final existing = _devices[id];
    if (existing != null) {
      existing.name = name;
      existing.lastSeen = DateTime.now();
    } else {
      _devices[id] = Device(
        id: id,
        name: name,
        address: address,
        voicePort: AppConstants.voicePort,
      );
      _log('发现设备: $name (${address.address})');
      _notifyDevices();
    }
  }

  /// 发送发现广播
  Future<void> _sendDiscovery() async {
    final msg =
        '${AppConstants.prefixDiscovery}:$deviceId:$deviceName';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 公开方法 — 重新发送发现广播
  Future<void> rediscover() async {
    await _sendDiscovery();
  }

  /// 发送心跳
  Future<void> _sendHeartbeat() async {
    final msg =
        '${AppConstants.prefixHeartbeat}:$deviceId:$deviceName';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 发送回复
  Future<void> _sendResponse() async {
    final msg =
        '${AppConstants.prefixResponse}:$deviceId:$deviceName';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 发送离线通知
  Future<void> sendLeave() async {
    final msg = '${AppConstants.prefixLeave}:$deviceId';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// UDP 广播（同时发送到 255.255.255.255 和子网广播地址）
  void _broadcast(List<int> data) {
    try {
      // 全局广播
      _socket?.send(data, InternetAddress('255.255.255.255'),
          AppConstants.discoveryPort);

      // 子网广播（假设 /24）
      if (_localIp.isNotEmpty) {
        final parts = _localIp.split('.');
        if (parts.length == 4) {
          parts[3] = '255';
          final subnetBroadcast = parts.join('.');
          _socket?.send(
              data, InternetAddress(subnetBroadcast), AppConstants.discoveryPort);
        }
      }
    } catch (e) {
      // 广播失败静默处理
    }
  }

  /// 清理超时设备
  void _cleanupDevices() {
    final now = DateTime.now();
    final offlineIds = <String>[];
    for (final entry in _devices.entries) {
      if (now.difference(entry.value.lastSeen).inSeconds >=
          AppConstants.deviceTimeout) {
        offlineIds.add(entry.key);
      }
    }
    if (offlineIds.isNotEmpty) {
      for (final id in offlineIds) {
        _log('设备超时离线: ${_devices[id]?.name}');
        _devices.remove(id);
      }
      _notifyDevices();
    }
  }

  /// 通知设备列表更新
  void _notifyDevices() {
    _deviceStream.add(_devices.values.toList());
  }

  /// 获取本机 IP（异步回退方案）
  Future<String> _getLocalIpFallback() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void _log(String msg) {
    _logStream.add(msg);
  }

  /// 停止服务
  Future<void> stop() async {
    await sendLeave();
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _log('发现服务已停止');
  }

  void dispose() {
    stop();
    _deviceStream.close();
    _logStream.close();
  }
}
