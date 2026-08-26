# FactoryLumi

Lumi 的**装配根**（Composition Root）：将 KernelCore 内核、全部 Provider 默认实现、
100+ 插件与视图组装集中在一个包中完成接线，是 Lumi 主应用启动的唯一入口。

## 职责

FactoryLumi 不包含业务逻辑，只负责**把正确的事情在正确的时机做对**：

| 职责 | 实现 | 说明 |
| --- | --- | --- |
| 内核创建 | `KernelFactory` | 创建 `KernelCoreContainer`，装配 Provider，启动插件 |
| Provider 工厂 | `DefaultProviderFactory` | 产出 30+ 个 Provider 默认实现并按依赖顺序注册 |
| Plugin 工厂 | `DefaultPluginFactory` | 产出 100+ 个插件，统一校验、排序、原子启动 |
| View 工厂 | `DefaultViewFactory` | 用内核 Provider 组装主视图与设置视图 |
| 菜单集成 | `AppCommands` | 把 `CommandProviding` 贡献映射到 macOS 系统菜单 |
| 主题桥接 | `PaletteChromeTheme` | 把新版 `LumiThemePalette` 适配回 LumiUI 旧版 chrome 主题 |

## 三大工厂协议

```swift
/// 产出全部插件。宿主可实现该协议覆盖插件列表。
protocol PluginFactory {
    func makePlugins() -> [any SuperPlugin]
}

/// 产出各 Provider 默认实现并注册进内核。
protocol ProviderFactory {
    func makeStorageProvider() -> any StorageProviding
    func makeThemeProvider() -> any ThemeProviding
    // ... 30+ 个 make 方法
    func registerProviders(into kernel: KernelCoreContainer) throws
}

/// 用已装配的内核组装主视图与设置视图。
protocol ViewFactory {
    func makeMainView(kernel: KernelCoreContainer) throws -> AnyView
    func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView
}
```

## 快速开始

### 最简启动

```swift
import FactoryLumi

// 一行创建内核 + 组装主视图
let mainView = try KernelFactory.makeMainView()
```

### 共享内核

主窗口、设置窗口、菜单栏共享同一内核实例，主题切换即时同步：

```swift
// 创建内核（装配 Provider + 启动插件）
let kernel = try KernelFactory.makeKernel()

// 用同一内核组装不同视图
let mainView     = try KernelFactory.makeMainView(kernel: kernel)
let settingsView = try KernelFactory.makeSettingsView(kernel: kernel)

// 菜单栏
WindowGroup { mainView }
    .commands { AppCommands(kernel: kernel) }

Settings { settingsView }
```

### 异步启动

需要数据库迁移、进程启动、Language Server 等异步准备的插件：

```swift
let kernel = try await KernelFactory.makeKernelAsync()
```

### 自定义工厂

宿主可替换任意一层工厂覆盖默认行为：

```swift
// 自定义插件列表
let kernel = try KernelFactory.makeKernel(
    providerFactory: MyProviderFactory(),
    pluginFactory: MyPluginFactory()
)

// 自定义视图组装
let view = try KernelFactory.makeMainView(
    kernel: kernel,
    viewFactory: MyViewFactory()
)
```

## 插件过滤

`SelectedPluginFactory` 把完整插件目录过滤到指定白名单，
用于专用应用（AppIconDesigner、BookletMaker 等）复用同一套工厂而无需
逐一手写插件列表：

```swift
let factory = SelectedPluginFactory(
    allowedPluginIDs: ["com.coffic.lumi.storage", "com.coffic.lumi.theme"]
)
let kernel = try KernelFactory.makeKernel(pluginFactory: factory)
```

过滤在启动前执行，被排除的插件不会 Boot 也不会发布 UI 贡献。

## 外部路径路由

`KernelFactory.openExternalPath(_:kernel:)` 处理 Finder / Dock / URL Scheme
传入的路径：

- **目录** → 切换当前项目（`ProjectProviding.openProject`）
- **文件** → 分发给 `ExternalFileOpening` 注册的处理器（如 DatabaseManager）

## 装配顺序

Provider 注册顺序由 `DefaultProviderFactory.registerProviders(into:)` 控制，
遵循依赖拓扑：

```
Storage → Theme → ContentView / ChatSection → Conversation → Message
→ LLMProvider → Streaming → LifecycleHooks → LLMManager → ToolManager
→ AgentLoop → MessageSender → ConversationInput → Rendering
→ PromptSuggestion → Workspace → Onboarding → Command → IdleTime
→ LegacyData → PluginControl → PluginManaging → WebServer
→ ExternalFile → DocsView → MenuBar → Logo → Project → Toast
→ Network → Toolbar → RootView → ActivityBar → RailView → SettingView
```

插件启动顺序由各插件的 `order` 属性控制，同一依赖层级内按 `order` 升序排列。
关键约束：

- `PluginActivityBar` 必须在所有向 ActivityBar 贡献条目的插件之前启动
- `PluginSettingView` 必须在各设置入口贡献插件之前启动
- `PluginLogoManager` 必须在各 Logo 贡献插件之前启动
- `PluginLLMManager` 必须在 AgentLoop 与各供应商插件之前启动
- `PluginToolManager` 必须在 AgentLoop 之前启动

## 目录结构

```
Sources/FactoryLumi/
├── Contracts/
│   ├── SuperPluginFactory.swift     # PluginFactory 协议
│   ├── SuperProviderFactory.swift   # ProviderFactory 协议
│   └── SuperViewFactory.swift       # ViewFactory 协议
├── KernelFactory.swift              # 内核创建与视图组装入口
├── ProviderFactory.swift            # DefaultProviderFactory 实现
├── PluginFactory.swift              # DefaultPluginFactory 实现
├── ViewFactory.swift                # DefaultViewFactory 实现
├── AppCommands.swift                # macOS 系统菜单集成
└── PaletteChromeTheme.swift         # 主题适配桥接
```

## 与 KernelCore 的关系

KernelCore 是零依赖的最小内核，不定义任何具体 Provider；FactoryLumi 在
KernelCore 之上完成全部装配：

```
┌─────────────────────────────────────────┐
│              Lumi App                    │
│   try KernelFactory.makeMainView()      │
├─────────────────────────────────────────┤
│            FactoryLumi                  │
│  ProviderFactory + PluginFactory        │
│  + ViewFactory + AppCommands            │
├─────────────────────────────────────────┤
│  Plugin×100+  │  Provider×30+  │ LumiUI │
├─────────────────────────────────────────┤
│             KernelCore                  │
│   泛型注册表 · 插件生命周期 · 依赖排序     │
└─────────────────────────────────────────┘
```

## 平台要求

- macOS 14.0+
- Swift 5.9+
