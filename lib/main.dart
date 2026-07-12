import 'package:flutter/material.dart';

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
      home: const _AppLoader(),
    );
  }
}

/// 应用加载器 — 初始化控制器后进入主界面
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  WalkieController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final deviceId = await WalkieController.loadDeviceId();
    final savedName = await WalkieController.loadDeviceName();
    final deviceName = savedName.isNotEmpty
        ? savedName
        : '对讲机-${deviceId.substring(0, 4).toUpperCase()}';

    final controller = WalkieController(deviceId: deviceId, deviceName: deviceName);
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Scaffold(
        backgroundColor: WalkieTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: WalkieTheme.accent),
        ),
      );
    }

    return WalkieScreen(controller: _controller!);
  }
}
