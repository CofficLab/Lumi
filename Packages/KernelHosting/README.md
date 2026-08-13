# KernelHosting

平台中性的 `KernelLumi` 生命周期宿主，负责内核实例的创建、注册与销毁。

## 设计理念

`KernelHosting` 把"内核生命周期"从 macOS 专属的 `FactoryCore` 中剥离出来，
变成一个同时编译到 macOS 与 iOS 的中立层。macOS 宿主（`FactoryCore`）与未来的
iOS 的 App 专属 Factory 共用这一份实现，避免内核生命周期漂移。

它只依赖 `KernelLumi` 与日志，**不涉及任何平台 chrome**（窗口、工具栏、菜单栏、
应用代理等）。这让它可以在两个平台之间无差别复用。

## 平台支持

- macOS 14+
- iOS 17+

## 核心 API

```swift
// 创建并启动一个内核（插件列表由宿主在编译期确定后传入）
let kernel = try await KernelHosting.createKernel(
    plugins: plugins,
    enabledPluginIDs: ["com.coffic.lumi.some-plugin"]
)

// 主内核（第一个创建的，通常应用启动时用）
let main = try await KernelHosting.createMainKernel(plugins: plugins)

// 访问注册表
KernelHosting.mainKernel
KernelHosting.kernels

// 销毁（用于测试或重置）
KernelHosting.destroyKernel(kernel)
KernelHosting.destroyAllKernels()
```

`createKernel` 内部依次完成：实例化 `KernelLumi` → 初始化插件 → 应用启用覆盖 →
订阅插件变更通知 → `kernel.startup()` → 登记到注册表。

## 职责边界

KernelHosting **只管**内核实例本身的生命周期。

| 职责 | 归属 |
| --- | --- |
| 内核创建 / 启动 / 销毁 / 注册表 | `KernelHosting` |
| 插件列表的确定与组装 | 宿主 Factory（`FactoryLumi` / `FactoryBookletMaker` 等） |
| 窗口、工具栏、菜单栏、设置面板等 chrome | `FactoryCore`（macOS）/ 各 App 的 Mobile Factory（iOS） |
| 宿主偏好（是否显示状态栏、活动栏等） | `FactoryConfiguration`（留在 `FactoryCore`） |

正因如此，`createKernel` 接收的是原始的 `plugins` / `enabledPluginIDs`，
而不是整个 `FactoryConfiguration`——后者承载的是宿主 chrome 关心的偏好，
与内核生命周期无关。

## 在架构中的位置

```
macOS:  App → FactoryBookletMaker → FactoryCore ─────────┐
                                              ↓           ├── 共用
iOS:    App → FactoryBookletMakerMobile ───────────────┘
                                              ↓
                                         KernelHosting
                                              ↓
                                          KernelLumi
```

- macOS：`FactoryCore.createKernel` / `mainKernel` / `destroy*` 等是转发到
  `KernelHosting` 的薄封装，保证现有调用方零改动。
- iOS：每个 App 的 Mobile Factory 直接调用 `KernelHosting`，不依赖 macOS 专属的
  `FactoryCore`。

## 依赖

- `KernelLumi`
- `SuperLogKit`
