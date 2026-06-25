# Clawd Pet - Android 桌宠

## 功能

- ✅ WebSocket 连接到 State Bridge
- ✅ 实时显示 AI 状态（空闲/思考/工作/成功/错误）
- ✅ 设置页面（服务器地址、端口、自动连接）
- ✅ 聊天面板
- ✅ 桌宠大小可调
- ✅ ZeroTier 支持
- ✅ **悬浮窗**（始终在最上层，可拖动）

## 安装 Flutter

### Windows
1. 下载 Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. 解压到 `C:\flutter`
3. 添加 `C:\flutter\bin` 到 PATH 环境变量
4. 运行 `flutter doctor` 检查环境

### 安装 Android Studio
1. 下载 Android Studio: https://developer.android.com/studio
2. 安装并配置 Android SDK
3. 创建 Android 模拟器或连接真机

## 构建步骤

```bash
# 1. 进入项目目录
cd clawd-pet-android

# 2. 创建 Flutter 项目结构
flutter create . --org com.example --project-name clawd_pet

# 3. 安装依赖
flutter pub get

# 4. 运行（调试模式）
flutter run

# 5. 构建 APK
flutter build apk --release
```

## 使用步骤

### 1. 启动 State Bridge（电脑端）
```bash
cd state-bridge
python main.py
```

### 2. 安装 ZeroTier（推荐，用于远程连接）
- 电脑和手机都安装 ZeroTier
- 加入同一网络（记住 Network ID）
- 在 ZeroTier 管理后台授权设备
- 获取电脑的 ZeroTier IP（10.x.x.x）

### 3. 配置 Android 应用
1. 打开应用
2. 进入设置
3. 填写服务器地址：
   - 本地网络：电脑的局域网 IP（如 192.168.1.100）
   - ZeroTier：电脑的 ZeroTier IP（10.x.x.x）
4. 端口：8001
5. 保存并连接

### 4. 使用
- 桌宠会自动显示 AI 状态
- 点击桌宠打开聊天面板
- 在聊天面板中发送消息

## 架构

```
Android 桌宠 (Flutter)
      │
      │ WebSocket
      │
ZeroTier 专网
      │
      ▼
State Bridge (Python)
      │
      ▼
OpenClaw
```

## 文件结构

```
clawd-pet-android/
├── lib/
│   ├── main.dart              # 应用入口
│   ├── models/
│   │   └── state_event.dart   # 状态事件模型
│   ├── services/
│   │   ├── websocket_service.dart  # WebSocket 服务
│   │   └── settings_service.dart   # 设置服务
│   └── screens/
│       ├── settings_screen.dart    # 设置页面
│       └── chat_screen.dart        # 聊天面板
├── assets/                    # 资源文件
├── pubspec.yaml              # 依赖配置
└── README.md                 # 说明文档
```

## 状态说明

| 状态 | 图标 | 颜色 | 说明 |
|------|------|------|------|
| idle | 🦀 | 灰色 | 空闲 |
| user_message | 👀 | 蓝色 | 收到消息 |
| thinking | 🤔 | 橙色 | 思考中 |
| tool_call | 🔧 | 紫色 | 工作中 |
| success | 🎉 | 绿色 | 完成 |
| error | ❌ | 红色 | 错误 |

## 下一步

- [ ] 添加悬浮窗功能
- [ ] 集成 Clawd 动画资源
- [ ] 添加通知功能
- [ ] 支持语音输入
- [ ] Live2D 动画
