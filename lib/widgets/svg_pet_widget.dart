import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// SVG 桌宠 Widget - 主页预览用
class SvgPetWidget extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const SvgPetWidget({Key? key, this.size = 100, this.onTap}) : super(key: key);

  @override
  SvgPetWidgetState createState() => SvgPetWidgetState();
}

class SvgPetWidgetState extends State<SvgPetWidget> {
  late WebViewController _controller;
  String _currentState = 'idle';
  bool _loaded = false;

  // 状态 → SVG 文件映射
  static const Map<String, String> _svgAssets = {
    // 空闲
    'idle': 'assets/svg/clawd-idle-follow.svg',
    'idle_look': 'assets/svg/clawd-idle-look.svg',
    'idle_bubble': 'assets/svg/clawd-idle-bubble.svg',
    'idle_reading': 'assets/svg/clawd-idle-reading.svg',
    'idle_living': 'assets/svg/clawd-idle-living.svg',
    'idle_groove': 'assets/svg/clawd-headphones-groove.svg',
    'idle_typing': 'assets/svg/clawd-working-typing.svg',
    'idle_juggling': 'assets/svg/clawd-working-juggling.svg',
    'idle_wizard': 'assets/svg/clawd-working-wizard.svg',
    // 工作
    'thinking': 'assets/svg/clawd-working-thinking.svg',
    'ultrathink': 'assets/svg/clawd-working-ultrathink.svg',
    'working': 'assets/svg/clawd-working-typing.svg',
    'working_building': 'assets/svg/clawd-working-building.svg',
    'working_carrying': 'assets/svg/clawd-working-carrying.svg',
    'working_sweeping': 'assets/svg/clawd-working-sweeping.svg',
    'working_debugger': 'assets/svg/clawd-working-debugger.svg',
    'working_typing_boss': 'assets/svg/clawd-working-typing-boss.svg',
    'working_building_boxes': 'assets/svg/clawd-working-building-boxes.svg',
    'working_conducting': 'assets/svg/clawd-working-conducting-retired-2026-05-12.svg',
    'working_typing_old': 'assets/svg/clawd-working-typing-old.svg',
    // 信号
    'attention': 'assets/svg/clawd-happy.svg',
    'error': 'assets/svg/clawd-error.svg',
    'notification': 'assets/svg/clawd-notification.svg',
    'notification_retired': 'assets/svg/clawd-notification-retired-2026-05-12.svg',
    'charging': 'assets/svg/clawd-happy.svg',
    'low_battery': 'assets/svg/clawd-idle-yawn.svg',
    'network_error': 'assets/svg/clawd-error.svg',
    'call_incoming': 'assets/svg/clawd-notification.svg',
    'call_active': 'assets/svg/clawd-working-typing.svg',
    // 睡眠
    'yawning': 'assets/svg/clawd-idle-yawn.svg',
    'dozing': 'assets/svg/clawd-idle-doze.svg',
    'collapsing': 'assets/svg/clawd-collapse-sleep.svg',
    'sleeping': 'assets/svg/clawd-sleeping.svg',
    'waking': 'assets/svg/clawd-wake.svg',
    // 反应
    'drag': 'assets/svg/clawd-react-drag.svg',
    'clickLeft': 'assets/svg/clawd-react-left.svg',
    'clickRight': 'assets/svg/clawd-react-right.svg',
    'annoyed': 'assets/svg/clawd-react-annoyed.svg',
    'double': 'assets/svg/clawd-react-double.svg',
    'double_jump': 'assets/svg/clawd-react-double-jump.svg',
    'sweeping': 'assets/svg/clawd-working-sweeping.svg',
    'juggling': 'assets/svg/clawd-working-juggling.svg',
    'carrying': 'assets/svg/clawd-working-carrying.svg',
    // 迷你
    'mini_idle': 'assets/svg/clawd-mini-idle.svg',
    'mini_peek': 'assets/svg/clawd-mini-peek.svg',
    'mini_happy': 'assets/svg/clawd-mini-happy.svg',
    'mini_alert': 'assets/svg/clawd-mini-alert.svg',
    'mini_sleep': 'assets/svg/clawd-mini-sleep.svg',
    'mini_typing': 'assets/svg/clawd-mini-typing.svg',
    'mini_enter': 'assets/svg/clawd-mini-enter.svg',
    'mini_crabwalk': 'assets/svg/clawd-mini-crabwalk.svg',
    'mini_enter_sleep': 'assets/svg/clawd-mini-enter-sleep.svg',
    // 经典
    'idle_reading_old': 'assets/svg/clawd-idle-reading-old.svg',
    'notification_old': 'assets/svg/clawd-notification-retired-2026-05-12.svg',
  };

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _loaded = true,
      ));
    _loadSvg('idle');
  }

  Future<void> _loadSvg(String state) async {
    final assetPath = _svgAssets[state] ?? _svgAssets['idle']!;
    try {
      final svgContent = await rootBundle.loadString(assetPath);
      final html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; }
            body {
              background: transparent;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              overflow: hidden;
            }
            svg { width: 100%; height: 100%; max-width: ${widget.size}px; max-height: ${widget.size}px; }
          </style>
        </head>
        <body>
          $svgContent
        </body>
      </html>
      ''';
      _controller.loadHtmlString(html);
    } catch (e) {
      print('加载 SVG 失败: $assetPath - $e');
    }
  }

  /// 从 OpenClaw 接收状态（悬浮窗用）
  void setStateFromEvent(String event) {
    final stateMap = {
      'thinking': 'thinking',
      'tool_call': 'working',
      'success': 'attention',
      'error': 'error',
      'idle': 'idle',
    };
    final newState = stateMap[event] ?? 'idle';
    if (newState != _currentState) {
      setState(() => _currentState = newState);
      _loadSvg(newState);
    }
  }

  /// 测试按钮直接设置状态（预览用）
  void forceState(String state) {
    setState(() => _currentState = state);
    _loadSvg(state);
  }

  /// 直接通过 SVG 资源路径预览（动画配置页用）
  void forceSvgPath(String assetPath) {
    _loadSvgByPath(assetPath);
  }

  Future<void> _loadSvgByPath(String assetPath) async {
    try {
      final svgContent = await rootBundle.loadString(assetPath);
      final html = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            * { margin: 0; padding: 0; }
            body {
              background: transparent;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              overflow: hidden;
            }
            svg { width: 100%; height: 100%; max-width: ${widget.size}px; max-height: ${widget.size}px; }
          </style>
        </head>
        <body>
          $svgContent
        </body>
      </html>
      ''';
      _controller.loadHtmlString(html);
    } catch (e) {
      print('加载 SVG 失败: $assetPath - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
