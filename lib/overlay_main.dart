// 注意：此文件当前未被使用。
// App 实际使用的是原生 Android 方案（FloatingPetService + WindowManager + WebView），
// 而非 flutter_overlay_window 插件方案。
// 此文件保留作为备选方案参考。
// 如果要切换到插件方案，需要：
//   1. 在 AndroidManifest.xml 中配置 OverlayService（已有）
//   2. 在 main.dart 中调用 FlutterOverlayWindow.showOverlay()
//   3. 通过 FlutterOverlayWindow.shareData() 发送状态更新

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:webview_flutter/webview_flutter.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayPet(),
  ));
}

class OverlayPet extends StatefulWidget {
  const OverlayPet({Key? key}) : super(key: key);

  @override
  State<OverlayPet> createState() => _OverlayPetState();
}

class _OverlayPetState extends State<OverlayPet> {
  late WebViewController _controller;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _listenForUpdates();
  }

  Future<void> _initWebView() async {
    final html = await rootBundle.loadString('assets/stable-pet.html');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loaded = true),
      ))
      ..loadRequest(Uri.dataFromString(html,
          mimeType: 'text/html', encoding: Encoding.getByName('utf-8')!));
  }

  void _listenForUpdates() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data.containsKey('event') && _loaded) {
        _controller.runJavaScript('setState("${data['event']}")');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.withOpacity(0.5), // 临时半透明背景
      body: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.red, // 临时红色背景
            borderRadius: BorderRadius.circular(60),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ),
    );
  }
}
