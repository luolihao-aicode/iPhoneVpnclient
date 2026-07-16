# Forge VPN 项目总结

更新时间：2026-07-17（第 3 轮 CI 调试）

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

### 第 3 轮修复摘要

详见 [第 8 节：第 3 轮 CI 调试记录](#8-第-3-轮-ci-调试记录2026-07-17-0615--0647)。

本轮通过 3 次 commit 修复了 6 个问题：

| # | 问题 | commit |
|---|------|--------|
| 1 | iOS 键盘盖导航 | `62e1556` |
| 2 | 缺少扩展 Target → VPN 不工作 | `62e1556` |
| 3 | pbxproj 格式错误（组引用错位）| `cc386b3` |
| 4 | VpnError 跨 Target 不可见 | `197bf8d` |
| 5 | VpnPlugin 跨 Target 引用（8 处）| `e2059de` |
| 6 | Build phase 顺序错误 | `e2059de` |

## 8. 第 3 轮 CI 调试记录（2026-07-17 06:15 ~ 06:47）

### 测试 → Bug → 修复循环

```
昊哥 Windows 推送 → GitHub Actions 构建 → 昊哥下载 .ipa → 爱思助手安装 → 实测反馈
    ↑                                                                        ↓
    └────────── 我改代码/文档 → git commit → 昊哥再推 ────────────────────┘
```

### 本轮修复摘要

| # | 问题 | 现象 | 修复 | commit |
|---|------|------|------|--------|
| 1 | iOS 键盘盖导航 | Nodes 页面输入 URL 后键盘不消失，无法切页 | `GestureDetector` + `keyboardDismissBehavior` + FocusNode | `62e1556` |
| 2 | 缺少扩展 Target | VPN 连接失败，Settings > VPN 不显示 | 创建 ForgeVpnPacketTunnel target (+ Info.plist、pbxproj 脚本) | `62e1556` |
| 3 | pbxproj 格式错误 | CocoaPods 解析失败：Dictionary missing value | 扩展组引用插错位置（在 RunnerTests 组定义内部），移正 | `cc386b3` |
| 4 | VpnError 跨 Target 不可见 | CI 编译失败：Cannot find 'VpnError' in scope | PacketTunnelProvider 移到扩展后 Runner 看不到它定义的 VpnError，加回 VpnPlugin.swift | `197bf8d` |
| 5 | VpnPlugin 跨 Target 引用 | CI 编译链接失败（实际 8 处引用） | 扩展不能引用主 App 的 VpnPlugin，全部改为 os_log | `e2059de` |
| 6 | Build phase 顺序错误 | Embed App Extensions 排在 Sources 之前 | 移到 Resources 之后、Embed Frameworks 之前 | `e2059de` |

### 关键修复详解

#### 问题 3：pbxproj 组引用错位

one-pass 脚本中判断 `331C8082294A63A400263BE5 /* RunnerTests */` 时有二义性：
- `RunnerTests /* RunnerTests */,` → children 列表中的引用（应插入扩展组引用）
- `RunnerTests /* RunnerTests */ = {` → 组定义头（误插入导致 `=` 和 `,` 冲突）

**修复：** 匹配改为检查行尾是否为 `,`。

#### 问题 4：VpnError 跨 Target

- 修复前：`VpnError` 定义在 `PacketTunnelProvider.swift`，Runner Target 可访问（同 Target）
- 修复后：`PacketTunnelProvider.swift` 移到了扩展 Target → Runner 访问不到
- **修复：** 在 `VpnPlugin.swift` 中重新定义 `VpnError`，两 Target 各有一份

#### 问题 5：扩展不能引用主 App 类

iOS 扩展运行在独立进程，`PacketTunnelProvider.swift` 中 8 处 `VpnPlugin.sendLog/sendStatus` 调用在链接时会找不到符号。

全部替换为 `os_log(.info, ...)`：

| 原代码 | 替换为 |
|--------|--------|
| `VpnPlugin.sendLog("[sing-box] %s", msg)` | `os_log(.info, "[ForgeVPN] [sing-box] %{public}@", msg)` |
| `VpnPlugin.sendStatus("connected", ...)` | 删除（NEVPNManager 自动处理状态） |
| `VpnPlugin.sendStatus("disconnected", ...)` | 删除 |

#### 问题 6：Build phase 顺序

原始 -> 修复后：
```
buildPhases = (
  [Embed App Extensions],   ❌ 放最前面，扩展还没编译
  Run Script,
  Sources,
  Frameworks,
  Resources,
  Embed Frameworks,
  Thin Binary,
)

→

buildPhases = (
  Run Script,
  Sources,
  Frameworks,
  Resources,
  [Embed App Extensions],  ✅ 放 Resources 之后，扩展已编译
  Embed Frameworks,
  Thin Binary,
)
```

### 当前项目结构

```
forge-vpn-flutter/
├── ios/
│   ├── Runner/                          # 主 App Target
│   │   ├── VpnPlugin.swift              # Flutter ↔ iOS 桥接（MethodChannel）
│   │   ├── AppDelegate.swift
│   │   ├── PacketTunnelProvider.swift
│   │   ├── Info.plist                   # NEProviderClasses 声明
│   │   └── Runner.entitlements
│   ├── ForgeVpnPacketTunnel/            # 扩展 Target（新建）
│   │   └── Info.plist                   # NSExtension 声明
│   └── Runner.xcodeproj/
│       └── project.pbxproj             # 2 targets: Runner + ForgeVpnPacketTunnel
└── scripts/
    ├── patch-pbxproj.py                # Xcode 项目修改脚本
    └── fix-pbxproj.py                  # 格式修复脚本
```

### 当前测试要点（第 3 轮，待测）

1. ❓ **VPN 配置显示** — Settings > VPN 是否有 "Forge VPN"
2. ❓ **VPN 连接** — Dashboard 选节点 → 连接是否成功
3. ❓ **订阅导入** — 输入 URL → Import → 节点列表是否正常
4. ❓ **节点检测** — Check 按钮能否检测节点可用性
5. ❓ **路由切换** — Settings 切换 Global proxy / Smart split
6. ❓ **断开连接** — 再次点击连接按钮断开

### 构建成功后安装步骤

1. GitHub Actions 下载 `forge-vpn-ios.ipa` artifact
2. 爱思助手 → 工具箱 → 签名（用个人 Apple ID 手动签名）
3. 爱思助手 → 我的设备 → 应用游戏 → 导入安装

> ⚠️ CI 产的 .ipa 是 unsigned，侧载一定要手动签名一步，不然装不上。

---

### 遗留问题

1. **iOS 签名：** CI 打出的 .ipa 是 unsigned，侧载需要爱思助手手动签名才能安装
2. **智能分流规则：** 中文站域名列表（`cnDirectSuffixes`）仍比较粗糙，缺少更新维护
3. **Android 实测：** Android VpnService 桥接就绪但尚未经过实际测试
4. **扩展 0 实测：** ForgeVpnPacketTunnel 扩展是第一次加入构建，CI 构建可能因包体大小变化影响阈值，需观察构建日志
5. **Singbox.framework 未链接到扩展：** 如果 CI 构建成功但 VPN 仍然不工作，需确认扩展的 Frameworks 阶段是否正确导入了 Singbox.xcframework
