import 'dart:async';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state/phone_state.dart';

/// 音频冲突检测 — 来电/通话时自动暂停对讲
class AudioConflictService {
  StreamSubscription? _subscription;
  bool _wasTransmitting = false;
  bool _wasReceiving = false;

  /// 冲突回调 — 当检测到来电/通话时调用
  Function()? onConflictStart;

  /// 冲突结束回调 — 通话结束后调用
  Function()? onConflictEnd;

  bool _isActive = false;
  bool get isActive => _isActive;

  /// 启动监听
  Future<void> start() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // 请求电话状态权限
      if (Platform.isAndroid) {
        final status = await Permission.phone.request();
        if (!status.isGranted) return;
      }

      _subscription = PhoneState.stream.listen((event) {
        _handlePhoneState(event);
      });
    } catch (_) {
      // 静默处理 — 某些平台可能不支持
    }
  }

  void _handlePhoneState(PhoneState state) {
    final status = state.status;

    if (status == PhoneStateStatus.CALL_INCOMING ||
        status == PhoneStateStatus.CALL_STARTED) {
      // 来电或通话开始 → 暂停对讲
      if (!_isActive) {
        _isActive = true;
        onConflictStart?.call();
      }
    } else if (status == PhoneStateStatus.CALL_ENDED ||
               status == PhoneStateStatus.NOTHING) {
      // 通话结束 → 恢复对讲
      if (_isActive) {
        _isActive = false;
        onConflictEnd?.call();
      }
    }
  }

  /// 保存当前状态（在冲突开始前调用）
  void saveState({required bool transmitting, required bool receiving}) {
    _wasTransmitting = transmitting;
    _wasReceiving = receiving;
  }

  /// 获取冲突前的状态
  bool get wasTransmitting => _wasTransmitting;
  bool get wasReceiving => _wasReceiving;

  /// 停止监听
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _isActive = false;
  }

  void dispose() {
    stop();
  }
}
