// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JiuDhi Walkie';

  @override
  String get standby => 'Standby';

  @override
  String get youSpeaking => 'You are speaking';

  @override
  String peerSpeaking(String name) {
    return '$name is speaking';
  }

  @override
  String get releaseToEnd => 'Release to end call';

  @override
  String get receivingVoice => 'Receiving voice';

  @override
  String onlineCount(int count) {
    return 'Online · $count';
  }

  @override
  String get connecting => 'Connecting...';

  @override
  String get initializing => 'Initializing...';

  @override
  String readyLocalIp(String ip) {
    return 'Ready — Local IP: $ip';
  }

  @override
  String get initFailed => 'Initialization Failed';

  @override
  String get retry => 'Retry';

  @override
  String get settings => 'Settings';

  @override
  String get device => 'Device';

  @override
  String get audio => 'Audio';

  @override
  String get ui => 'Interface';

  @override
  String get notificationBackground => 'Notifications & Background';

  @override
  String get connection => 'Connection';

  @override
  String get messages => 'Messages';

  @override
  String get about => 'About';

  @override
  String get deviceName => 'Device Name';

  @override
  String get deviceId => 'Device ID';

  @override
  String get localIp => 'Local IP';

  @override
  String get mute => 'Mute';

  @override
  String get splashScreen => 'Splash Screen';

  @override
  String get backgroundRunning => 'Background Running';

  @override
  String get systemNotification => 'System Notifications';

  @override
  String get autoPauseOnCall => 'Auto-pause on Incoming Call';

  @override
  String get onlineDevices => 'Online Devices';

  @override
  String get averageSignal => 'Avg. Signal';

  @override
  String get messageCount => 'Total Messages';

  @override
  String get clearMessages => 'Clear Message History';

  @override
  String get aboutApp => 'About This App';

  @override
  String get version => 'Version';

  @override
  String get author => 'Author';

  @override
  String get setDeviceName => 'Set Device Name';

  @override
  String get enterDeviceName => 'Enter device name';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get close => 'Close';

  @override
  String get volumeControl => 'Volume Control';

  @override
  String get muted => 'Muted';

  @override
  String get volume => 'Volume';

  @override
  String get exitApp => 'Exit Walkie';

  @override
  String get exitConfirm =>
      'Are you sure you want to exit? This will disconnect from all devices.';

  @override
  String get exit => 'Exit';

  @override
  String get micPermissionDenied => 'Microphone Permission Denied';

  @override
  String get micPermissionGuide =>
      'Walkie requires microphone permission for voice communication.\n\nPlease go to System Settings → Apps → JiuDhi Walkie → Permissions, enable microphone permission, then reopen the app.';

  @override
  String get later => 'Later';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get signalExcellent => 'Excellent';

  @override
  String get signalGood => 'Good';

  @override
  String get signalFair => 'Fair';

  @override
  String get signalPoor => 'Poor';

  @override
  String get signalNone => 'No Signal';

  @override
  String get lanWalkie => 'A LAN Walkie-Talkie App';

  @override
  String get callDetected => 'Incoming call detected, walkie paused';

  @override
  String get callEnded => 'Call ended, walkie resumed';

  @override
  String get deviceOffline => 'Device offline';

  @override
  String deviceDiscovered(String name) {
    return 'Discovered: $name';
  }

  @override
  String deviceTimeout(String name) {
    return 'Device timed out: $name';
  }

  @override
  String devicesOnline(int count) {
    return '$count devices online';
  }

  @override
  String get transmitting => 'Transmitting...';

  @override
  String receivingFrom(String name) {
    return '$name is speaking';
  }

  @override
  String get webPreviewMode => 'Web preview mode — networking unavailable';

  @override
  String get micPermissionRejected => 'Microphone permission denied';

  @override
  String get networkDisconnected => 'Network disconnected';

  @override
  String get networkChanged => 'Network changed, rediscovering devices...';

  @override
  String ipUpdated(String ip) {
    return 'Local IP updated: $ip';
  }
}
