import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:jiudhiduijiang/l10n/app_localizations.dart';
import 'package:jiudhiduijiang/theme/walkie_theme.dart';
import 'package:jiudhiduijiang/services/walkie_controller.dart';
import 'package:jiudhiduijiang/screens/walkie_screen.dart';

void main() {
  runApp(const JiudhiDuiJiangApp());
}

class JiudhiDuiJiangApp extends StatelessWidget {
  const JiudhiDuiJiangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '就是对讲',
      debugShowCheckedModeBanner: false,
      theme: WalkieTheme.themeData,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      home: const _AppLoader(),
    );
  }
}

/// 应用加载器 — 根据设置决定是否显示启动页
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader>
    with SingleTickerProviderStateMixin {
  WalkieController? _controller;
  bool _splashEnabled = true;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    _initApp();
  }

  Future<void> _initApp() async {
    // 先读取启动页开关设置
    _splashEnabled = await WalkieController.loadSplashEnabled();

    final deviceId = await WalkieController.loadDeviceId();
    final savedName = await WalkieController.loadDeviceName();
    final deviceName = savedName.isNotEmpty
        ? savedName
        : '对讲机-${deviceId.substring(0, 4).toUpperCase()}';

    final controller = WalkieController(deviceId: deviceId, deviceName: deviceName);

    // 启动页开启时给动画展示时间；关闭时直接进入
    if (_splashEnabled) {
      _logoController.forward();
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (mounted) setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      // 启动页关闭时显示极简加载
      if (!_splashEnabled) {
        return Scaffold(
          backgroundColor: WalkieTheme.background,
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: WalkieTheme.accent.withValues(alpha: 0.6),
                strokeWidth: 2,
              ),
            ),
          ),
        );
      }
      return _buildSplash();
    }

    return WalkieScreen(controller: _controller!);
  }

  /// 启动页 — 使用用户提供的启动图
  Widget _buildSplash() {
    return Scaffold(
      backgroundColor: WalkieTheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 用户提供的启动图
            Image.asset(
              'assets/splash/splash.png',
              fit: BoxFit.cover,
            ),
            // 底部渐变遮罩 + 加载指示器
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 60),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      WalkieTheme.background.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: WalkieTheme.accent.withValues(alpha: 0.8),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
