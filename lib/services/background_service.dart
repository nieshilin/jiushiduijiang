import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 后台服务 — Android 前台服务保活 + 系统通知
class BackgroundService {
  static const _channel = MethodChannel('com.jiudhi.jiudhiduijiang/background');

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 启动前台服务
  Future<void> startService({
    String title = '就是对讲',
    String content = '对讲机运行中',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService', {
        'title': title,
        'content': content,
      });
      _isRunning = true;
    } catch (e) {
      // 静默处理 — 非 Android 平台或服务未注册
    }
  }

  /// 更新通知内容
  Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    if (!Platform.isAndroid || !_isRunning) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'content': content,
      });
    } catch (_) {}
  }

  /// 停止前台服务
  Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
      _isRunning = false;
    } catch (_) {}
  }

  /// 请求通知权限 (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 请求忽略电池优化
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimization');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
