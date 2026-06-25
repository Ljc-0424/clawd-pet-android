import 'package:flutter/material.dart';
import '../services/animation_config_service.dart';
import '../widgets/svg_pet_widget.dart';

/// 动画配置页面
class AnimationConfigScreen extends StatefulWidget {
  final AnimationConfigService configService;
  const AnimationConfigScreen({Key? key, required this.configService}) : super(key: key);

  @override
  State<AnimationConfigScreen> createState() => _AnimationConfigScreenState();
}

class _AnimationConfigScreenState extends State<AnimationConfigScreen> {
  final GlobalKey<SvgPetWidgetState> _previewKey = GlobalKey();
  String _selectedCategory = '全部';
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = ['全部', ...{for (var c in AnimationConfigService.allCards) c.category}];
  }

  List<AnimationCard> get _filteredCards {
    if (_selectedCategory == '全部') return AnimationConfigService.allCards;
    return AnimationConfigService.allCards.where((c) => c.category == _selectedCategory).toList();
  }

  void _previewAnim(AnimationCard card) {
    _previewKey.currentState?.forceSvgPath(card.svgPath);
  }

  void _showAddDialog(String stateId, String stateName) {
    showDialog(
      context: context,
      builder: (ctx) => _AddAnimDialog(
        stateId: stateId,
        stateName: stateName,
        configService: widget.configService,
        onAdded: () => setState(() {}),
        onPreview: _previewAnim,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        title: const Text('动画配置', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0d1117),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '全部重置',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF161b22),
                  title: const Text('重置全部动画', style: TextStyle(color: Colors.white)),
                  content: const Text('确定恢复所有状态的默认动画？', style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () { widget.configService.resetAll(); setState(() {}); Navigator.pop(ctx); },
                      child: const Text('重置', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 顶部预览 ──
          Container(
            color: const Color(0xFF161b22),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SvgPetWidget(key: _previewKey, size: 120),
            ),
          ),
          // ── 动画池 ──
          _buildAnimPool(),
          const Divider(color: Color(0xFF30363d), height: 1),
          // ── 状态分组列表 ──
          Expanded(child: _buildStateGroups()),
        ],
      ),
    );
  }

  Widget _buildAnimPool() {
    return Container(
      color: const Color(0xFF161b22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标签
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white54)),
                    selected: selected,
                    selectedColor: const Color(0xFF58a6ff),
                    backgroundColor: const Color(0xFF21262d),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
          // 动画卡片横向滚动
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _filteredCards.length,
              itemBuilder: (_, i) {
                final card = _filteredCards[i];
                return _AnimCardWidget(
                  card: card,
                  onTap: () => _previewAnim(card),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateGroups() {
    // 按 category 分组
    final categories = <String, List<StateGroup>>{};
    for (var g in AnimationConfigService.filteredStateGroups) {
      categories.putIfAbsent(g.category, () => []).add(g);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final catName = categories.keys.elementAt(i);
        final groups = categories[catName]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(catName, style: const TextStyle(color: Color(0xFF58a6ff), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            ...groups.map((g) => _buildStateTile(g)),
          ],
        );
      },
    );
  }

  Widget _buildStateTile(StateGroup group) {
    final animIds = widget.configService.getAnimIds(group.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Row(
          children: [
            Text(group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${animIds.length} 个动画', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 重置按钮
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 18, color: Colors.white38),
              tooltip: '恢复默认',
              onPressed: () { widget.configService.resetState(group.id); setState(() {}); },
            ),
            const Icon(Icons.expand_more, color: Colors.white38),
          ],
        ),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...animIds.map((aid) {
                final card = AnimationConfigService.cardById[aid];
                if (card == null) return const SizedBox();
                return _AssignedChip(
                  card: card,
                  canRemove: animIds.length > 1,
                  onTap: () => _previewAnim(card),
                  onRemove: () { widget.configService.removeAnim(group.id, aid); setState(() {}); },
                );
              }),
              // 添加按钮
              ActionChip(
                avatar: const Icon(Icons.add, size: 16, color: Color(0xFF58a6ff)),
                label: const Text('添加', style: TextStyle(color: Color(0xFF58a6ff), fontSize: 12)),
                backgroundColor: const Color(0xFF21262d),
                side: const BorderSide(color: Color(0xFF58a6ff), width: 0.5),
                onPressed: () => _showAddDialog(group.id, group.name),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 动画池中的小卡片
class _AnimCardWidget extends StatelessWidget {
  final AnimationCard card;
  final VoidCallback onTap;
  const _AnimCardWidget({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF21262d),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363d)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SVG 缩略图（用 WebView 加载太重，用图标代替）
            const Icon(Icons.animation, color: Color(0xFF58a6ff), size: 28),
            const SizedBox(height: 4),
            Text(
              card.name,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              card.category,
              style: const TextStyle(color: Colors.white24, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// 状态分组中已分配的动画标签
class _AssignedChip extends StatelessWidget {
  final AnimationCard card;
  final bool canRemove;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _AssignedChip({required this.card, required this.canRemove, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF21262d),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363d)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.animation, size: 14, color: Color(0xFF58a6ff)),
            const SizedBox(width: 4),
            Text(card.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (canRemove) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 14, color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 添加动画对话框
class _AddAnimDialog extends StatefulWidget {
  final String stateId;
  final String stateName;
  final AnimationConfigService configService;
  final VoidCallback onAdded;
  final void Function(AnimationCard) onPreview;
  const _AddAnimDialog({
    required this.stateId, required this.stateName,
    required this.configService, required this.onAdded, required this.onPreview,
  });

  @override
  State<_AddAnimDialog> createState() => _AddAnimDialogState();
}

class _AddAnimDialogState extends State<_AddAnimDialog> {
  String _filterCategory = '全部';
  late List<String> _categories;
  final GlobalKey<SvgPetWidgetState> _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _categories = ['全部', ...{for (var c in AnimationConfigService.allCards) c.category}];
  }

  @override
  Widget build(BuildContext context) {
    final currentIds = widget.configService.getAnimIds(widget.stateId).toSet();
    final available = _filterCategory == '全部'
        ? AnimationConfigService.allCards
        : AnimationConfigService.allCards.where((c) => c.category == _filterCategory).toList();

    return Dialog(
      backgroundColor: const Color(0xFF161b22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 标题 + 预览
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SvgPetWidget(key: _previewKey, size: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('「${widget.stateName}」动画选择', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 分类过滤
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected = cat == _filterCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white54)),
                      selected: selected,
                      selectedColor: const Color(0xFF58a6ff),
                      backgroundColor: const Color(0xFF21262d),
                      onSelected: (_) => setState(() => _filterCategory = cat),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // 动画列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final card = available[i];
                  final alreadyAdded = currentIds.contains(card.id);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.animation, color: Color(0xFF58a6ff), size: 20),
                    title: Text(card.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text('${card.category} · ${card.id}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    trailing: alreadyAdded
                        ? const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)
                        : const Icon(Icons.add_circle_outline, color: Color(0xFF58a6ff), size: 20),
                    onTap: () {
                      _previewKey.currentState?.forceSvgPath(card.svgPath);
                      if (alreadyAdded) {
                        widget.configService.removeAnim(widget.stateId, card.id);
                      } else {
                        widget.configService.addAnim(widget.stateId, card.id);
                      }
                      widget.onAdded();
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
