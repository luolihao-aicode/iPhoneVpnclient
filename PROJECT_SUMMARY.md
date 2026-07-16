# Forge VPN 项目总结

更新时间：2026-07-17（第 3 轮）

---

## 1. 项目说明

Forge VPN 是一个跨平台 VPN/代理客户端，使用 sing-box 作为核心代理引擎。

### 平台

| 平台 | 项目 | 技术栈 | 状态 |
|------|------|--------|------|
| Windows | `desktop-vpn-client` | Electron + Node.js + sing-box | ✅ 主流程可用 |
| iOS | `forge-vpn-flutter` | Flutter + Dart + sing-box | 🚧 测试中 |
| Android | `forge-vpn-flutter` | Flutter + Dart + Kotlin VpnService | 🚧 开发中 |

### 核心理念

- 导入订阅链接 → 解析节点 → 展示节点 → 检测可用性 → 一键连接
- 断开/退出时彻底清理代理，不留残留
- 双路由模式：Global proxy 全走代理 / Smart split 智能分流

---

## 2. 代码结构

### 2.1 桌面母版 `desktop-vpn-client`

```
desktop-vpn-client/
├── resources/bin/sing-box.exe         # sing-box 核心引擎
├── scripts/                           # PowerShell 脚本
│   ├── clear-system-proxy.ps1         # 清理 Windows 系统代理
│   ├── set-system-proxy.ps1           # 设置系统代理
│   ├── install-logon-proxy-cleanup.ps1 # 安装登录兜底清理
│   ├── install-singbox.ps1            # sing-box 安装
│   ├── start-singbox.ps1              # 启动 sing-box
│   ├── stop-singbox.ps1               # 停止 sing-box
│   └── ...
├── src/
│   ├── core/
│   │   ├── subscription.js            # 订阅解析 (Base64/JSON/URI)
│   │   ├── singbox.js                 # sing-box 配置生成 + 进程管理
│   │   ├── systemProxy.js             # WinHTTP/注册表代理管理
│   │   ├── nodeHealth.js              # 节点健康检测 (临时 sing-box)
│   │   ├── nodeLatency.js             # 节点排序统计
│   │   └── stats.js                   # 流量读取 (Clash API)
│   ├── main/
│   │   ├── main.js                    # Electron 主进程
│   │   └── preload.cjs                # IPC 桥接
│   └── renderer/
│       ├── index.html                 # 前端结构 (4 页)
│       ├── renderer.js                # 前端交互
│       └── styles.css                 # 样式
├── package.json
└── project_context.md                 # 详细上下文字档
```

### 2.2 Flutter 跨平台客户端 `forge-vpn-flutter`

```
forge-vpn-flutter/
├── lib/
│   ├── main.dart                      # Flutter 入口 + 主题 + 导航壳
│   ├── core/
│   │   ├── models/node.dart           # VpnNode 数据模型 (6 协议)
│   │   ├── subscription.dart          # 订阅解析 (Dart, 镜像 JS 逻辑)
│   │   ├── singbox_config.dart        # sing-box 配置生成
│   │   ├── node_health.dart           # 节点健康检测
│   │   ├── node_latency.dart          # 节点排序 + 可用计数
│   │   └── stats.dart                 # 流量统计
│   ├── providers/
│   │   └── app_provider.dart          # 全局状态管理
│   ├── screens/
│   │   ├── dashboard_screen.dart      # Dashboard: 状态卡 + 指标 + 节点表
│   │   ├── nodes_screen.dart          # Nodes: 订阅导入 + 节点列表
│   │   ├── settings_screen.dart       # Settings: 路由模式 + 系统代理
│   │   └── logs_screen.dart           # Logs: 日志列表
│   ├── services/
│   │   ├── singbox_service.dart       # sing-box 进程控制 (桌面)
│   │   ├── android_vpn_service.dart   # Android VpnService MethodChannel
│   │   └── ios_vpn_service.dart       # iOS NETunnelProvider MethodChannel
│   └── widgets/
│       └── responsive.dart            # 自适应布局 breakpoints
├── ios/
│   └── Runner/
│       ├── VpnPlugin.swift            # Flutter ↔ iOS 原生桥接
│       ├── PacketTunnelProvider.swift  # iOS TUN 隧道 + sing-box 集成
│       └── build-singbox-ios.sh       # gomobile 编译 sing-box 脚本
├── golib/ios/                         # Go gomobile 绑定
│   ├── main.go                        # sing-box iOS 绑定入口
│   ├── tools.go                       # golang.org/x/mobile 依赖
│   └── go.mod
├── scripts/
│   └── disable-codesign.py            # CI: 禁用代码签名脚本
└── .github/workflows/build-ios.yml    # GitHub Actions CI
```

---

## 3. 项目进度

### Windows (desktop-vpn-client) ✅ 主流程可用

**已完成：**
- 订阅导入 + 节点解析 (Base64/JSON/URI)
- sing-box 集成 (HTTP/SOCKS/Clash API)
- 节点真实可用性检测 (YouTube HTTPS)
- 节点表 + Ping + Available + Status 列
- Start/Stop 一键连接
- Global proxy / Smart split
- 系统代理自动设置 + 清理
- WinHTTP 代理管理
- 托盘后台运行 + 右键菜单
- 退出时清理代理
- 重启/注销同步清理代理
- 登录后兜底清理脚本

**待验证：**
- 开着 VPN 重启后的代理清理 —— 需要真实重启测试

### iOS (forge-vpn-flutter) 🚧 测试中

**已完成：**
- Dashboard / Nodes / Settings / Logs 四页面
- 订阅解析 (Dart)
- 节点健康检测
- 节点表格 (Node/Protocol/Endpoint/Ping/Available/Status)
- Check 按钮 + 可用数量
- 双击连接
- 状态徽章 (Connected/Selected/Ready)
- 自适应布局 (phone/tablet/desktop)
- iOS NETunnelProvider + sing-box 集成 (gomobile)
- CI 自动编译

**进行中：**
- iOS 实测调试
- CI 签名问题（未签名 .ipa 可侧载，但需要手动签名或 Apple Developer 账号）

### Android (forge-vpn-flutter) 🚧 开发中

- Android VpnService 基础桥接就绪
- 尚未实际测试

---

## 4. Bug 修复时间线（今晚 2026-07-17）

所有修改在 `forge-vpn-flutter` 仓库。

| # | 问题 | 修改 | Commit |
|---|------|------|--------|
| 1 | iOS Dashboard 只有横向 chips，缺少桌面版的完整节点表格 | 替换为 6 列节点表 + Check 按钮 + 可用数 + 状态列 + 双击连接 | `9 files changed` |
| 2 | Nodes 页面状态徽章只有 Selected/Tap，没有 Connected | 改为 Connected(绿)/Selected(蓝)/Ready(默认) | 同上 |
| 3 | Settings 缺少 System proxy 信息 | 新增 System proxy 分组 + 托管提示 | 同上 |
| 4 | PacketTunnelProvider.swift 纯透传，没有 sing-box 集成 | 重写为 sing-box gomobile 绑定 + TUN fd/packetFlow 双模式 + DNS 配置 + 局域网排除 | 同上 |
| 5 | Go 绑定代码 `package main` 不被 gomobile 支持 | 改为 `package singbox` | `2 files` |
| 6 | sing-box API 猜错：`box.ParseConfig`/`TUNOptions`/`ListenPrefix`/`box.Version` 都不存在 | 改为 `json.Unmarshal(option.Options)` + JSON 层 tun fd 注入 + `constant.Version` | `2 files` |
| 7 | CI sing-box 版本 `v1.10.6` 不存在 | 修正为 `v1.10.0` | 同上 |
| 8 | `nodes` 和 `availableCount` 未定义的 Dart 编译错误 | 改为 `provider.nodes` + `.where(healthStatus == available).length` | `efbb55e` |
| 9 | `FeedTunPacket`/`ReadTunPacket` 被 revert 从 Go 代码删除，Swift 仍引用 | 重新添加到 `golib/ios/main.go` | `0b6b393` |
| 10 | Swift 调用 gomobile API 签名不匹配（closure 传给 protocol、Start 不会 throw、Int32 应为 Int） | 改用 `SingboxLogCallbackProtocol` 类 + 返回值检查 + `Int` | `0b6b393` |
| 11 | `VpnError` 在两个 Swift 文件中重复定义 | 从 `VpnPlugin.swift` 中移除，保留 `PacketTunnelProvider.swift` 的版本 | `b76ade6` |

---

## 5. GitHub Actions 构建问题分阶段记录

### 阶段 1：初始 CI 没有 sing-box framework

**现象：** CI 只有 `flutter build ios`，没有编译 sing-box iOS framework 的步骤。

**处理：**
- 添加 `build-singbox-framework` job，用 `gomobile bind` 编译 `Singbox.xcframework`
- Go 绑定代码放在 `golib/ios/`
- CI 拉取 `sagernet/sing-box` 源码，注入绑定，编译 framework
- framework 作为 artifact 传给 `build-ios` job

### 阶段 2：`package main` 不被 gomobile 支持

**错误：** `gomobile: binding "main" package is not supported`

**处理：** Go 包名改为 `package singbox`。

### 阶段 3：sing-box API 对接失败（多次编译报错）

**问题 3a：** `golang.org/x/mobile` 不在模块依赖中
- **处理：** `go.mod` + `tools.go` + CI 中 `go get golang.org/x/mobile@latest`

**问题 3b：** `golang.org/x/mobile@v0.0.0-20241204231617-5e49bdcd6d1a` 不存在的 pseudo-version
- **处理：** 不指定版本，让 CI 的 `go get @latest` 自动解析

**问题 3c：** API 不匹配：
- `box.ParseConfig` → 不存在，改为 `json.Unmarshal` 到 `option.Options`
- `option.TUNOptions` → 不存在，正确字段是 `TunOptions`，改为 JSON 层注入
- `option.ListenPrefix` → 不存在，改为字符串
- `option.TUNStackSystem` → 不存在，改为 `"system"`
- `box.Version` → 不存在，改为 `constant.Version`

**处理：** 重写整个 `main.go`，使用 JSON map 操作注入 TUN fd。

### 阶段 4：CI 需要 Development Team 才能编译（签名问题）

**问题 4a：** `Building a deployable iOS app requires a selected Development Team`

尝试方案：
1. ❌ `--no-codesign` → Flutter 仍然在内部校验 Development Team
2. ❌ Python 脚本 patch pbxproj → Flutter 的 `Upgrading project.pbxproj` 步骤会覆盖修改
3. ❌ 直接 xcodebuild → 缺少 Flutter 生成的 framework 缓存
4. ✅ `flutter build ios --release --no-codesign || true` → Xcode 实际编译成功，但 Flutter 后置校验拒绝
5. **最终方案：** 编译失败后直接拿 `build/ios/Release-iphoneos/Runner.app` 打包 .ipa

**现状：** CI 生成 unsigned .app → 打包 .ipa → 上传 artifact。用户拿到后需手动签名或用 AltStore 侧载。

### 阶段 5：YAML 语法错误

**问题：** 内联 Python 脚本的引号破坏 YAML 解析

**处理：** 拆到独立文件 `scripts/disable-codesign.py`，CI 中一行调用

### 阶段 6：revert/rebase 导致代码撕裂（Go ↔ Swift API 错位）

**根因：** `d7379ea` 一次性改了 Go + Swift + Xcode，回滚时 Go 的 `FeedTunPacket`/`ReadTunPacket` 被删但 Swift 引用没同步。后续 rebase 进一步切碎了文件状态。

**现象（CI 反复挂，错误一直在变）：**
1. 16KB .app stub — Flutter 诊断说 Development Team 问题，实际是 Dart 编译错误
2. `DashboardScreen` 缺少 `nodes`/`availableCount` — 用了 undefined getter
3. `SingboxSetLogCallback` 传 closure — gomobile 需要 ObjC protocol 类
4. `SingboxStart` 加了 try — 实际不 throw，返回 String?
5. `tunFd: Int32` — gomobile 桥接是 `Int`
6. `SingboxFeedTunPacket`/`ReadTunPacket` 签名错 — gomobile 用 `Data?` 不是 unsafe pointers
7. `VpnError` 在两个 Swift 文件中重复定义

**处理：**
- 重新添加 `FeedTunPacket`/`ReadTunPacket` 到 `main.go`
- Swift 全部改用 gomobile 生成的正确桥接签名
- 移除 `VpnPlugin.swift` 中的重复 `VpnError`
- CI workflow 去掉 `|| true`，直接报错
- `DEVELOPMENT_TEAM` 和 `CODE_SIGN_ENTITLEMENTS` 直接烙入 `project.pbxproj` 而非 Python 脚本

---

## 6. 当前状态快照

```
GitHub: luolihao-aicode/iPhoneVpnclient
```

### ✅ 已解决（2026-07-17 第 2 轮）

- **16KB .app stub 构建失败：** root cause 是 Dart 编译错误 + Go/Swift API 错位，非 Development Team 问题
- **`DEVELOPMENT_TEAM` 配置固化：** 直接烙入 `project.pbxproj`（`CODE_SIGN_STYLE=Manual; DEVELOPMENT_TEAM=ABCD123456`），不再依赖 Python 脚本
- **`Runner.entitlements`：** 重新创建，含 VPN 网络扩展权限
- **`Singbox.xcframework` 链接：** 重新添加到 Frameworks + Embed Frameworks 阶段
- **Go/Swift API 对齐：** gomobile 桥接签名全部修正
- **CI 不再吞错误：** 去掉 `|| true` + 去掉 `continue-on-error`
- **Swift Package Manager：** 通过 `enable-swift-package-manager: false` 禁用，消除混合警告

### 新增修复（2026-07-17 第 3 轮 — 实测反馈）

#### 🐛 问题 A：iOS 键盘弹起盖住底部导航

**现象：** 在 Nodes 页面输入订阅 URL 时，iOS 键盘弹出后不消失，挡住底部导航栏，无法切页。

**根因：** `NodesScreen` 的 `TextField` 聚焦后 iOS 键盘弹出，`SingleChildScrollView` 没有点空白收回键盘的逻辑。

**修复：**
- 添加 `FocusNode` 管理 TextField 焦点
- 整体包裹 `GestureDetector` + `onTap: _dismissKeyboard`
- `SingleChildScrollView` 增加 `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`
- Import 按钮先收键盘再提交

**修改文件：** `lib/screens/nodes_screen.dart`

#### 🐛 问题 B：VPN 连接失败 `fail to start VPN service`

**现象：** iOS 上选择节点后点击连接，弹出 "fail to start VPN service"。

**根因（关键发现）：** Xcode 项目缺少 **PacketTunnel 扩展 Target**。

```
VpnPlugin.startVPN() 流程
  → NETunnelProviderManager.loadAllFromPreferences()  ✅
  → proto.providerBundleIdentifier = "$(主ID).tunnel"  ✅
  → manager.saveToPreferences()  ❌ 没有这个扩展，VPN profile 注册失败
  → startVPNTunnel()  ❌ 找不到扩展，返回错误
```

**修复：**
1. 新建扩展目录 `ios/ForgeVpnPacketTunnel/`
2. 创建扩展 `Info.plist`（声明 NSExtensionPointIdentifier = `com.apple.networkextension.packet-tunnel`）
3. 脚本修改 `project.pbxproj`（`scripts/patch-pbxproj.py`）：
   - 新增 **ForgeVpnPacketTunnel** target（`productType = app-extension`）
   - Bundle ID: `com.example.forgeVpnFlutter.tunnel`
   - `PacketTunnelProvider.swift` 从 Runner Sources 移出 → 加到扩展 Sources
   - `Singbox.xcframework` 链接到扩展 Frameworks
   - Runner target 增加依赖 + Embed App Extensions build phase
   - 3 个 build config (Debug/Release/Profile)：`SKIP_INSTALL=YES`、`DEVELOPMENT_TEAM=ABCD123456`

**修改文件：**
- `ios/ForgeVpnPacketTunnel/Info.plist`（新建）
- `ios/Runner.xcodeproj/project.pbxproj`（脚本修改）
- `scripts/patch-pbxproj.py`（新建，可重复运行）

#### 🐛 问题 C：Settings > VPN 不显示 Forge VPN 配置

**根因：** 与问题 B 同一根因 — 没有扩展 Target，`saveToPreferences()` 失败，VPN profile 无法注册进系统。

**修复：** 同上（扩展 Target 建立后，`saveToPreferences` 可正常注册 VPN Profile）。

#### 目录结构更新

```
forge-vpn-flutter/
├── ios/
│   ├── Runner/                          # 主 App Target
│   │   ├── VpnPlugin.swift              # Flutter ↔ iOS 桥接（MethodChannel）
│   │   ├── AppDelegate.swift
│   │   ├── Info.plist                   # 主 App Info
│   │   └── Runner.entitlements
│   ├── ForgeVpnPacketTunnel/            # 扩展 Target（新建）
│   │   └── Info.plist                   # 扩展 Info（NSExtension 声明）
│   └── Runner.xcodeproj/
│       └── project.pbxproj             # 新增 ForgeVpnPacketTunnel target
└── scripts/
    └── patch-pbxproj.py                # Xcode 项目修改脚本（新建）
```

## 7. 测试工作流（第 3 轮）

### 流程

```
昊哥测试 → 发现 Bug → 我改代码/配置 → git push
↓
GitHub Actions 自动构建
├── build-singbox-framework    (编译 Singbox.xcframework)
└── build-ios
    ├── 下载 framework
    ├── flutter build ios --release --no-codesign
    ├── 验证 .app >= 1000KB
    └── 打包 .ipa → 上传 artifact
↓
昊哥用爱思助手下载 .ipa → 连手机安装 → 实测
↓ 发现新 Bug → 循环
```

### 当前第 3 轮测试要点

1. ✅ **键盘收起** — Nodes 页面点空白/拖拽/点 Import 都能收键盘
2. ❓ **VPN 配置显示** — Settings > VPN 是否有 "Forge VPN"
3. ❓ **VPN 连接** — Dashboard 选节点 → 连接是否成功
4. ❓ **订阅导入** — 输入 URL → Import → 节点列表是否正常
5. ❓ **节点检测** — Check 按钮能否检测节点可用性
6. ❓ **路由切换** — Settings 切换 Global proxy / Smart split
7. ❓ **断开连接** — 再次点击连接按钮断开

### 构建成功后安装步骤

1. GitHub Actions 下载 `forge-vpn-ios.ipa` artifact
2. 爱思助手 → 工具箱 → 签名（用个人 Apple ID 手动签名）
3. 爱思助手 → 我的设备 → 应用游戏 → 导入安装

> ⚠️ CI 产的 .ipa 是 unsigned，侧载一定要手动签名一步，不然装不上。

## 8. 近期 commit 记录

```
(docs: record 2026-07-17 CI debugging session (Dart/Go/Swift fixes))   ← 第 2 轮
  b76ade6  fix: remove duplicate VpnError enum from VpnPlugin.swift
  0b6b393  fix: re-add FeedTunPacket/ReadTunPacket to Go + fix Swift gomobile API calls
  efbb55e  fix: DashboardScreen uses provider.nodes instead of undefined getters
  2636e44  fix: bake DEVELOPMENT_TEAM & entitlements into pbxproj for unsigned device build
  ...
```

### 遗留问题

1. **iOS 签名：** CI 打出的 .ipa 是 unsigned，侧载需要爱思助手手动签名才能安装
2. **智能分流规则：** 中文站域名列表（`cnDirectSuffixes`）仍比较粗糙，缺少更新维护
3. **Android 实测：** Android VpnService 桥接就绪但尚未经过实际测试
4. **CI 扩展兼容性：** ForgeVpnPacketTunnel 扩展是第一次加入构建，CI 构建可能因扩展数量变化影响 .app/.ipa 大小阈值，需观察
