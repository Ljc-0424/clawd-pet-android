import 'package:shared_preferences/shared_preferences.dart';

/// 设置服务
class SettingsService {
  static const String _keyHost = 'server_host';
  static const String _keyPort = 'server_port';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyPetSize = 'pet_size';
  static const String _keyUseVpn = 'use_vpn';

  late SharedPreferences _prefs;

  /// 暴露 SharedPreferences 实例（供其他 Service 共享）
  SharedPreferences get prefs => _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 服务器地址
  String get host => _prefs.getString(_keyHost) ?? '10.151.155.66';
  set host(String value) => _prefs.setString(_keyHost, value);

  /// 服务器端口
  int get port => _prefs.getInt(_keyPort) ?? 8001;
  set port(int value) => _prefs.setInt(_keyPort, value);

  /// 自动连接
  bool get autoConnect => _prefs.getBool(_keyAutoConnect) ?? true;
  set autoConnect(bool value) => _prefs.setBool(_keyAutoConnect, value);

  /// 桌宠大小
  double get petSize => _prefs.getDouble(_keyPetSize) ?? 200.0;
  set petSize(double value) => _prefs.setDouble(_keyPetSize, value);

  /// 使用 ZeroTier VPN 路由
  bool get useVpn => _prefs.getBool(_keyUseVpn) ?? false;
  set useVpn(bool value) => _prefs.setBool(_keyUseVpn, value);
}
