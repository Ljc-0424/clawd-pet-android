import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 动画卡片定义
class AnimationCard {
  final String id;
  final String name;
  final String svgPath;
  final String category;

  const AnimationCard({
    required this.id,
    required this.name,
    required this.svgPath,
    required this.category,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'svgPath': svgPath, 'category': category};
  factory AnimationCard.fromJson(Map<String, dynamic> j) =>
      AnimationCard(id: j['id'], name: j['name'], svgPath: j['svgPath'], category: j['category']);
}

/// 状态分组定义
class StateGroup {
  final String id;
  final String name;
  final String category;
  final List<String> defaultAnimIds;

  const StateGroup({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultAnimIds,
  });
}

/// 动画配置服务
class AnimationConfigService {
  late SharedPreferences _prefs;

  static const String _configKey = 'animation_config';

  // ── 全部动画卡片 ──
  static const List<AnimationCard> allCards = [
    // 空闲
    AnimationCard(id: 'idle_follow', name: '跟随', svgPath: 'assets/svg/clawd-idle-follow.svg', category: '空闲'),
    AnimationCard(id: 'idle_living', name: '生活', svgPath: 'assets/svg/clawd-idle-living.svg', category: '空闲'),
    AnimationCard(id: 'idle_look', name: '张望', svgPath: 'assets/svg/clawd-idle-look.svg', category: '空闲'),
    AnimationCard(id: 'idle_bubble', name: '泡泡', svgPath: 'assets/svg/clawd-idle-bubble.svg', category: '空闲'),
    AnimationCard(id: 'idle_reading', name: '看书', svgPath: 'assets/svg/clawd-idle-reading.svg', category: '空闲'),
    AnimationCard(id: 'idle_wizard', name: '巫师', svgPath: 'assets/svg/clawd-working-wizard.svg', category: '空闲'),
    // 工作
    AnimationCard(id: 'working_typing', name: '打字', svgPath: 'assets/svg/clawd-working-typing.svg', category: '工作'),
    AnimationCard(id: 'working_thinking', name: '思考', svgPath: 'assets/svg/clawd-working-thinking.svg', category: '工作'),
    AnimationCard(id: 'working_ultrathink', name: '深度思考', svgPath: 'assets/svg/clawd-working-ultrathink.svg', category: '工作'),
    AnimationCard(id: 'working_building', name: '建造', svgPath: 'assets/svg/clawd-working-building.svg', category: '工作'),
    AnimationCard(id: 'working_debugger', name: '调试', svgPath: 'assets/svg/clawd-working-debugger.svg', category: '工作'),
    AnimationCard(id: 'working_typing_boss', name: '打字Boss', svgPath: 'assets/svg/clawd-working-typing-boss.svg', category: '工作'),
    AnimationCard(id: 'working_sweeping', name: '扫地', svgPath: 'assets/svg/clawd-working-sweeping.svg', category: '工作'),
    AnimationCard(id: 'working_juggling', name: '杂耍', svgPath: 'assets/svg/clawd-working-juggling.svg', category: '工作'),
    AnimationCard(id: 'working_carrying', name: '搬运', svgPath: 'assets/svg/clawd-working-carrying.svg', category: '工作'),
    // 情绪
    AnimationCard(id: 'happy', name: '开心', svgPath: 'assets/svg/clawd-happy.svg', category: '情绪'),
    AnimationCard(id: 'error', name: '错误', svgPath: 'assets/svg/clawd-error.svg', category: '情绪'),
    AnimationCard(id: 'notification', name: '通知', svgPath: 'assets/svg/clawd-notification.svg', category: '情绪'),
    AnimationCard(id: 'annoyed', name: '烦躁', svgPath: 'assets/svg/clawd-react-annoyed.svg', category: '情绪'),
    // 睡眠
    AnimationCard(id: 'yawn', name: '哈欠', svgPath: 'assets/svg/clawd-idle-yawn.svg', category: '睡眠'),
    AnimationCard(id: 'doze', name: '打盹', svgPath: 'assets/svg/clawd-idle-doze.svg', category: '睡眠'),
    AnimationCard(id: 'collapse', name: '瘫倒', svgPath: 'assets/svg/clawd-collapse-sleep.svg', category: '睡眠'),
    AnimationCard(id: 'sleeping', name: '熟睡', svgPath: 'assets/svg/clawd-sleeping.svg', category: '睡眠'),
    AnimationCard(id: 'wake', name: '醒来', svgPath: 'assets/svg/clawd-wake.svg', category: '睡眠'),
    // 反应
    AnimationCard(id: 'react_left', name: '戳左', svgPath: 'assets/svg/clawd-react-left.svg', category: '反应'),
    AnimationCard(id: 'react_right', name: '戳右', svgPath: 'assets/svg/clawd-react-right.svg', category: '反应'),
    AnimationCard(id: 'react_double', name: '双击', svgPath: 'assets/svg/clawd-react-double.svg', category: '反应'),
    AnimationCard(id: 'react_double_jump', name: '双击跳', svgPath: 'assets/svg/clawd-react-double-jump.svg', category: '反应'),
    AnimationCard(id: 'react_drag', name: '拖拽', svgPath: 'assets/svg/clawd-react-drag.svg', category: '反应'),
    // 迷你（边缘）
    AnimationCard(id: 'mini_peek', name: '探头', svgPath: 'assets/svg/clawd-mini-peek.svg', category: '迷你'),
    AnimationCard(id: 'mini_idle', name: '迷你空闲', svgPath: 'assets/svg/clawd-mini-idle.svg', category: '迷你'),
    AnimationCard(id: 'mini_sleep', name: '迷你睡眠', svgPath: 'assets/svg/clawd-mini-sleep.svg', category: '迷你'),
    AnimationCard(id: 'mini_happy', name: '迷你开心', svgPath: 'assets/svg/clawd-mini-happy.svg', category: '迷你'),
    AnimationCard(id: 'mini_typing', name: '迷你打字', svgPath: 'assets/svg/clawd-mini-typing.svg', category: '迷你'),
    AnimationCard(id: 'mini_alert', name: '迷你警告', svgPath: 'assets/svg/clawd-mini-alert.svg', category: '迷你'),
    AnimationCard(id: 'mini_crabwalk', name: '横移', svgPath: 'assets/svg/clawd-mini-crabwalk.svg', category: '迷你'),
    AnimationCard(id: 'mini_enter', name: '迷你进入', svgPath: 'assets/svg/clawd-mini-enter.svg', category: '迷你'),
    // 检测器
    AnimationCard(id: 'headphones_groove', name: '打碟', svgPath: 'assets/svg/clawd-headphones-groove.svg', category: '检测器'),
    // 经典/旧版
    AnimationCard(id: 'idle_reading_old', name: '看书(经典)', svgPath: 'assets/svg/clawd-idle-reading-old.svg', category: '经典'),
    AnimationCard(id: 'notification_retired', name: '通知(经典)', svgPath: 'assets/svg/clawd-notification-retired-2026-05-12.svg', category: '经典'),
    AnimationCard(id: 'working_building_boxes', name: '搬箱子', svgPath: 'assets/svg/clawd-working-building-boxes.svg', category: '工作'),
    AnimationCard(id: 'working_conducting', name: '指挥', svgPath: 'assets/svg/clawd-working-conducting-retired-2026-05-12.svg', category: '工作'),
    AnimationCard(id: 'working_typing_old', name: '打字(经典)', svgPath: 'assets/svg/clawd-working-typing-old.svg', category: '经典'),
  ];

  // ── 可配置的状态分组 ──
  static const List<StateGroup> stateGroups = [
    StateGroup(id: 'thinking', name: '思考', category: '工作态', defaultAnimIds: ['working_thinking']),
    StateGroup(id: 'working', name: '工作', category: '工作态', defaultAnimIds: ['working_typing']),
    StateGroup(id: 'sweeping', name: '清理', category: '工作态', defaultAnimIds: ['working_sweeping']),
    StateGroup(id: 'juggling', name: '杂耍', category: '工作态', defaultAnimIds: ['working_juggling']),
    StateGroup(id: 'carrying', name: '搬运', category: '工作态', defaultAnimIds: ['working_carrying']),
    StateGroup(id: 'attention', name: '完成', category: '信号态', defaultAnimIds: ['happy']),
    StateGroup(id: 'error', name: '错误', category: '信号态', defaultAnimIds: ['error']),
    StateGroup(id: 'notification', name: '通知', category: '信号态', defaultAnimIds: ['notification']),
    StateGroup(id: 'idle', name: '空闲轮播', category: '空闲态', defaultAnimIds: ['idle_living', 'idle_look', 'idle_bubble', 'idle_wizard', 'idle_reading']),
    StateGroup(id: 'idle_typing', name: '打字中', category: '检测器态', defaultAnimIds: ['working_typing']),
    StateGroup(id: 'idle_groove', name: '听歌', category: '检测器态', defaultAnimIds: ['headphones_groove']),
    StateGroup(id: 'charging', name: '充电', category: '检测器态', defaultAnimIds: ['happy']),
    StateGroup(id: 'low_battery', name: '低电量', category: '检测器态', defaultAnimIds: ['yawn']),
    StateGroup(id: 'network_error', name: '断网', category: '检测器态', defaultAnimIds: ['error']),
    StateGroup(id: 'call_incoming', name: '来电', category: '检测器态', defaultAnimIds: ['notification']),
    StateGroup(id: 'call_active', name: '通话中', category: '检测器态', defaultAnimIds: ['working_typing']),
    StateGroup(id: 'mini_idle', name: '迷你空闲', category: '迷你模式', defaultAnimIds: ['mini_idle']),
    StateGroup(id: 'mini_typing', name: '迷你工作', category: '迷你模式', defaultAnimIds: ['mini_typing']),
    StateGroup(id: 'mini_happy', name: '迷你开心', category: '迷你模式', defaultAnimIds: ['mini_happy']),
    StateGroup(id: 'mini_alert', name: '迷你警告', category: '迷你模式', defaultAnimIds: ['mini_alert']),
    StateGroup(id: 'mini_sleep', name: '迷你睡眠', category: '迷你模式', defaultAnimIds: ['mini_sleep']),
    StateGroup(id: 'drag', name: '拖拽', category: '反应', defaultAnimIds: ['react_drag']),
    StateGroup(id: 'clickLeft', name: '戳左', category: '反应', defaultAnimIds: ['react_left']),
    StateGroup(id: 'clickRight', name: '戳右', category: '反应', defaultAnimIds: ['react_right']),
    StateGroup(id: 'double', name: '双击', category: '反应', defaultAnimIds: ['react_double', 'react_double_jump']),
    StateGroup(id: 'edge_peek', name: '边缘探头', category: '边缘', defaultAnimIds: ['mini_peek']),
  ];

  // 排除的分类（独立版可设置为 {'工作态'}）
  static Set<String> excludedCategories = {};

  // 过滤后的状态分组
  static List<StateGroup> get filteredStateGroups =>
      stateGroups.where((g) => !excludedCategories.contains(g.category)).toList();

  // id → AnimationCard 快速查找
  static final Map<String, AnimationCard> cardById = {
    for (var c in allCards) c.id: c,
  };

  // ── 运行时配置：stateId → animId 列表 ──
  Map<String, List<String>> _config = {};

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _loadConfig();
  }

  void _loadConfig() {
    final json = _prefs.getString(_configKey);
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        _config = map.map((k, v) => MapEntry(k, List<String>.from(v as List)));
      } catch (_) {
        _config = {};
      }
    }
    // 填充默认值
    for (var group in stateGroups) {
      _config.putIfAbsent(group.id, () => List.from(group.defaultAnimIds));
    }
  }

  /// 获取某个状态的动画 ID 列表
  List<String> getAnimIds(String stateId) =>
      _config[stateId] ?? stateGroups.firstWhere((g) => g.id == stateId, orElse: () => stateGroups.first).defaultAnimIds;

  /// 添加动画到状态
  void addAnim(String stateId, String animId) {
    final list = _config[stateId] ?? [];
    if (!list.contains(animId)) {
      list.add(animId);
      _config[stateId] = list;
      _save();
    }
  }

  /// 从状态移除动画
  void removeAnim(String stateId, String animId) {
    final list = _config[stateId];
    if (list != null && list.length > 1) {
      list.remove(animId);
      _config[stateId] = list;
      _save();
    }
  }

  /// 重置某个状态为默认
  void resetState(String stateId) {
    final group = stateGroups.firstWhere((g) => g.id == stateId);
    _config[stateId] = List.from(group.defaultAnimIds);
    _save();
  }

  /// 重置全部
  void resetAll() {
    for (var group in stateGroups) {
      _config[group.id] = List.from(group.defaultAnimIds);
    }
    _save();
  }

  /// 导出完整配置为 JSON（给 Kotlin 端读取）
  String exportJson() => jsonEncode(_config);

  void _save() {
    _prefs.setString(_configKey, jsonEncode(_config));
  }
}
