# Forge VPN 项目总结

更新时间：2026-07-17

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

---

## 6. 当前状态快照

```
GitHub: luolihao-aicode/iPhoneVpnclient
最近 9 个 commit (57b4c90 → 7875d0f):
  - fix CI YAML: use external Python script ...
  - fix: correct ipa path to build/ios/Release-iphoneos/Runner.app
  - fix CI: ignore flutter signing validation failure, grab compiled .app
  - fix CI: patch Xcode project to disable code signing before build
  - fix: correct sing-box API (option.Options, TunOptions, constant.Version) + v1.10.0 tag
  - fix: rename Go package from 'main' to 'singbox' for gomobile compatibility
  - fix CI: add golang.org/x/mobile dependency for gomobile bind
  - fix: align iOS UI with desktop template + integrate sing-box + CI pipeline
  - (previous commits before tonight)
```

### 遗留问题

1. **iOS 签名：** CI 打出的 .ipa 是 unsigned，需要手动签名或使用免费 Apple ID 设置自动签名
2. **iOS sing-box 框架链接：** 需要把 `Singbox.xcframework` 加到 Xcode 项目配置中才能启用真正的代理转发
3. **智能分流规则：** 桌面版 GeoIP/GeoSite 规则仍比较粗糙
4. **Android 实测：** Android VpnService 尚未经过实际测试
