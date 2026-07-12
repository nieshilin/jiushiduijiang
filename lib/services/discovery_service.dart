import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/models/device.dart';

/// 设备发现服务 — Bonsoir/mDNS 系统托管发现 + UDP unicast 心跳保活
///
/// 使用 Bonsoir（基于 Apple Bonjour / Android NSD）进行设备发现，
/// iOS 不需要 multicast entitlement。
/// 心跳/ping/pong 通过 UDP unicast 发送到已知 peer。
class DiscoveryService {
  // ── Bonsoir ──
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;

  // ── UDP socket（仅 unicast 心跳/ping/pong）──
  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final String deviceId;
  String deviceName;
  String _localIp = '';

  final Map<String, Device> _devices = {};
  final StreamController<List<Device>> _deviceStream =
      StreamController<List<Device>>.broadcast();
  final StreamController<String> _logStream =
      StreamController<String>.broadcast();

  // ping/pong 延迟测量
  final Map<String, int> _pendingPings = {};

  Stream<List<Device>> get deviceStream => _deviceStream.stream;
  Stream<String> get logStream => _logStream.stream;
  String get localIp => _localIp;
  List<Device> get devices => _devices.values.toList();
  int get onlineCount => _devices.values.where((d) => d.isOnline).length;

  /// Bonsoir 服务类型
  static const String serviceType = '_jiudhi._udp';

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

      // 绑定 UDP socket（仅用于 unicast 心跳）
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: Platform.isIOS || Platform.isMacOS,
        ttl: 1,
      );
      _socket!.listen(_handleDatagram);
      _log('UDP 心跳服务已启动 (端口 ${AppConstants.discoveryPort})');

      // 启动 Bonsoir 广播和发现
      await _startBonsoir();

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

      // 监听 WiFi 网络变化
      _connectivitySub = Connectivity()
          .onConnectivityChanged
          .listen(_onConnectivityChanged);
    } catch (e) {
      _log('发现服务启动失败: $e');
      rethrow;
    }
  }

  // ── Bonsoir 广播和发现 ──

  /// 启动 Bonsoir 广播和发现
  Future<void> _startBonsoir() async {
    // 发布服务
    final service = BonsoirService(
      name: deviceId,
      type: serviceType,
      port: AppConstants.voicePort,
      attributes: {
        'id': deviceId,
        'name': deviceName,
        'ip': _localIp,
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();
    _log('Bonsoir 广播已启动: $deviceName ($serviceType)');

    // 发现服务
    _discovery = BonsoirDiscovery(type: serviceType);
    await _discovery!.initialize();
    _discoverySub = _discovery!.eventStream!.listen(_onDiscoveryEvent);
    await _discovery!.start();
    _log('Bonsoir 发现已启动');
  }

  /// 停止 Bonsoir 广播和发现
  Future<void> _stopBonsoir() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery?.stop();
    _discovery = null;
    await _broadcast?.stop();
    _broadcast = null;
  }

  /// 处理 Bonsoir 发现事件
  void _onDiscoveryEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        // 发现服务，尝试解析
        event.service.resolve(_discovery!.serviceResolver);
        _log('发现服务: ${event.service.name}');
        break;

      case BonsoirDiscoveryServiceResolvedEvent():
        _onServiceResolved(event.service);
        break;

      case BonsoirDiscoveryServiceLostEvent():
        final serviceId = event.service.name;
        if (_devices.containsKey(serviceId)) {
          _devices.remove(serviceId);
          _notifyDevices();
          _log('设备离线: ${event.service.name}');
        }
        break;

      case BonsoirDiscoveryServiceUpdatedEvent():
        _onServiceResolved(event.service);
        break;

      default:
        break;
    }
  }

  /// 服务已解析 — 提取 IP 并添加/更新设备
  void _onServiceResolved(BonsoirService service) {
    final id = service.attributes['id'] ?? service.name;
    if (id == deviceId) return; // 忽略自己

    final name = service.attributes['name'] ?? service.name;
    final ip = service.attributes['ip'] ?? '';

    InternetAddress address;
    if (ip.isNotEmpty) {
      address = InternetAddress(ip);
    } else if (service.host != null && service.host!.isNotEmpty) {
      // 从 host 解析 IP
      try {
        final lookup = InternetAddress.lookup(service.host!);
        // 异步解析，先用 host 作为地址
        address = InternetAddress(service.host!);
        // 后台解析真实 IP
        lookup.then((addresses) {
          if (addresses.isNotEmpty) {
            _addOrUpdateDevice(id, name, addresses.first);
          }
        });
        return;
      } catch (_) {
        address = InternetAddress(service.host ?? '0.0.0.0');
      }
    } else {
      return;
    }

    _addOrUpdateDevice(id, name, address);
  }

  // ── UDP 心跳/ping/pong ──

  /// 处理接收到的 UDP 数据报（心跳/ping/pong/leave）
  void _handleDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    while (true) {
      final datagram = _socket?.receive();
      if (datagram == null) break;

      // 过滤本机消息
      if (_localIp.isNotEmpty && datagram.address.address == _localIp) continue;

      String message;
      try {
        message = utf8.decode(datagram.data);
      } catch (_) {
        continue;
      }
      _parseMessage(message, datagram.address);
    }
  }

  /// 解析协议消息
  void _parseMessage(String message, InternetAddress senderAddr) {
    final parts = message.split(':');
    if (parts.length < 2) return;

    final prefix = parts[0];
    final senderId = parts[1];

    if (senderId == deviceId) return;

    switch (prefix) {
      case AppConstants.prefixHeartbeat:
        final device = _devices[senderId];
        if (device != null) {
          device.lastSeen = DateTime.now();
          device.heartbeatCount++;
        } else {
          // 收到未知设备心跳，添加它
          final senderName = parts.length > 2 ? parts[2] : 'Unknown';
          _addOrUpdateDevice(senderId, senderName, senderAddr);
        }
        // 回复 pong
        if (parts.length > 3) {
          _sendPongTo(senderAddr, parts[3]);
        }
        break;

      case AppConstants.prefixPing:
        final pingTs = parts.length > 2 ? parts[2] : '';
        if (pingTs.isNotEmpty) {
          _sendPongTo(senderAddr, pingTs);
        }
        break;

      case AppConstants.prefixPong:
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
        if (_devices.containsKey(senderId)) {
          _devices.remove(senderId);
          _notifyDevices();
          _log('设备离开: $senderId');
        }
        break;
    }
  }

  /// 添加或更新设备
  void _addOrUpdateDevice(String id, String name, InternetAddress address) {
    if (id == deviceId) return;

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

  /// 公开方法 — 重新发送心跳
  Future<void> rediscover() async {
    _sendHeartbeat();
  }

  /// 发送心跳（附带 ping 时间戳）— unicast 到所有已知 peer
  void _sendHeartbeat() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final device in _devices.values) {
      _pendingPings[device.id] = now;
    }
    final msg =
        '${AppConstants.prefixHeartbeat}:$deviceId:$deviceName:$now';
    final data = utf8.encode(msg);
    _sendToAllPeers(data);
  }

  /// 发送 pong 到指定地址
  void _sendPongTo(InternetAddress targetAddr, String pingTs) {
    final msg = '${AppConstants.prefixPong}:$deviceId:$pingTs';
    final data = utf8.encode(msg);
    try {
      _socket?.send(data, targetAddr, AppConstants.discoveryPort);
    } catch (_) {}
  }

  /// 发送离线通知
  Future<void> sendLeave() async {
    final msg = '${AppConstants.prefixLeave}:$deviceId';
    final data = utf8.encode(msg);
    _sendToAllPeers(data);
  }

  /// 向所有已知 peer 发送 unicast 数据
  void _sendToAllPeers(List<int> data) {
    for (final device in _devices.values) {
      if (device.isOnline) {
        try {
          _socket?.send(data, device.address, AppConstants.discoveryPort);
        } catch (_) {}
      }
    }
  }

  // ── WiFi 变化处理 ──

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasWifi = results.any((r) =>
        r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
    if (!hasWifi) {
      _log('网络已断开');
      return;
    }
    _onWifiChanged();
  }

  Future<void> _onWifiChanged() async {
    _log('检测到网络变化，重新发现设备...');

    _devices.clear();
    _pendingPings.clear();
    _notifyDevices();

    // 重新获取本机 IP
    var newIp = await NetworkInfo().getWifiIP() ?? '';
    if (newIp.isEmpty) {
      newIp = await _getLocalIpFallback();
    }

    if (newIp.isNotEmpty) {
      _localIp = newIp;
      _log('本机IP已更新: $_localIp');
    }

    // 重启 Bonsoir（更新 TXT 记录中的 IP）
    await _stopBonsoir();
    await _startBonsoir();

    // 发送心跳
    _sendHeartbeat();
  }

  // ── 设备清理 ──

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

  // ── 工具方法 ──

  void _notifyDevices() {
    _deviceStream.add(_devices.values.toList());
  }

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

  // ── 停止/释放 ──

  Future<void> stop() async {
    await sendLeave();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    await _stopBonsoir();
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
