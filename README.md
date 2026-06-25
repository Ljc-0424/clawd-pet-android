# Clawd Pet — Android 桌面宠物

一款运行在 Android 手机上的桌面宠物悬浮窗应用，基于开源项目 [Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk) 的 SVG 动画资源，用 Flutter + Kotlin 原生重新实现。宠物以悬浮窗形式覆盖在所有 App 之上，可以拖拽、点击交互，并根据手机状态和 AI 工作状态自动切换动画。

动画资源原版作者：**Ruller_Lulu / 鹿鹿**

## 两个版本

| | OpenClaw 版（本仓库） | [独立版](https://github.com/Ljc-0424/clawd-pet-standalone) |
|---|---|---|
| 包名 | `com.example.clawd_pet` | `com.example.clawd_desktop_pet` |
| 连接 OpenClaw | ✅ 通过 WebSocket 同步 AI 工作状态 | ❌ 无网络依赖，打开即用 |
| 适用场景 | 配合 OpenClaw AI 使用，宠物随 AI 状态变化 | 纯桌宠，手机状态检测 + 自定义动画 |

两个版本共享相同的核心引擎，唯一区别是 OpenClaw 版多了 WebSocket 连接和 bridge 状态守卫。

## 核心功能

### 交互

| 操作 | 效果 |
|------|------|
| 单击 | 左/右戳反应动画 |
| 双击（300ms 内） | 跳跃反应 |
| 连续 3 戳 | 烦躁反应 |
| 拖拽 | 拖拽动画，带边缘吸附 |
| 边缘挂载 | 拖到屏幕边缘 → 迷你模式（半身探头） |
| 边缘点击 | 第一次探头，第二次跳出回屏幕 |

### 手机状态检测

| 检测器 | 触发 | 动画 | 自动恢复 |
|--------|------|------|---------|
| 音乐播放 | AudioPlaybackCallback + 轮询 | 打碟 | 暂停后恢复 |
| 打字 | AccessibilityService | 打字工作 | 停止 2 秒后恢复 |
| 通知 | AccessibilityService | 通知动画 | 5 秒自动回 |
| 充电 | BroadcastReceiver | 开心 | 一次播放后不再重复 |
| 低电量 | BroadcastReceiver | 哈欠 | 8 秒自动回 |
| 断网 | BroadcastReceiver | 错误 | 恢复网络后回 |
| 来电/通话 | BroadcastReceiver | 通知/打字 | 挂断后回 |
| 息屏/亮屏 | BroadcastReceiver | 暂停/唤醒 | 亮屏恢复之前状态 |

### OpenClaw 状态同步（仅本版本）

通过 State Bridge（Python WebSocket 代理）接收 AI 工作状态：

| 状态 | 动画 | 优先级 | 行为 |
|------|------|--------|------|
| thinking | 思考 | 2 | 持续到新状态 |
| working | 打字工作 | 3 | 持续到新状态 |
| sweeping/juggling/carrying | 扫地/杂耍/搬运 | 4-6 | 持续到新状态 |
| attention | 开心 | 5 | oneshot，4 秒自动回 |
| error | 错误 | 8 | oneshot，5 秒自动回 |
| notification | 通知 | 7 | oneshot，5 秒自动回 |

### 睡眠系统

5 分钟无操作自动进入睡眠序列：

```
哈欠(3秒) → 打盹(10分钟) → 瘫倒(6秒) → 熟睡
```

每步独立 Runnable，任何交互可中断唤醒。

### 空闲动画轮播

空闲时每 6 秒切换一次随机动画，间隔 1.5 秒，不重复：生活、张望、泡泡、巫师、看书（5 种，可自定义扩展）

### 迷你模式（边缘挂载）

- 拖到屏幕边缘 → 角色半身探出 → 播放进入动画
- 迷你空闲、迷你工作、迷你开心、迷你警告、迷你睡眠自动切换
- 点击跳出 → 横移动画滑回屏幕
- 左边缘自动翻转 SVG

## 动画配置系统

用户可通过 Flutter UI 自由配置每个状态的动画组合：

- 37+ 张动画卡片，按分类浏览（空闲/工作/情绪/睡眠/反应/迷你/检测器/经典）
- 14+ 个可配置状态，每个状态可分配多个动画随机轮播
- 实时预览，点击卡片即可查看效果
- 配置持久化到 SharedPreferences，自动同步到 Kotlin 悬浮窗
- 支持一键恢复默认

## 技术架构

```
┌─────────────────────────────────────────────┐
│  Flutter UI 层                               │
│  ┌─────────┐ ┌──────────┐ ┌──────────────┐ │
│  │主页预览  │ │动画配置页│ │ 设置/关于    │ │
│  │SvgPetWidget│ │拖拽卡片  │ │权限引导     │ │
│  └─────────┘ └──────────┘ └──────────────┘ │
│           MethodChannel                      │
├─────────────────────────────────────────────┤
│  Kotlin 原生层                               │
│  ┌────────────────────────────────────────┐ │
│  │ FloatingPetService (前台服务)           │ │
│  │  ┌──────────┐ ┌───────────────────┐   │ │
│  │  │渲染窗口   │ │触摸窗口(角色区域) │   │ │
│  │  │WebView+SVG│ │拖拽/点击/边缘检测 │   │ │
│  │  └──────────┘ └───────────────────┘   │ │
│  │  ┌──────────────────────────────────┐ │ │
│  │  │ 状态机                           │ │ │
│  │  │ 优先级系统 + oneshot 自动回      │ │ │
│  │  │ 睡眠序列(可取消) + 空闲轮播      │ │ │
│  │  │ 迷你模式 + 触摸穿透              │ │ │
│  │  └──────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────┐ │ │
│  │  │ 检测器                           │ │ │
│  │  │ MusicDetector (回调+轮询双保障)  │ │ │
│  │  │ TypingDetector (无障碍+安全超时) │ │ │
│  │  │ Battery / Network / Screen / Call│ │ │
│  │  └──────────────────────────────────┘ │ │
│  └────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│  State Bridge (仅 OpenClaw 版)              │
│  Python FastAPI WebSocket 代理              │
│  接收 OpenClaw 插件状态 → 转发给手机        │
└─────────────────────────────────────────────┘
```

### 悬浮窗双窗口架构

```
渲染窗口 (TYPE_APPLICATION_OVERLAY + FLAG_NOT_TOUCHABLE)
  └─ WebView 加载 SVG 动画
  └─ 完全透明穿透，不拦截触摸
触摸窗口 (TYPE_APPLICATION_OVERLAY, 仅角色区域大小)
  └─ 处理所有拖拽/点击/边缘检测
  └─ 位置和大小随渲染窗口同步
  └─ 角色区域外触摸穿透到其他 App
```

### 状态机设计

```
反应态(点击/拖拽) > attention(特殊通道) > bridge态(优先级) > detector态 > idle > sleeping
每个状态都有明确的退出条件：
- 持久态 → 被更高优先级打断
- oneshot态 → 超时自动回 idle
- 反应态 → 播完自动回 resolveAndApply()
- 睡眠序列 → 每步独立 Runnable，可被任意事件打断
```

## 项目结构

```
lib/
  main.dart                        ← 主页 + 权限引导
  screens/
    settings_screen.dart           ← 连接设置
    animation_config_screen.dart   ← 动画配置 UI
    about_screen.dart              ← 关于页面
  services/
    animation_config_service.dart  ← 动画配置数据模型 + 持久化
    settings_service.dart          ← SharedPreferences 封装
    websocket_service.dart         ← WebSocket 客户端 (仅 OpenClaw)
  widgets/
    svg_pet_widget.dart            ← WebView SVG 预览组件
  models/
    state_event.dart               ← 状态事件模型
android/app/src/main/kotlin/.../
  FloatingPetService.kt           ← 核心：悬浮窗 + 状态机 + 检测器
  MainActivity.kt                 ← MethodChannel 处理
  MusicDetector.kt                ← 音乐检测
  TypingDetector.kt               ← 打字+通知检测 (AccessibilityService)
  BatteryDetector.kt              ← 电池检测
  NetworkDetector.kt              ← 网络检测
  ScreenDetector.kt               ← 屏幕检测
  CallDetector.kt                 ← 来电检测
assets/svg/                       ← 64+ 个 SVG 动画文件
```

## 构建

```bash
# OpenClaw 版
cd clawd-pet-android && flutter build apk --release

# 独立版
cd clawd-pet-standalone && flutter build apk --release

# Bridge（仅 OpenClaw 需要）
cd state-bridge && python main.py
```

## 许可

动画资源来自 [Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk)，原版作者 Ruller_Lulu / 鹿鹿。

作者：**陈俊霖**
