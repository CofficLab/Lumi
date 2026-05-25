# 插件 Package 化架构

> 日期：2026-05-25
> 状态：迁移设计中
> 涉及范围：Core + LumiCoreKit + Plugins

## 背景与动机

Lumi 当前已经有大量插件能力，例如 Git、GitHub、Recent Projects、Editor、LLM Provider、Agent Tools 等。早期插件直接放在 `LumiApp/Plugins` 中，协议、共享模型和部分内核逻辑则散落在 `LumiApp/Core` 中。

这种结构在插件数量较少时可以工作，但随着插件变多，会出现几个问题：

1. 插件核心逻辑和 App Core 耦合，插件很难作为独立单元测试
2. 插件之间容易间接依赖 Core 的具体实现，边界不清晰
3. Core 中堆积了插件协议、共享模型、业务服务和 UI 装配代码
4. 新插件难以形成稳定模板，测试和依赖管理成本逐步升高

因此需要把插件系统的公共契约抽到独立 Package 中，并让每个插件的核心能力也逐步沉淀为独立 Package。

## 目标

最终目标是让每个插件都基于一个 Swift Package 实现。

以 Git 插件为例：

```text
GitPlugin Package
  Sources
    GitPluginCore
      Git 状态、diff、log、commit、branch 等核心逻辑
    GitPlugin
      SuperPlugin 实现、UI 贡献、Agent Tool 注册、App 集成适配
  Tests
    GitPluginCoreTests
    GitPluginTests
```

App 中可以保留插件注册文件，用来决定哪些插件随 App 一起加载。但插件的核心功能不应该依赖 App Core，而应该依赖稳定的插件 SDK：`LumiCoreKit`。

## 目标架构

```text
┌─────────────────────────────────────────────────────┐
│                     LumiApp                         │
│                                                     │
│  Core:                                              │
│    - App 启动                                       │
│    - 窗口和场景管理                                  │
│    - 全局状态装配                                    │
│    - 插件注册和生命周期聚合                           │
│                                                     │
│  BundledPluginRegistry:                             │
│    - 注册随 App 打包的插件实例                         │
└──────────────────────┬──────────────────────────────┘
                       │ imports
                       ↓
┌─────────────────────────────────────────────────────┐
│                  LumiCoreKit                      │
│                                                     │
│  插件 SDK:                                          │
│    - SuperPlugin                                    │
│    - PluginContext / ToolContext                    │
│    - SendPipeline / Middleware                      │
│    - ChatMessage / StreamChunk 等共享模型             │
│    - 子 Agent、LLM Provider、Message Renderer 扩展点   │
└──────────────────────┬──────────────────────────────┘
                       │ imported by
                       ↓
┌─────────────────────────────────────────────────────┐
│                Plugin Packages                      │
│                                                     │
│  GitPluginPackage                                   │
│  GitHubPluginPackage                                │
│  RecentProjectsPluginPackage                        │
│  IdleTimePluginPackage                              │
│  ...                                                │
└─────────────────────────────────────────────────────┘
```

## 分层职责

### LumiApp Core

Core 只保留让 App 跑起来所必须的简单代码：

- App 生命周期和启动入口
- Window、Scene、RootView 装配
- 全局 ViewModel 和 Store 的组合
- 插件列表注册、启用状态、生命周期调度
- 将插件贡献的 UI、工具、中间件、Provider 聚合到 App

Core 不应该继续承载插件协议和插件业务逻辑。

### LumiCoreKit

`LumiCoreKit` 是插件开发 SDK，负责定义插件和 App Core 之间的稳定边界。

适合放入 `LumiCoreKit` 的内容：

- `SuperPlugin` 及其默认实现
- 插件扩展点协议，例如 UI、Agent Tool、Send Middleware、LLM Provider、Message Renderer、Editor Extension
- 插件运行上下文，例如 `PluginContext`、`ToolContext`、`SendMessageContext`
- 插件之间必须共享的值类型，例如 `ChatMessage`、`StreamChunk`、`MessageRole`
- 插件注册和生命周期所需的轻量协议

不适合放入 `LumiCoreKit` 的内容：

- 具体 App 窗口和布局实现
- 具体 ViewModel、Store、Controller
- 具体插件业务逻辑
- 具体数据库、文件、网络、Git、GitHub 等功能实现
- 只服务某一个插件的专用模型

原则是：`LumiCoreKit` 应该是插件 SDK，而不是 Core 的搬家版。

### Plugin Package

每个插件 Package 专注实现自己的功能，并维护自己的单元测试。

推荐拆分为两个 target：

```text
PluginCore target
  - 纯业务逻辑
  - 尽量少依赖 SwiftUI/AppKit
  - 单元测试重点覆盖这里

Plugin target
  - 实现 SuperPlugin
  - 负责 UI 贡献
  - 负责 Agent Tool / Middleware / Provider 注册
  - 负责把 PluginCore 适配到 LumiCoreKit 扩展点
```

例如：

```text
GitPluginCore
  GitRepositoryService
  GitStatusParser
  GitDiffParser
  GitCommitService

GitPlugin
  GitPlugin: SuperPlugin
  GitStatusTool
  GitCommitTool
  GitStatusBarView
  GitCommitPanelView
```

这样大部分核心逻辑都能在 Package 内独立测试，App target 只负责最终集成。

## 依赖规则

推荐依赖方向：

```text
LumiApp
  → LumiCoreKit
  → Plugin Packages

Plugin Package
  → LumiCoreKit
  → 领域 Kit，例如 GitHubKit、DatabaseKit、ShellKit
```

禁止或尽量避免的依赖方向：

```text
Plugin Package → LumiApp/Core
LumiCoreKit  → LumiApp/Core
LumiCoreKit  → 具体插件 Package
Plugin Package → 另一个插件 Package 的实现细节
```

如果插件之间确实需要共享能力，应优先抽成独立领域 Package，而不是互相依赖插件实现。

## 插件注册

App 可以保留一个集中注册文件，例如：

```swift
enum BundledPluginRegistry {
    @MainActor
    static func plugins() -> [any SuperPlugin] {
        [
            GitPlugin.shared,
            GitHubPlugin.shared,
            RecentProjectsPlugin.shared,
        ]
    }
}
```

这样 App 明确知道自己打包了哪些插件，但不需要知道插件内部如何实现。

相比完全依赖 runtime 扫描，显式注册更利于 Package 化、测试、裁剪和排查启动问题。

## 迁移路径

### 1. 先稳定 LumiCoreKit

把 Core 中已经被插件使用的协议和值类型迁到 `LumiCoreKit`，并确保访问级别为 `public`。

重点包括：

- `SuperPlugin`
- `PluginCategory`
- `PluginContext`
- `ToolContext`
- `SendMessageContext`
- `SuperSendMiddleware`
- `SuperLLMProvider`
- `SuperMessageRenderer`
- `SubAgentDefinition`
- `ChatMessage`
- `MessageRole`
- `StreamChunk`

迁移期间允许 Core 中短期存在兼容代码，但最终应删除重复定义。

### 2. 让 Core 依赖 LumiCoreKit

Core 中所有插件协议和值类型引用都应切换为 `import LumiCoreKit`。

验收标准：

- Core 不再定义自己的 `SuperPlugin`
- Core 不再定义和 `LumiCoreKit` 重复的共享模型
- AppPluginVM 只聚合 `any SuperPlugin`

### 3. 选择一个插件作为样板

建议优先选择 GitPlugin 或 IdleTimePlugin。

GitPlugin 覆盖面更完整，适合作为最终模板：

- UI 贡献
- Status Bar
- Agent Tools
- 子 Agent 定义
- 核心业务逻辑

IdleTimePlugin 更轻，适合作为第一批低风险验证对象。

### 4. 拆出插件 Package

以 GitPlugin 为例：

```text
Packages/GitPlugin
  Package.swift
  Sources/GitPluginCore
  Sources/GitPlugin
  Tests/GitPluginCoreTests
  Tests/GitPluginTests
```

先把纯逻辑迁到 `GitPluginCore`，测试稳定后，再迁移 `SuperPlugin` 适配层和 UI。

### 5. App 注册插件 Package

App target 添加插件 Package 依赖，并在注册文件中引用插件实例。

验收标准：

- App 可以正常启动
- 插件可以被启用、禁用和显示
- 插件工具能被 Agent 聚合
- 插件 Package 的测试可以独立运行

## 风险与约束

### LumiCoreKit 变成新 Core

这是最大风险。

如果迁移时把 App 状态、窗口管理、具体业务服务都放进 `LumiCoreKit`，它会变成新的 Core，插件仍然无法独立。

规避方式：

- 只迁移插件边界所必需的协议和值类型
- 具体实现留在 Core、领域 Kit 或插件 Package
- 每次迁移前判断：这是插件 SDK 的公共契约，还是某个实现细节

### 插件仍然直接依赖 AgentToolKit 等底层 Kit

当前 `LumiCoreKit` 的部分 API 暴露了 `AgentToolKit` 类型，例如 `SuperAgentTool`。这会导致插件为了实现工具仍需直接 `import AgentToolKit`。

可接受的过渡方案：

- 插件 Package 依赖 `LumiCoreKit` 和少量领域 Kit
- 暂时允许依赖 `AgentToolKit`

长期优化方向：

- 将插件开发常用的工具协议 facade 收敛到 `LumiCoreKit`
- 或明确 `AgentToolKit` 是插件 SDK 的一部分，并在文档中承认它是稳定公共依赖

### UI 插件天然依赖 SwiftUI/AppKit

插件如果贡献 `AnyView`、菜单栏、状态栏、设置页，就不可避免依赖 SwiftUI/AppKit。

规避方式不是消除 UI 依赖，而是把 UI 适配层和核心逻辑拆开：

- `PluginCore` 尽量纯逻辑
- `Plugin` target 负责 SwiftUI/AppKit 集成

### Core 和 LumiCoreKit 双份类型并存

迁移过程中，Core 和 `LumiCoreKit` 中可能短期存在同名类型。

这只能作为过渡状态。长期并存会造成：

- 类型不兼容
- 扩展重复
- 测试和 App 集成使用不同类型
- 插件 Package 无法真正脱离 App

最终应统一到 `LumiCoreKit`。

## 验收标准

阶段性验收：

- `LumiCoreKit` 可以独立 `swift test`
- 至少一个插件 Package 可以独立 `swift test`
- 插件 Package 不依赖 `LumiApp/Core`
- App 通过注册文件加载插件 Package
- Core 中不再保留和 `LumiCoreKit` 重复的插件协议定义

最终验收：

- 新插件可以通过新建 Package 完成开发
- 插件核心逻辑可以在 Package 内完整单测
- App Core 只负责装配，不承载插件业务逻辑
- 插件之间通过 `LumiCoreKit` 或领域 Kit 协作，不通过 Core 间接耦合

## 推荐下一步

1. 以 `LumiCoreKit` 为准，清理 Core 中重复的插件协议和值类型
2. 明确 `AgentToolKit`、`LumiUI` 是否属于插件 SDK 的稳定公共依赖
3. 选择一个轻量插件做 Package 化试点
4. 再用 GitPlugin 做完整模板，覆盖 UI、工具、子 Agent 和单元测试

## 试点：PluginWebFetch

已新增 `Packages/PluginWebFetch` 作为第一批 package 化试点。Package、product 和 target 使用 `Plugin` 前缀；插件类型仍保留 `WebFetchPlugin`，用于表达插件在运行时的业务身份。

选择 `PluginWebFetch` 的原因：

- 没有 App UI 贡献，不依赖窗口 VM
- 只通过 `agentTools(context:)` 注册一个工具
- 核心网页抓取逻辑已经在 `WebFetchKit`
- 适合先验证插件适配层、Package 依赖和单元测试方式

当前结构：

```text
Packages/PluginWebFetch
  Package.swift
  Sources/PluginWebFetch
    Resources/WebFetch.xcstrings
    WebFetchPlugin.swift
    WebFetchTool.swift
  Tests/PluginWebFetchTests
    WebFetchPluginTests.swift
```

当前验证结果：

```bash
cd Packages/PluginWebFetch
swift test
```

结果：4 个测试通过。

插件自带的本地化资源也应该随 package 迁移。以 `PluginWebFetch` 为例，`WebFetch.xcstrings` 放在 package target 的 `Resources` 目录中，并在 `Package.swift` 中声明：

```swift
.target(
    name: "PluginWebFetch",
    dependencies: [
        .product(name: "LumiCoreKit", package: "LumiCoreKit"),
        .product(name: "WebFetchKit", package: "WebFetchKit"),
    ],
    path: "Sources/PluginWebFetch",
    resources: [
        .process("Resources")
    ]
)
```

package 内部本地化调用必须指定 `Bundle.module`：

```swift
String(localized: "Web Fetch", table: "WebFetch", bundle: .module)
```

不要继续依赖 main bundle，否则 package 独立测试时可能找不到翻译，App 集成后也容易和其它插件的同名 table 冲突。

这个试点也暴露了一个架构问题：即使 `PluginWebFetch` 只是 Agent Tool 插件，依赖 `LumiCoreKit` 时仍会一起构建 `LumiUI`、`LLMKit` 等较重依赖。后续可以考虑把 `LumiCoreKit` 拆成更细 target，例如：

```text
LumiPluginCore
  - SuperPlugin 基础协议
  - PluginCategory
  - ToolContext
  - Agent Tool / Middleware 基础扩展点

LumiPluginUI
  - SwiftUI / AppKit 相关扩展点
  - AnyView UI 贡献
  - LumiUI theme contribution

LumiPluginLLM
  - LLM Provider
  - Message Renderer
  - StreamChunk / provider bridge
```

下一步如果要把试点接入 App，需要：

1. 将 App target 添加对 `Packages/PluginWebFetch` library product 的依赖
2. 在 App 插件注册处引用 package 中的 `WebFetchPlugin.shared`
3. 移除或停用 `LumiApp/Plugins/WebFetchPlugin` 中的旧实现，避免重复插件注册
4. 跑 App 构建和工具聚合测试，确认 `web_fetch` 仍能被 Agent 发现
