import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: const Color(0xFF0d1117),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App 图标和名称
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161b22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF30363d)),
                    ),
                    child: const Icon(Icons.pets, size: 40, color: Color(0xFF58a6ff)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Clawd Pet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('v1.0.0', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 功能介绍
            _sectionTitle('功能介绍'),
            const SizedBox(height: 8),
            _infoCard([
              '一个可爱的 Android 桌面宠物悬浮窗应用',
              '支持 OpenClaw 状态同步，宠物会随 AI 工作状态变化',
              '音乐检测、打字检测、通知检测、来电检测',
              '电池充电/低电量、网络断开状态感知',
              '拖拽交互、点击反应、边缘挂载迷你模式',
              '睡眠序列：5分钟无操作自动进入睡眠',
              '自定义动画配置：为每个状态自由搭配动画组合',
              '空闲时自动轮播随机动画',
            ]),
            const SizedBox(height: 24),

            // 动画资源致谢
            _sectionTitle('动画资源致谢'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161b22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF30363d)),
              ),
              child: const Text(
                '本应用的所有 SVG 动画资源均来自开源项目 Clawd on Desk，这是一个由 Ruller_Lulu / 鹿鹿 开发的 Electron 桌面端 AI 桌宠应用。感谢原版作者的开源贡献。',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            _linkCard(
              icon: Icons.code,
              title: '原版项目仓库',
              subtitle: 'github.com/rullerzhou-afk/clawd-on-desk',
              color: const Color(0xFF58a6ff),
            ),
            const SizedBox(height: 32),

            // 作者
            Center(
              child: Text(
                '作者：未来注定之人',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Color(0xFF58a6ff), fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _infoCard(List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('·  ', style: TextStyle(color: Color(0xFF58a6ff), fontSize: 13)),
              Expanded(child: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _linkCard({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363d)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
