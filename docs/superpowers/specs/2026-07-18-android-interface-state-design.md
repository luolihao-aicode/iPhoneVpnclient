# Android VPN 接口与状态管理设计

日期：2026-07-18

## 目标与范围

本阶段仅补齐 Flutter 与 Android Kotlin 层之间的 VPN 接口和状态管理，使 Android 的调用与 iOS 的 `dev.forge.vpn/vpn_service` 契约一致。

完成后，应用应能发起 Android 系统 VPN 授权、请求连接或断开、查询运行状态，并持续向 Flutter 回传稳定的状态和日志事件。

本阶段不包含 sing-box 二进制打包、TUN 文件描述符传递、真实流量转发或真机隧道可用性验证。这些留给下一阶段。

## 现状与问题

- Dart 的 `AndroidVpnService.requestPermission` 临时替换 MethodChannel 回调，会覆盖原有状态和日志监听。
- Kotlin `VpnBridge` 尚未处理 `requestPermission`，`isRunning` 固定返回 `false`。
- `MainActivity` 已有授权辅助方法，但没有被桥接调用；授权结果也没有持久化为可查询的状态。
- `ForgeVpnService` 的状态只由本地线程判断，桥接层没有单一、可查询的事实来源。

## 设计

### 通道契约

继续使用现有的 `MethodChannel`：`dev.forge.vpn/vpn_service`。

Flutter 调用 Kotlin 的命令：

- `requestPermission`：启动系统 VPN 授权；立即返回请求是否已成功发起。最终结果由 `onStatus` 事件报告。
- `connect`（参数：`config`）：请求服务连接；立即返回命令是否已被接受，不代表隧道已建立。
- `disconnect`：请求停止服务；立即返回命令是否已被接受。
- `isRunning`：返回桥接层维护的已连接状态。
- `getState`：返回当前状态、消息和权限状态，供 Flutter 初始化时恢复本地状态。

Kotlin 调用 Flutter 的事件：

- `onStatus`（`status`、`message`）：状态变化和授权结果。
- `onLog`（字符串）：诊断日志。

现有的 `connected`、`disconnected`、`error`、`permission_granted`、`permission_denied` 事件保持不变；新中间状态 `ready`、`connecting`、`disconnecting` 仅用于日志和诊断，不会让 Provider 误标记为已连接。

### Flutter 层

`AndroidVpnService` 在实例创建时仅设置一次 MethodChannel handler。权限等待由内部 pending completer 管理，接收 `permission_granted` 或 `permission_denied` 后完成；handler 不会在每次授权请求时被替换。

服务初始化时调用 `getState`，恢复权限和连接标记。所有 PlatformException、缺失插件和非预期异常都转为日志和 `error` 状态，保持与 `IosVpnService` 的失败语义一致。

### Kotlin 层

`VpnBridge` 维护单一状态：`idle`、`permissionPending`、`ready`、`connecting`、`connected`、`disconnecting`、`error`，以及最近的说明消息和权限状态。它负责处理全部 Flutter 命令与状态事件。

`MainActivity` 负责展示系统授权界面，并将活动结果回传给 `VpnBridge`。重复授权请求在 `permissionPending` 时被拒绝或复用，不产生并发 request code。

`ForgeVpnService` 不重写隧道实现；只在连接启动、启动失败、进程退出、停止和销毁时调用桥接层更新状态。服务状态是桥接层 `isRunning` 的唯一来源。

### Provider 行为

`AppProvider` 保持现有对 `connected`、`disconnected`、`error` 和权限事件的处理。对 `ready`、`connecting`、`disconnecting` 增加日志记录，且只有收到 `connected` 才设置 `runtime.connected = true`。

## 错误处理

- 缺少 Android Activity、通道未注册或权限请求启动失败：返回 PlatformException 并上报 `error`。
- 用户拒绝权限：上报 `permission_denied`，等待中的权限请求返回 `false`，不尝试连接。
- 服务启动失败、异常退出或停止：桥接层将状态更新为 `error` 或 `disconnected`，并保留消息用于日志。
- Flutter 重建或恢复：以 `getState` 结果为准，不假设服务仍在运行。

## 验证

- 增加 Dart 单元测试：权限回调不覆盖全局事件处理器、授权结果映射、命令异常与状态恢复。
- 运行 `flutter analyze`。
- 运行 Android debug 编译，验证 Kotlin、Manifest 和 Flutter 通道代码可构建。

## 非目标与后续

下一阶段再验证 Android 真机连接并实现 sing-box 与 TUN 的可靠集成，包括受保护套接字、前台服务限制、通知权限、二进制 ABI 管理和真实流量测试。
