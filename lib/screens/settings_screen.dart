import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  final SettingsService settings;

  const SettingsScreen({Key? key, required this.settings}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late bool _autoConnect;
  late bool _useVpn;
  late double _petSize;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.settings.host);
    _portController =
        TextEditingController(text: widget.settings.port.toString());
    _autoConnect = widget.settings.autoConnect;
    _useVpn = widget.settings.useVpn;
    _petSize = widget.settings.petSize;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    widget.settings.host = _hostController.text;
    widget.settings.port = int.tryParse(_portController.text) ?? 8001;
    widget.settings.autoConnect = _autoConnect;
    widget.settings.useVpn = _useVpn;
    widget.settings.petSize = _petSize;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, color: Colors.green),
            label: const Text('保存', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 连接设置
          const Text(
            '连接设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: '服务器地址',
              hintText: '例如：192.168.1.100 或 ZeroTier IP（10.x.x.x）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.computer),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '8001',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('自动连接'),
            subtitle: const Text('启动时自动连接到服务器'),
            value: _autoConnect,
            onChanged: (value) {
              setState(() { _autoConnect = value; });
            },
          ),
          SwitchListTile(
            title: const Text('ZeroTier VPN 路由'),
            subtitle: const Text('非局域网时启用，强制流量走 VPN 通道'),
            value: _useVpn,
            secondary: const Icon(Icons.vpn_lock, color: Color(0xFF58a6ff)),
            onChanged: (value) {
              setState(() { _useVpn = value; });
            },
          ),

          const Divider(height: 32),

          // 桌宠设置
          const Text(
            '悬浮窗设置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('悬浮窗大小: ${_petSize.toInt()}dp'),
            if (_petSize.toInt() != 200) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { setState(() => _petSize = 200); MethodChannel('com.example.clawd_pet/floating').invokeMethod('resizeOverlay', 200); },
                child: const Text('推荐: 200dp', style: TextStyle(color: Color(0xFF58a6ff), fontSize: 12)),
              ),
            ],
          ]),
          Slider(
            value: _petSize,
            min: 50,
            max: 600,
            divisions: 11,
            label: '${_petSize.toInt()}dp',
            onChanged: (value) {
              setState(() {
                _petSize = value;
              });
              // 即时保存并调整悬浮窗大小
              widget.settings.petSize = value;
              MethodChannel('com.example.clawd_pet/floating')
                  .invokeMethod('resizeOverlay', value.toInt());
            },
          ),

          const Divider(height: 32),

          // 网络说明
          const Text(
            '网络配置说明',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本地网络：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('填写电脑的局域网 IP（如 192.168.1.100）'),
                  SizedBox(height: 8),
                  Text(
                    'ZeroTier（推荐）：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('1. 电脑和手机都安装 ZeroTier'),
                  Text('2. 加入同一网络（记住 Network ID）'),
                  Text('3. 在 ZeroTier 管理后台授权设备'),
                  Text('4. 填写电脑的 ZeroTier IP（10.x.x.x）'),
                  SizedBox(height: 8),
                  Text(
                    '端口：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('默认 8001，与 State Bridge 配置一致'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
