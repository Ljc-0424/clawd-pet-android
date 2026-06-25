import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/settings_screen.dart';
import 'screens/animation_config_screen.dart';
import 'screens/about_screen.dart';
import 'services/websocket_service.dart';
import 'services/settings_service.dart';
import 'services/animation_config_service.dart';
import 'models/state_event.dart';
import 'widgets/svg_pet_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService();
  await settings.init();
  final animConfig = AnimationConfigService();
  await animConfig.init(settings.prefs);
  runApp(ClawdPetApp(settings: settings, animConfig: animConfig));
}

class ClawdPetApp extends StatelessWidget {
  final SettingsService settings;
  final AnimationConfigService animConfig;
  const ClawdPetApp({Key? key, required this.settings, required this.animConfig}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clawd Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0d1117),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0d1117), elevation: 0),
      ),
      home: HomeScreen(settings: settings, animConfig: animConfig),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final SettingsService settings;
  final AnimationConfigService animConfig;
  const HomeScreen({Key? key, required this.settings, required this.animConfig}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.clawd_pet/floating');
  final WebSocketService _wsService = WebSocketService();
  final GlobalKey<SvgPetWidgetState> _petKey = GlobalKey();
  StateEvent? _currentEvent;
  bool _isConnected = false;
  bool _showOverlay = false;
  StreamSubscription? _connectionSub;
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWebSocket();
    // 首次启动提醒开启权限
    _checkPermissions();
  }

  void _checkPermissions() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final result = await platform.invokeMethod('checkPermissions');
      final overlayOk = result['overlay'] == true;
      final accessibilityOk = result['accessibility'] == true;
      if (overlayOk && accessibilityOk) return; // 都已开启，不弹窗
      if (!mounted) return;
      _showPermissionDialog(overlayOk, accessibilityOk);
    } catch (_) {
      // 检查失败时仍然弹窗引导
      if (mounted) _showPermissionDialog(false, false);
    }
  }

  void _showPermissionDialog(bool overlayOk, bool accessibilityOk) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要开启权限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!overlayOk) ...[
              Row(children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('悬浮窗权限未开启', style: TextStyle(color: Colors.white70))),
              ]),
              const SizedBox(height: 4),
              const Text('用于显示桌面宠物', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 12),
            ],
            if (!accessibilityOk) ...[
              Row(children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                const Expanded(child: Text('无障碍服务未开启', style: TextStyle(color: Colors.white70))),
              ]),
              const SizedBox(height: 4),
              const Text('用于打字检测和通知检测', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
          if (!overlayOk)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                platform.invokeMethod('openOverlaySettings');
              },
              child: const Text('悬浮窗权限'),
            ),
          if (!accessibilityOk)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                platform.invokeMethod('openAccessibilitySettings');
              },
              child: const Text('无障碍服务'),
            ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台时重新检查权限（用户可能刚从设置页回来）
      _checkPermissions();
      if (!_isConnected) {
        print('>>> App 回到前台，尝试重连...');
        _wsService.connect();
      }
    }
  }

  Future<void> _initWebSocket() async {
    _connectionSub?.cancel();
    _eventSub?.cancel();

    _wsService.setServer(widget.settings.host, widget.settings.port);

    _connectionSub = _wsService.connectionStream.listen((connected) {
      setState(() => _isConnected = connected);
    });

    _eventSub = _wsService.eventStream.listen((event) {
      setState(() => _currentEvent = event);
      // 预览桌宠同步状态
      _petKey.currentState?.setStateFromEvent(event.event);
      // 悬浮窗同步状态
      if (_showOverlay) {
        _updateOverlayState(event.event);
      }
    });

    if (widget.settings.autoConnect) {
      if (widget.settings.useVpn) {
        // 延迟绑定 VPN，等 ZeroTier 就绪
        Future.delayed(const Duration(seconds: 3), () async {
          if (mounted) { await _bindVpn(); _wsService.connect(); }
        });
      } else {
        _wsService.connect();
      }
    }
  }

  /// 绑定 ZeroTier VPN 网络
  Future<void> _bindVpn() async {
    try {
      final ok = await platform.invokeMethod('bindVpnNetwork');
      print('>>> VPN 绑定: $ok');
    } catch (e) {
      print('>>> VPN 绑定失败: $e');
    }
  }

  Future<void> _updateOverlayState(String state) async {
    try {
      await platform.invokeMethod('updateState', state);
    } catch (e) {
      print('更新悬浮窗状态失败: $e');
    }
  }

  Future<void> _toggleOverlay() async {
    try {
      if (_showOverlay) {
        await platform.invokeMethod('hideOverlay');
        setState(() => _showOverlay = false);
        _showSnackBar('悬浮窗已关闭');
      } else {
        await platform.invokeMethod('showOverlay', {
          'host': widget.settings.host,
          'port': widget.settings.port,
        });
        await platform.invokeMethod('resizeOverlay', widget.settings.petSize.toInt());
        _syncAnimConfig(); // 同步动画配置
        setState(() => _showOverlay = true);
        _showSnackBar('悬浮窗已显示');
      }
    } catch (e) {
      _showSnackBar('错误: $e');
    }
  }

  /// 同步动画配置到 Kotlin 悬浮窗
  void _syncAnimConfig() {
    try {
      platform.invokeMethod('updateAnimConfig', widget.animConfig.exportJson());
    } catch (_) {}
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// 测试按钮 → 控制预览桌宠
  Widget _testBtn(String label, String state, Color color) {
    return ElevatedButton(
      onPressed: () {
        _petKey.currentState?.forceState(state);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.3),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: const TextStyle(color: Color(0xFF58a6ff), fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _eventSub?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clawd Pet', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.green : Colors.red),
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: '动画配置',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimationConfigScreen(configService: widget.animConfig),
                ),
              );
              // 配置修改后同步到悬浮窗
              _syncAnimConfig();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings)),
              );
              if (result == true) {
                setState(() {
                  _wsService.disconnect();
                  _initWebSocket();
                });
                if (_showOverlay) {
                  platform.invokeMethod('resizeOverlay', widget.settings.petSize.toInt());
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 固定区域：预览 + 按钮
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SvgPetWidget(key: _petKey, size: 200),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                    onPressed: () async {
                      if (_isConnected) {
                        _wsService.disconnect();
                      } else {
                        if (widget.settings.useVpn) await _bindVpn();
                        _wsService.connect();
                      }
                    },
                    icon: Icon(_isConnected ? Icons.stop : Icons.play_arrow),
                    label: Text(_isConnected ? '断开' : '连接'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: _isConnected ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _toggleOverlay,
                    icon: Icon(_showOverlay ? Icons.visibility_off : Icons.visibility),
                    label: Text(_showOverlay ? '隐藏' : '悬浮窗'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: _showOverlay ? Colors.orange : Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 状态信息
              Card(
                color: const Color(0xFF161b22),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${widget.settings.host}:${widget.settings.port}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 12),
                      Text(_isConnected ? '已连接' : '未连接',
                          style: TextStyle(color: _isConnected ? Colors.green : Colors.red, fontSize: 12)),
                      if (_currentEvent != null) ...[
                        const SizedBox(width: 12),
                        Text(_currentEvent!.displayText,
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
          // 可滚动区域：动画配置 + 测试按钮
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: [
              const SizedBox(height: 8),
              // 动画配置引导
              Card(
                color: const Color(0xFF161b22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF58a6ff), width: 0.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AnimationConfigScreen(configService: widget.animConfig)),
                  ).then((_) => _syncAnimConfig()),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.palette, color: Color(0xFF58a6ff), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('自定义动画', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                '为每个状态自由搭配喜欢的动画组合',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 测试动画按钮
              const Text('测试动画预览', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _sectionTitle('工作态'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('思考', 'thinking', Colors.orange),
                _testBtn('深度思考', 'ultrathink', Colors.deepOrange),
                _testBtn('工作', 'working', Colors.blue),
                _testBtn('调试', 'working_debugger', Colors.cyan),
                _testBtn('建造', 'working_building', Colors.amber),
                _testBtn('打字Boss', 'working_typing_boss', Colors.indigo),
                _testBtn('清理', 'sweeping', Colors.brown),
                _testBtn('杂耍', 'juggling', Colors.purple),
                _testBtn('搬运', 'carrying', Colors.teal),
                _testBtn('搬箱子', 'working_building_boxes', Colors.brown),
                _testBtn('指挥', 'working_conducting', Colors.amber),
                _testBtn('打字(经典)', 'working_typing_old', Colors.blueGrey),
              ]),
              const SizedBox(height: 10),
              _sectionTitle('信号态'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('完成', 'attention', Colors.green),
                _testBtn('错误', 'error', Colors.red),
                _testBtn('通知', 'notification', Colors.lime),
                _testBtn('充电', 'charging', Colors.yellow),
                _testBtn('低电量', 'low_battery', Colors.deepOrange),
              ]),
              const SizedBox(height: 10),
              _sectionTitle('空闲态'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('跟随', 'idle', Colors.grey),
                _testBtn('生活', 'idle_living', Colors.green),
                _testBtn('张望', 'idle_look', Colors.blueGrey),
                _testBtn('泡泡', 'idle_bubble', Colors.lightBlue),
                _testBtn('看书', 'idle_reading', Colors.brown),
                _testBtn('看书(经典)', 'idle_reading_old', Colors.brown),
                _testBtn('巫师', 'idle_wizard', Colors.deepPurple),
                _testBtn('打碟', 'idle_groove', Colors.purple),
                _testBtn('打字', 'idle_typing', Colors.blue),
              ]),
              const SizedBox(height: 10),
              _sectionTitle('反应动画'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('戳左', 'clickLeft', Colors.cyan),
                _testBtn('戳右', 'clickRight', Colors.cyan),
                _testBtn('双击', 'double', Colors.pink),
                _testBtn('烦躁', 'annoyed', Colors.deepOrange),
                _testBtn('拖拽', 'drag', Colors.purple),
              ]),
              const SizedBox(height: 10),
              _sectionTitle('睡眠态'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('哈欠', 'yawning', Colors.teal),
                _testBtn('犯困', 'dozing', Colors.indigo),
                _testBtn('瘫倒', 'collapsing', Colors.indigo),
                _testBtn('熟睡', 'sleeping', Colors.blueGrey),
                _testBtn('唤醒', 'waking', Colors.amber),
              ]),
              const SizedBox(height: 10),
              _sectionTitle('迷你模式（边缘）'),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                _testBtn('迷你空闲', 'mini_idle', Colors.grey),
                _testBtn('迷你工作', 'mini_typing', Colors.blue),
                _testBtn('迷你开心', 'mini_happy', Colors.green),
                _testBtn('迷你警告', 'mini_alert', Colors.red),
                _testBtn('迷你睡眠', 'mini_sleep', Colors.blueGrey),
                _testBtn('探头', 'mini_peek', Colors.amber),
                _testBtn('进入', 'mini_enter', Colors.teal),
                _testBtn('横移', 'mini_crabwalk', Colors.purple),
              ]),
              const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
