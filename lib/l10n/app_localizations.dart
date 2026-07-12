import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'就是对讲'**
  String get appTitle;

  /// No description provided for @standby.
  ///
  /// In zh, this message translates to:
  /// **'待机'**
  String get standby;

  /// No description provided for @youSpeaking.
  ///
  /// In zh, this message translates to:
  /// **'你正在讲话'**
  String get youSpeaking;

  /// No description provided for @peerSpeaking.
  ///
  /// In zh, this message translates to:
  /// **'{name} 正在讲话'**
  String peerSpeaking(String name);

  /// No description provided for @releaseToEnd.
  ///
  /// In zh, this message translates to:
  /// **'松开按钮结束通话'**
  String get releaseToEnd;

  /// No description provided for @receivingVoice.
  ///
  /// In zh, this message translates to:
  /// **'接收语音中'**
  String get receivingVoice;

  /// No description provided for @onlineCount.
  ///
  /// In zh, this message translates to:
  /// **'在线 · {count} 人'**
  String onlineCount(int count);

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'正在连接...'**
  String get connecting;

  /// No description provided for @initializing.
  ///
  /// In zh, this message translates to:
  /// **'正在初始化...'**
  String get initializing;

  /// No description provided for @readyLocalIp.
  ///
  /// In zh, this message translates to:
  /// **'就绪 — 本机IP: {ip}'**
  String readyLocalIp(String ip);

  /// No description provided for @initFailed.
  ///
  /// In zh, this message translates to:
  /// **'初始化失败'**
  String get initFailed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @device.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get device;

  /// No description provided for @audio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get audio;

  /// No description provided for @ui.
  ///
  /// In zh, this message translates to:
  /// **'界面'**
  String get ui;

  /// No description provided for @notificationBackground.
  ///
  /// In zh, this message translates to:
  /// **'通知与后台'**
  String get notificationBackground;

  /// No description provided for @connection.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connection;

  /// No description provided for @messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @deviceName.
  ///
  /// In zh, this message translates to:
  /// **'设备名称'**
  String get deviceName;

  /// No description provided for @deviceId.
  ///
  /// In zh, this message translates to:
  /// **'设备 ID'**
  String get deviceId;

  /// No description provided for @localIp.
  ///
  /// In zh, this message translates to:
  /// **'本机 IP'**
  String get localIp;

  /// No description provided for @mute.
  ///
  /// In zh, this message translates to:
  /// **'静音'**
  String get mute;

  /// No description provided for @splashScreen.
  ///
  /// In zh, this message translates to:
  /// **'启动页'**
  String get splashScreen;

  /// No description provided for @backgroundRunning.
  ///
  /// In zh, this message translates to:
  /// **'后台常驻运行'**
  String get backgroundRunning;

  /// No description provided for @systemNotification.
  ///
  /// In zh, this message translates to:
  /// **'系统通知提醒'**
  String get systemNotification;

  /// No description provided for @autoPauseOnCall.
  ///
  /// In zh, this message translates to:
  /// **'来电自动暂停对讲'**
  String get autoPauseOnCall;

  /// No description provided for @onlineDevices.
  ///
  /// In zh, this message translates to:
  /// **'在线设备'**
  String get onlineDevices;

  /// No description provided for @averageSignal.
  ///
  /// In zh, this message translates to:
  /// **'平均信号'**
  String get averageSignal;

  /// No description provided for @messageCount.
  ///
  /// In zh, this message translates to:
  /// **'消息总数'**
  String get messageCount;

  /// No description provided for @clearMessages.
  ///
  /// In zh, this message translates to:
  /// **'清空消息记录'**
  String get clearMessages;

  /// No description provided for @aboutApp.
  ///
  /// In zh, this message translates to:
  /// **'关于本应用'**
  String get aboutApp;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @author.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get author;

  /// No description provided for @setDeviceName.
  ///
  /// In zh, this message translates to:
  /// **'设置设备名称'**
  String get setDeviceName;

  /// No description provided for @enterDeviceName.
  ///
  /// In zh, this message translates to:
  /// **'输入设备名称'**
  String get enterDeviceName;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @volumeControl.
  ///
  /// In zh, this message translates to:
  /// **'音量调节'**
  String get volumeControl;

  /// No description provided for @muted.
  ///
  /// In zh, this message translates to:
  /// **'已静音'**
  String get muted;

  /// No description provided for @volume.
  ///
  /// In zh, this message translates to:
  /// **'音量'**
  String get volume;

  /// No description provided for @exitApp.
  ///
  /// In zh, this message translates to:
  /// **'退出对讲机'**
  String get exitApp;

  /// No description provided for @exitConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要退出吗？退出后将断开与其他设备的连接。'**
  String get exitConfirm;

  /// No description provided for @exit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get exit;

  /// No description provided for @micPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'麦克风权限被拒绝'**
  String get micPermissionDenied;

  /// No description provided for @micPermissionGuide.
  ///
  /// In zh, this message translates to:
  /// **'对讲机需要麦克风权限才能进行语音通话。\n\n请前往系统设置 → 应用 → 就是对讲 → 权限，开启麦克风权限后重新打开应用。'**
  String get micPermissionGuide;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// No description provided for @goToSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get goToSettings;

  /// No description provided for @signalExcellent.
  ///
  /// In zh, this message translates to:
  /// **'极好'**
  String get signalExcellent;

  /// No description provided for @signalGood.
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get signalGood;

  /// No description provided for @signalFair.
  ///
  /// In zh, this message translates to:
  /// **'一般'**
  String get signalFair;

  /// No description provided for @signalPoor.
  ///
  /// In zh, this message translates to:
  /// **'较差'**
  String get signalPoor;

  /// No description provided for @signalNone.
  ///
  /// In zh, this message translates to:
  /// **'无信号'**
  String get signalNone;

  /// No description provided for @lanWalkie.
  ///
  /// In zh, this message translates to:
  /// **'就是一个局域网对讲机'**
  String get lanWalkie;

  /// No description provided for @callDetected.
  ///
  /// In zh, this message translates to:
  /// **'检测到来电，已暂停对讲'**
  String get callDetected;

  /// No description provided for @callEnded.
  ///
  /// In zh, this message translates to:
  /// **'通话结束，对讲已恢复'**
  String get callEnded;

  /// No description provided for @deviceOffline.
  ///
  /// In zh, this message translates to:
  /// **'设备离线'**
  String get deviceOffline;

  /// No description provided for @deviceDiscovered.
  ///
  /// In zh, this message translates to:
  /// **'发现设备: {name}'**
  String deviceDiscovered(String name);

  /// No description provided for @deviceTimeout.
  ///
  /// In zh, this message translates to:
  /// **'设备超时离线: {name}'**
  String deviceTimeout(String name);

  /// No description provided for @devicesOnline.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台设备在线'**
  String devicesOnline(int count);

  /// No description provided for @transmitting.
  ///
  /// In zh, this message translates to:
  /// **'正在通话...'**
  String get transmitting;

  /// No description provided for @receivingFrom.
  ///
  /// In zh, this message translates to:
  /// **'{name} 正在讲话'**
  String receivingFrom(String name);

  /// No description provided for @webPreviewMode.
  ///
  /// In zh, this message translates to:
  /// **'Web 预览模式 — 网络功能不可用'**
  String get webPreviewMode;

  /// No description provided for @micPermissionRejected.
  ///
  /// In zh, this message translates to:
  /// **'麦克风权限被拒绝'**
  String get micPermissionRejected;

  /// No description provided for @networkDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'网络已断开'**
  String get networkDisconnected;

  /// No description provided for @networkChanged.
  ///
  /// In zh, this message translates to:
  /// **'检测到网络变化，重新发现设备...'**
  String get networkChanged;

  /// No description provided for @ipUpdated.
  ///
  /// In zh, this message translates to:
  /// **'本机IP已更新: {ip}'**
  String ipUpdated(String ip);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
