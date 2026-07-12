import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 设备发现服务 — UDP 广播 + 心跳保活 + 信号质量检测 + WiFi 变化检测
class DiscoveryService {
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final String deviceId;
  String deviceName;
  String _localIp = '';

  /// 组播地址 — iOS 不支持 UDP 广播，使用组播进行设备发现
  final InternetAddress _multicastAddr =
      InternetAddress(AppConstants.multicastGroup);

  final Map<String, Device> _devices = {};
  final StreamController<List<Device>> _deviceStream =
      StreamController<List<Device>>.broadcast();
  final StreamController<String> _logStream =
      StreamController<String>.broadcast();

  // ping/pong 延迟测量：发送 ping 时记录时间戳
  final Map<String, int> _pendingPings = {}; // senderId -> timestampMs

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
        reusePort: Platform.isIOS || Platform.isMacOS,
        ttl: 1,
      );
      // broadcastEnabled 仅在非 iOS 平台设置（iOS 不支持 SO_BROADCAST）
      if (!Platform.isIOS) {
        _socket!.broadcastEnabled = true;
      }
      // 加入组播组（iOS 必需，其他平台也兼容）
      try {
        _socket!.joinMulticast(_multicastAddr);
        _log('已加入组播组 ${AppConstants.multicastGroup}');
      } catch (e) {
        _log('加入组播组失败: $e');
      }
      _socket!.listen(_handleDatagram);

      _log('发现服务已启动 (端口 ${AppConstants.discoveryPort})');

      // 发送初始发现广播
      await _sendDiscovery();

      // 启动心跳定时器（心跳中附带 ping 时间戳）
      _heartbeatTimer = Timer.periodic(
        Duration(seconds: AppConstants.heartbeatInterval),
        (_) => _sendHeartbeat(),
      );

      // 启动设备清理定时器
      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _cleanupDevices(),
      );

      // 监听 WiFi 网络变化
      _connectivitySub = Connectivity()
          .onConnectivityChanged
          .listen(_onConnectivityChanged);
    } catch (e) {
      _log('发现服务启动失败: $e');
      rethrow;
    }
  }

  /// WiFi 网络变化处理 — 重新获取 IP 并重新发现
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // 检查是否有 WiFi 连接
    final hasWifi = results.any((r) =>
        r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);

    if (!hasWifi) {
      _log('网络已断开');
      return;
    }

    // WiFi 可能发生了变化，重新获取 IP
    _onWifiChanged();
  }

  /// WiFi 变化时重新初始化网络
  Future<void> _onWifiChanged() async {
    _log('检测到网络变化，重新发现设备...');

    // 清除旧设备列表（旧网络的设备不可达）
    _devices.clear();
    _pendingPings.clear();
    _notifyDevices();

    // 重新获取本机 IP
    var newIp = await NetworkInfo().getWifiIP() ?? '';
    if (newIp.isEmpty) {
      newIp = await _getLocalIpFallback();
    }

    if (newIp.isNotEmpty && newIp != _localIp) {
      _localIp = newIp;
      _log('本机IP已更新: $_localIp');

      // 重新绑定 socket
      _socket?.close();
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          AppConstants.discoveryPort,
          reuseAddress: true,
          reusePort: Platform.isIOS || Platform.isMacOS,
          ttl: 1,
        );
        if (!Platform.isIOS) {
          _socket!.broadcastEnabled = true;
        }
        // 重新加入组播组
        try {
          _socket!.joinMulticast(_multicastAddr);
        } catch (e) {
          _log('重新加入组播组失败: $e');
        }
        _socket!.listen(_handleDatagram);
      } catch (e) {
        _log('重新绑定 socket 失败: $e');
      }
    }

    // 重新发送发现广播
    await _sendDiscovery();
  }

  /// 处理接收到的 UDP 数据报
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    // 循环读取所有可用数据报，防止丢包
    while (true) {
      final datagram = _socket?.receive();
      if (datagram == null) break;

      // 过滤本机消息（IP 过滤，_parseMessage 中还有 deviceId 过滤双保险）
      if (_localIp.isNotEmpty && datagram.address.address == _localIp) continue;

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

    // 过滤本机消息（双保险：IP 过滤 + deviceId 过滤）
    if (senderId == deviceId) return;

    switch (prefix) {
      case AppConstants.prefixDiscovery:
        // 收到发现请求，回复自己的信息
        final senderName = parts.length > 2 ? parts[2] : 'Unknown';
        _addOrUpdateDevice(senderId, senderName, senderAddr);
        // 向发现者发送 unicast 回复（确保 iOS 可达）
        _sendResponseTo(senderAddr);
        break;

      case AppConstants.prefixResponse:
        final senderName = parts.length > 2 ? parts[2] : 'Unknown';
        _addOrUpdateDevice(senderId, senderName, senderAddr);
        break;

      case AppConstants.prefixHeartbeat:
        // 更新最后在线时间和心跳计数
        final device = _devices[senderId];
        if (device != null) {
          device.lastSeen = DateTime.now();
          device.heartbeatCount++;
        } else {
          // 收到未知设备心跳，添加它并发送发现请求
          final senderName = parts.length > 2 ? parts[2] : 'Unknown';
          _addOrUpdateDevice(senderId, senderName, senderAddr);
          _sendDiscovery();
        }
        // 如果心跳中附带 ping 时间戳，回复 pong
        if (parts.length > 3) {
          _sendPong(senderId, parts[3]);
        }
        break;

      case AppConstants.prefixPing:
        // 收到 ping，回复 pong（原样返回时间戳）
        final pingTs = parts.length > 2 ? parts[2] : '';
        if (pingTs.isNotEmpty) {
          _sendPongTo(senderId, pingTs);
        }
        break;

      case AppConstants.prefixPong:
        // 收到 pong，计算延迟
        final pingTs = int.tryParse(parts.length > 2 ? parts[2] : '');
        if (pingTs != null && _pendingPings.containsKey(senderId)) {
          final sentTs = _pendingPings[senderId]!;
          final rtt = DateTime.now().millisecondsSinceEpoch - sentTs;
          final device = _devices[senderId];
          if (device != null) {
            device.latencyMs = rtt;
          }
          _pendingPings.remove(senderId);
          _notifyDevices();
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
      existing.heartbeatCount++;
    } else {
      _devices[id] = Device(
        id: id,
        name: name,
        address: address,
        voicePort: AppConstants.voicePort,
      );
      _devices[id]!.heartbeatCount = 1;
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
    // 同时发送 unicast 到子网所有 IP（iOS 可靠后备）
    _sendUnicastToSubnet(data);
  }

  /// 公开方法 — 重新发送发现广播
  Future<void> rediscover() async {
    await _sendDiscovery();
  }

  /// 发送心跳（附带 ping 时间戳用于延迟测量）
  Future<void> _sendHeartbeat() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 记录 pending ping，等待所有已知设备的 pong
    for (final device in _devices.values) {
      _pendingPings[device.id] = now;
    }
    final msg =
        '${AppConstants.prefixHeartbeat}:$deviceId:$deviceName:$now';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 向指定地址发送 unicast 回复
  void _sendResponseTo(InternetAddress targetAddr) {
    final msg =
        '${AppConstants.prefixResponse}:$deviceId:$deviceName';
    final data = utf8.encode(msg);
    try {
      _socket?.send(data, targetAddr, AppConstants.discoveryPort);
    } catch (_) {}
    // 也通过 broadcast 发送，让其他设备也能收到
    _broadcast(data);
  }

  /// 发送 pong（回复心跳中的 ping）
  void _sendPong(String targetId, String pingTs) {
    final msg = '${AppConstants.prefixPong}:$deviceId:$pingTs';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 发送 pong 到指定地址
  void _sendPongTo(String targetId, String pingTs) {
    final msg = '${AppConstants.prefixPong}:$deviceId:$pingTs';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 发送离线通知
  Future<void> sendLeave() async {
    final msg = '${AppConstants.prefixLeave}:$deviceId';
    final data = utf8.encode(msg);
    _broadcast(data);
  }

  /// 发送数据（组播 + 子网广播兼容 + unicast 已知 peer）
  void _broadcast(List<int> data) {
    try {
      // 发送到组播地址（iOS 主要靠此方式发现设备）
      _socket?.send(data, _multicastAddr, AppConstants.discoveryPort);

      // 非 iOS 平台同时发送子网广播（兼容旧版本/增强覆盖）
      if (!Platform.isIOS && _localIp.isNotEmpty) {
        final parts = _localIp.split('.');
        if (parts.length == 4) {
          parts[3] = '255';
          final subnetBroadcast = parts.join('.');
          _socket?.send(
              data, InternetAddress(subnetBroadcast), AppConstants.discoveryPort);
        }
      }

      // 向所有已知 peer 发送 unicast（确保 iOS 上心跳可达）
      for (final device in _devices.values) {
        if (device.isOnline) {
          _socket?.send(data, device.address, AppConstants.discoveryPort);
        }
      }
    } catch (e) {
      // 发送失败静默处理
    }
  }

  /// 向子网内所有 IP 发送 unicast 发现包（iOS 的可靠后备方案）
  void _sendUnicastToSubnet(List<int> data) {
    if (_localIp.isEmpty) return;
    final parts = _localIp.split('.');
    if (parts.length != 4) return;

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
    final selfLast = int.tryParse(parts[3]) ?? -1;

    for (var i = 1; i <= 254; i++) {
      if (i == selfLast) continue; // 跳过自己
      try {
        _socket?.send(data, InternetAddress('$prefix$i'),
            AppConstants.discoveryPort);
      } catch (_) {
        // 忽略单个发送失败
      }
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
        _pendingPings.remove(id);
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
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    // 离开组播组
    try {
      _socket?.leaveMulticast(_multicastAddr);
    } catch (_) {}
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
