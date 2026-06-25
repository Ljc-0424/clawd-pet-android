/// 状态事件模型
class StateEvent {
  final String event;
  final Map<String, dynamic> data;

  StateEvent({
    required this.event,
    this.data = const {},
  });

  factory StateEvent.fromJson(Map<String, dynamic> json) {
    return StateEvent(
      event: json['event'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 获取显示文本
  String get displayText {
    switch (event) {
      case 'idle':
        return '空闲';
      case 'user_message':
        return '收到消息';
      case 'thinking':
        return '思考中';
      case 'tool_call':
        return '工作中';
      case 'success':
        return '完成';
      case 'error':
        return '错误';
      default:
        return event;
    }
  }

  /// 获取图标
  String get icon {
    switch (event) {
      case 'idle':
        return '🦀';
      case 'user_message':
        return '👀';
      case 'thinking':
        return '🤔';
      case 'tool_call':
        return '🔧';
      case 'success':
        return '🎉';
      case 'error':
        return '❌';
      default:
        return '🦀';
    }
  }
}
