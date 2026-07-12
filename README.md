# 就是对讲 (JiuDhi Walkie)

> 局域网跨平台对讲机应用 — 不需要服务器，不需要互联网，连上同一个 WiFi 就能通话。

[![Flutter](https://img.shields.io/badge/Flutter-3.32.4-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.8.1-blue)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-green)]()

## 功能特性

### 核心功能
- **PTT 语音对讲** — 半双工实时语音通信，按住说话，松开接听
- **设备自动发现** — UDP 广播自动发现局域网内所有设备，无需手动输入 IP
- **文字消息** — 支持收发文字消息，消息本地持久化保存
- **信号质量检测** — 基于 RTT 延迟和心跳时效的综合信号质量评估（0-4 级）
- **语音丢包检测** — 序列号追踪 + jitter buffer 排序，减少语音断续

### UI 设计
- 深色硬核对讲机风格 UI，仿实体手持对讲机
- 绿色 LCD 显示屏，实时显示设备状态
- PTT 大圆按钮，带按压动效和震动反馈
- 设备名称可自定义，在线设备列表实时更新

### 系统集成
- **后台常驻运行** — Android 前台服务，退后台不断连
- **系统通知提醒** — 通话状态通知栏显示
- **来电自动暂停** — 检测到来电/通话时自动暂停对讲，通话结束自动恢复
- **WiFi 网络变化检测** — 切换 WiFi 时自动重新发现设备
- **返回键安全退出** — 退出前发送离线通知，确保其他设备及时更新状态
- **权限拒绝引导** — 麦克风权限被拒绝时引导用户前往系统设置

### 其他
- **启动页可开关** — 设置中可控制是否显示启动页
- **国际化支持** — 中文/英文双语，自动跟随系统语言
- **音量控制** — 播放音量调节 + 静音开关
- **屏幕常亮** — 应用运行时保持屏幕常亮

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.32.4 / Dart 3.8.1 |
| 状态管理 | ChangeNotifier + AnimatedBuilder |
| 录音 | record ^6.0.0 (PCM 16-bit, 16kHz, AGC, 回声消除, 降噪) |
| 播放 | audioplayers ^6.4.0 (WAV 封装, 缓冲播放) |
| 网络 | UDP (dart:io RawDatagramSocket) |
| 设备发现 | network_info_plus + UDP 广播 |
| 网络监听 | connectivity_plus |
| 权限管理 | permission_handler |
| 本地存储 | shared_preferences |
| 通知 | flutter_local_notifications |
| 来电检测 | phone_state |
| 国际化 | flutter_localizations + intl |
| 屏幕常亮 | wakelock_plus |

## 架构

```
lib/
├── main.dart                      # 应用入口 + 启动页
├── theme/
│   └── walkie_theme.dart          # 深色主题定义
├── models/
│   ├── device.dart                # 设备模型 (含信号质量)
│   └── chat_message.dart          # 文字消息模型 (含序列化)
├── services/
│   ├── walkie_controller.dart     # 核心控制器 (状态管理 + 服务协调)
│   ├── discovery_service.dart     # UDP 设备发现 + 心跳 + WiFi 监听
│   ├── voice_transceiver.dart     # UDP 语音收发 + 丢包检测 + jitter buffer
│   ├── audio_service.dart         # 录音 + 播放 (PCM→WAV)
│   ├── background_service.dart    # Android 前台服务
│   └── audio_conflict_service.dart # 来电/音频冲突检测
├── screens/
│   ├── walkie_screen.dart         # 主界面
│   ├── settings_screen.dart       # 设置页
│   ├── message_panel.dart         # 文字消息面板
│   └── about_screen.dart          # 关于页
├── widgets/
│   ├── led_display.dart           # LCD 显示屏
│   ├── ptt_button.dart            # PTT 按钮
│   ├── device_list.dart           # 设备列表
│   └── signal_indicator.dart      # 信号指示器
├── utils/
│   ├── constants.dart             # 全局常量
│   └── wav_utils.dart             # PCM→WAV 封装
└── l10n/
    ├── app_zh.arb                 # 中文翻译
    ├── app_en.arb                 # 英文翻译
    └── app_localizations*.dart    # 生成的本地化类
```

## 通信协议

### 端口分配
| 端口 | 用途 |
|------|------|
| 45670 | UDP 设备发现 + 心跳 |
| 45671 | UDP 语音数据 + 文字消息 |

### 消息前缀
| 前缀 | 用途 |
|------|------|
| `JDHI_DISC` | 设备发现广播 |
| `JDHI_RESP` | 发现响应 |
| `JDHI_HB` | 心跳 (附带 ping 时间戳) |
| `JDHI_LEAVE` | 离线通知 |
| `JDHI_VS` | 通话开始 |
| `JDHI_VE` | 通话结束 |
| `JDHI_MSG` | 文字消息 |
| `JDHI_PNG` | Ping (延迟测量) |
| `JDHI_POG` | Pong (延迟响应) |

### 语音数据包格式
```
[4B magic "JDVD"][4B seq (uint32 LE)][PCM audio data]
```
- **magic**: `0x4A 0x44 0x56 0x44` ("JDVD")
- **seq**: 序列号，用于丢包检测和 jitter buffer 排序
- **PCM data**: 16-bit PCM, 16kHz, 单声道

## 构建

### 环境要求
- Flutter SDK >= 3.32.4
- Dart SDK >= 3.8.1
- Android Studio / VS Code
- Android: SDK 21+ (Android 5.0+)
- iOS: Xcode 15+ (iOS 12+)
- Windows: Visual Studio 2022+

### 运行
```bash
flutter pub get
flutter run
```

### 构建 APK
```bash
flutter build apk --release
```

### 构建 iOS
```bash
flutter build ios --release
```

### 构建 Windows
```bash
flutter build windows --release
```

### 构建 Web
```bash
flutter build web --release
```

## 使用方法

1. 确保所有设备连接到**同一个 WiFi 局域网**
2. 在每台设备上启动应用
3. 应用会自动发现局域网内的其他设备
4. **按住** PTT 按钮说话，**松开** 结束
5. 点击消息按钮可收发文字消息
6. 在设置中可调整音量、设备名称、后台运行等选项

## 作者

- **小聂**
- 邮箱: xiaonie@xiaonie.me
- 博客: xiaonie.me

## License

MIT
