// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '就是对讲';

  @override
  String get standby => '待机';

  @override
  String get youSpeaking => '你正在讲话';

  @override
  String peerSpeaking(String name) {
    return '$name 正在讲话';
  }

  @override
  String get releaseToEnd => '松开按钮结束通话';

  @override
  String get receivingVoice => '接收语音中';

  @override
  String onlineCount(int count) {
    return '在线 · $count 人';
  }

  @override
  String get connecting => '正在连接...';

  @override
  String get initializing => '正在初始化...';

  @override
  String readyLocalIp(String ip) {
    return '就绪 — 本机IP: $ip';
  }

  @override
  String get initFailed => '初始化失败';

  @override
  String get retry => '重试';

  @override
  String get settings => '设置';

  @override
  String get device => '设备';

  @override
  String get audio => '音频';

  @override
  String get ui => '界面';

  @override
  String get notificationBackground => '通知与后台';

  @override
  String get connection => '连接';

  @override
  String get messages => '消息';

  @override
  String get about => '关于';

  @override
  String get deviceName => '设备名称';

  @override
  String get deviceId => '设备 ID';

  @override
  String get localIp => '本机 IP';

  @override
  String get mute => '静音';

  @override
  String get splashScreen => '启动页';

  @override
  String get backgroundRunning => '后台常驻运行';

  @override
  String get systemNotification => '系统通知提醒';

  @override
  String get autoPauseOnCall => '来电自动暂停对讲';

  @override
  String get onlineDevices => '在线设备';

  @override
  String get averageSignal => '平均信号';

  @override
  String get messageCount => '消息总数';

  @override
  String get clearMessages => '清空消息记录';

  @override
  String get aboutApp => '关于本应用';

  @override
  String get version => '版本';

  @override
  String get author => '作者';

  @override
  String get setDeviceName => '设置设备名称';

  @override
  String get enterDeviceName => '输入设备名称';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get close => '关闭';

  @override
  String get volumeControl => '音量调节';

  @override
  String get muted => '已静音';

  @override
  String get volume => '音量';

  @override
  String get exitApp => '退出对讲机';

  @override
  String get exitConfirm => '确定要退出吗？退出后将断开与其他设备的连接。';

  @override
  String get exit => '退出';

  @override
  String get micPermissionDenied => '麦克风权限被拒绝';

  @override
  String get micPermissionGuide =>
      '对讲机需要麦克风权限才能进行语音通话。\n\n请前往系统设置 → 应用 → 就是对讲 → 权限，开启麦克风权限后重新打开应用。';

  @override
  String get later => '稍后';

  @override
  String get goToSettings => '去设置';

  @override
  String get signalExcellent => '极好';

  @override
  String get signalGood => '良好';

  @override
  String get signalFair => '一般';

  @override
  String get signalPoor => '较差';

  @override
  String get signalNone => '无信号';

  @override
  String get lanWalkie => '就是一个局域网对讲机';

  @override
  String get callDetected => '检测到来电，已暂停对讲';

  @override
  String get callEnded => '通话结束，对讲已恢复';

  @override
  String get deviceOffline => '设备离线';

  @override
  String deviceDiscovered(String name) {
    return '发现设备: $name';
  }

  @override
  String deviceTimeout(String name) {
    return '设备超时离线: $name';
  }

  @override
  String devicesOnline(int count) {
    return '$count 台设备在线';
  }

  @override
  String get transmitting => '正在通话...';

  @override
  String receivingFrom(String name) {
    return '$name 正在讲话';
  }

  @override
  String get webPreviewMode => 'Web 预览模式 — 网络功能不可用';

  @override
  String get micPermissionRejected => '麦克风权限被拒绝';

  @override
  String get networkDisconnected => '网络已断开';

  @override
  String get networkChanged => '检测到网络变化，重新发现设备...';

  @override
  String ipUpdated(String ip) {
    return '本机IP已更新: $ip';
  }
}
