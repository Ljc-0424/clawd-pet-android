import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/state_event.dart';

/// WebSocket 服务（使用 dart:io 原生 WebSocket）
class WebSocketService {
  WebSocket? _ws;
  final StreamController<StateEvent> _eventController =
      StreamController<StateEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  String _serverHost = 'localhost';
  int _serverPort = 8001;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  StreamSubscription? _streamSub;

  Stream<StateEvent> get eventStream => _eventController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  void setServer(String host, int port) {
    _serverHost = host;
    _serverPort = port;
  }

  void _setConnected(bool value) {
    if (_isConnected != value) {
      _isConnected = value;
      _connectionController.add(value);
    }
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _streamSub?.cancel();
    _streamSub = null;
    _ws?.close();
    _ws = null;
  }

  Future<void> connect() async {
    if (_isConnecting) return;
    _isConnecting = true;
    _manualDisconnect = false;

    try {
      _cleanup();
      _setConnected(false);

      final url = 'ws://$_serverHost:$_serverPort/ws';
      print('>>> 连接 WebSocket: $url');

      // 使用 dart:io 原生 WebSocket，支持自定义超时
      final ws = await WebSocket.connect(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('>>> 连接超时');
          throw TimeoutException('WebSocket 连接超时');
        },
      );

      // 连接成功
      _cleanup();
      _ws = ws;
      _setConnected(true);
      _isConnecting = false;
      print('>>> WebSocket 已连接');

      // 监听消息
      _streamSub = _ws!.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            final event = StateEvent.fromJson(data);
            if (event.event == 'pong') return;
            print('>>> WS 收到: event=${event.event}');
            _eventController.add(event);
          } catch (e) {
            print('>>> WS 解析失败: $e');
          }
        },
        onError: (error) {
          if (_manualDisconnect) return;
          print('>>> WebSocket 错误: $error');
          _setConnected(false);
          _scheduleReconnect();
        },
        onDone: () {
          if (_manualDisconnect) return;
          print('>>> WebSocket 断开');
          _setConnected(false);
          _scheduleReconnect();
        },
      );

      _startPing();
    } catch (e) {
      print('>>> 连接失败: $e');
      _isConnecting = false;
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print('>>> 尝试重连...');
      connect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      sendMessage({'event': 'ping'});
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    _ws?.add(jsonEncode(message));
  }

  void sendUserMessage(String content) {
    sendMessage({
      'event': 'user_message',
      'data': {'content': content}
    });
  }

  void disconnect() {
    _manualDisconnect = true;
    _cleanup();
    _setConnected(false);
  }

  void stopReconnect() {
    _manualDisconnect = true;
    _cleanup();
    _setConnected(false);
  }

  void dispose() {
    _cleanup();
    _eventController.close();
    _connectionController.close();
  }
}
