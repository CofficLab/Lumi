# 插件 Capabilities 能力边界规范

> 本规范定义 Lumi 插件如何声明自己**消费外部能力**的最小边界。
> 参考兄弟项目 Cisum / GitOK 的同名机制，核心目的：让 View / ViewModel / Service / Tool
> 不再直接依赖 `any *Providing` 宽接口。

---

## 核心原则

**插件依赖的是「自己声明的窄能力」，不是「内核的宽 Provider」。**

一个插件对外界（内核 Provider、其他插件的 Provider）的所有依赖，都应收敛到本插件
`Capabilities/` 目录下的 `protocol XxxCapability` + `XxxCapabilityAdapter`。
View / ViewModel / Service / Tool 只面向该窄协议编程。

> 外部能力进入插件的唯一入口是**能力协议 + Adapter**（依赖收窄），
> 外部状态进入插件的唯一入口是**Observer**（状态收窄）。两者互补、不冲突：
> Observer 负责「状态怎么进来」，Capabilities 负责「接口怎么收窄」。

---

## 1. 目录位置

| 包结构 | 位置 |
|--------|------|
| 有包裹目录（`Sources/<PackageName>/`，Lumi 多数插件包） | `Sources/<PackageName>/Capabilities/` |
| 无包裹目录（`path: "."` + `sources: ["Sources"]`） | `Sources/Capabilities/` |

每个能力一个文件，文件名 = 主类型名，例如 `ProjectsProjectCapability.swift`。

目录与 `Observers/`、`ViewModels/`、`Views/` 平级。

---

## 2. 与 `Providers/` 的区别（关键，别混淆）

Lumi 中两个目录方向**相反**：

| 目录 | 方向 | 内容 | 例 |
|------|------|------|------|
| `Providers/` | **生产**：本插件向外**提供**能力 | 实现内核的 `*Providing` 协议 | `PluginStorage/Providers/StorageProvider.swift` |
| `Capabilities/` | **消费**：本插件向**内**索取能力 | 声明本插件**需要的**窄接口 + Adapter | `PluginProjects/Capabilities/ProjectsProjectCapability.swift` |

一句话：`Providers/` 是我给别人什么，`Capabilities/` 是我需要什么。

---

## 3. 标准写法

以 `PluginProjects` 为参考实现：

```swift
import Foundation
import ProviderProject

/// Projects 插件需要的最小项目能力边界。
///
/// ViewModel 通过该协议读写项目列表与当前项目，不直接持有
/// `ProjectProviding` 具体类型；Provider 的解析与适配由插件入口完成。
@MainActor
protocol ProjectsProjectCapability: AnyObject {
    /// 所有项目列表。
    var projects: [ProjectInfo] { get }

    /// 当前打开的项目。
    var currentProject: ProjectInfo? { get }

    /// 同步应用当前维护的完整项目列表。
    func synchronizeProjects(_ projects: [ProjectInfo])

    /// 打开项目。
    func openProject(at path: String, reason: ProjectChangeReason) async throws

    /// 关闭当前项目。
    func closeProject(reason: ProjectChangeReason) async
}

/// 将内核的 `ProjectProviding` 收窄为 Projects 插件的项目能力。
@MainActor
final class ProjectsProjectCapabilityAdapter: ProjectsProjectCapability {
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    var projects: [ProjectInfo] { project.projects }

    var currentProject: ProjectInfo? { project.currentProject }

    func synchronizeProjects(_ projects: [ProjectInfo]) {
        project.synchronizeProjects(projects)
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        try await project.openProject(at: path, reason: reason)
    }

    func closeProject(reason: ProjectChangeReason) async {
        await project.closeProject(reason: reason)
    }
}
```

### 命名规范

| 角色 | 命名 |
|------|------|
| 协议 | `<Plugin前缀><Domain>Capability`，如 `ProjectsProjectCapability`、`GitProjectCapability` |
| 适配器 | 协议名 + `Adapter`，如 `ProjectsProjectCapabilityAdapter` |
| 事件枚举 | `<Domain>Event`，如 `MessageSenderEvent` |
| 观察句柄 | `<Domain>ObserverHandle`，如 `TextInputObserverHandle` |

> 多个能力共用同一 Provider 时，前缀区分用途而非 Provider 本身
> （如 `MessageListMessageCapability` 与 `MessageListConversationCapability`）。
> 插件前缀可省略当包名已隐含唯一性时（如 `PluginProjects/Capabilities/ProjectCapability.swift`）。

### 可见性

| 场景 | 修饰符 |
|------|--------|
| 能力仅本插件内部消费 | `internal`（默认，不写修饰符） |
| 能力需被本包 `Tests` 使用 | `public` |
| 能力需被**其他插件**消费 | 不属于本机制 —— 应下沉为 `Provider*` / `Kit*` 包 |

---

## 4. 装配规则

Adapter 一律在插件入口的 `onBoot(kernel:)` 中创建并注入 ViewModel / View / Service。

```swift
@MainActor
public final class FooSuperPlugin: SuperPlugin {
    private var viewModel: FooViewModel?

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ProjectProviding")
            return
        }
        // 入口已 guard 到具体 Provider，直接构造 Adapter 注入业务层
        let viewModel = FooViewModel(
            projectCapability: FooProjectCapabilityAdapter(project: project)
        )
        self.viewModel = viewModel
        // Observer 仍使用完整 Provider 类型
        let observer = FooProviderObserver(project: project, viewModel: viewModel)
        self.observer = observer
        ...
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
    }
}
```

### ⚠️ 生命周期陷阱：Adapter 无人持有会静默失效

如果 Adapter 只是**临时创建后直接注入**，且没有任何强引用持有它，
Adapter 会随 `onBoot` 返回立即释放，消费方的 `weak` 全部落空（功能静默失效）。

```swift
// ❌ 错误：Adapter 无人持有；如果注入方用 weak 接收，功能永远不生效
let viewModel = MyViewModel(capability: MyCapabilityAdapter(project: project))

// ✅ 正确：入口显式强持有 Adapter，并在 onShutdown 释放
private var capability: MyProjectCapability?
...
let capability = MyProjectCapabilityAdapter(project: project)
self.capability = capability
let viewModel = MyViewModel(capability: capability)
```

判断标准：**如果消费方不持有 Adapter（或持有为 `weak`），入口必须持有。**
若消费方以强引用存进 ViewModel 且 ViewModel 被入口持有，Adapter 随 ViewModel 存活，可不强持。

### 与 Observer 的分工

| 层 | 职责 | 是否允许持有 Provider 协议 |
|----|------|------|
| 插件入口（`<Plugin>SuperPlugin.swift` / `<Plugin>Plugin.swift`) | 解析 Provider、装配 Adapter/Observer/ViewModel | **允许** |
| `Capabilities/` | 声明最小能力边界；Adapter 收窄 Provider | **允许**（仅 Adapter import Provider 包） |
| `Observers/` | 订阅 Provider 事件 → 更新 ViewModel | 允许（Observer 需要完整事件面） |
| ViewModel / View / Service / Tool | 只依赖能力协议 | **禁止直接持有 Provider 协议** |

> **Observer 不迁移到能力协议**：Observer 需要订阅完整 Provider 事件面，
> 保留 Provider 类型；能力协议只服务业务层（ViewModel / View / Service / Tool）。

### 时序要求

先 `guard` 到具体 Provider → 创建 Adapter → 同步一次初始快照 → 再安装 Observer 监听。
与现有 Observer 生命周期一致；能力协议本身不负责事件订阅。

---

## 5. 规则清单

1. **收窄优先**：能力协议只声明实际用到的成员，禁止把 Provider 整个协议照抄一遍。
   对比 `ProjectProviding` 有 14 个成员，`ProjectsProjectCapability` 只收窄 5 个。
2. **不泄漏句柄类型**：Provider 的 `*ObserverHandle` 与 `*ProvidingEvent`
   不应直接出现在能力协议里 —— 它们会把 Provider 包重新泄漏给消费方。
   需在能力文件内**内联定义**自己的事件枚举与句柄协议（见 `PluginConversationInput/Capabilities/ConversationInputCapability.swift`）：

   ```swift
   @MainActor
   protocol FooCapability: AnyObject {
       var value: Int { get }

       /// 插件自有事件，不泄漏 Provider 的事件类型
       enum ValueEvent { case changed(Int) }

       @discardableResult
       func addValueObserver(_ callback: @escaping (ValueEvent) -> Void) -> any ValueObserverHandle
   }

   protocol ValueObserverHandle: AnyObject { func cancel() }
   ```

   Adapter 内部负责把 `*ProvidingEvent` 映射为自有事件。
   若 Provider 事件类型已足够通用且消费方确实需要其完整面，
   可暂时透传，但应在文件注释中说明理由，并在 Provider 事件面变化时同步检查。

3. **禁止循环**：Adapter 可依赖 `Provider*` 包；Provider 包**不得**反向依赖插件包。
4. **`@MainActor`**：能力协议与 Adapter 默认标注 `@MainActor`（Lumi Provider 均为主线程语义）。
   若 ViewModel 在 `Task { @MainActor in }` 跨闭包使用能力，能力协议需精化 `Sendable`。
5. **日志**：Adapter 构造失败 / Provider 缺失统一在插件入口用 `Self.logger.error` 记录，
   Adapter 内部不重复打日志。

---

## 6. 是否该建 Capability（判断标准）

**应当建**：
- View / ViewModel / Service / Tool 直接持有 `any XxxProviding`
- 同一 Provider 在插件内有 2 处以上消费点
- 单元测试需要 mock 掉某个外部能力

**不必建**：
- 只有插件入口（`<Plugin>SuperPlugin.swift`）消费 Provider —— 入口本就是组装层，直接 `resolveProvider` 即可
- 只有单个 Observer 消费、且仅转发一次事件

**不适用**：
- 插件本身是某个 Provider 的**实现者**（如 `PluginAgentLoop` 实现 `AgentLoopProviding`）。
  持有其他 Provider 属于实现层依赖，收窄会限制实现能力，不适用本机制。

---

## 7. 惰性解析场景

当 Provider 的注册时机**晚于**本插件的 `onBoot`（跨插件 boot 顺序不确定），
不要在插件入口把 Provider **快照**进 Adapter —— 快照会永久失效。

正确做法：让 Adapter 内部持**惰性解析闭包**，每次调用都重新 `resolveProvider`：

```swift
@MainActor
public final class XxxCapabilityAdapter: XxxCapability {
    private let resolve: @MainActor @Sendable () -> (any XxxProviding)?

    public init(resolve: @escaping @MainActor @Sendable () -> (any XxxProviding)?) {
        self.resolve = resolve
    }

    private var provider: (any XxxProviding)? { resolve() }
    public var value: Int { provider?.value ?? 0 }
}
```

这样「仓库不可用」的判断也要跟着改 —— 原代码靠**闭包返回 nil** 判断，
现在闭包被收进能力内部，应改判能力的 `isAvailable` / 空值语义。

Lumi 现有的 Scene 能力由入口在 `onBoot` 中 `guard` 到 `SceneProviding` 后构造，属于**快照式**；
若调整 boot 顺序导致启动期拿不到 Scene，需改用本节的惰性解析写法。

---

## 8. 渐进迁移

本规范**不要求**一次性改造全部插件。新增或重构插件时遵守；
既有插件在触及相关文件时顺手迁移即可。

**已完成迁移**（可作为参考实现）：

- Phase 1（试点）：`PluginProjects`、`PluginProjectFiles`、`PluginEditorPreview`
- Phase 2：`PluginGit`、`PluginTerminal`

其余插件若仍存在「非入口文件直接依赖 `any *Providing`」，在触及时顺手迁移。

---

## 检查清单

新增/改造插件时，确认：

- [ ] View / ViewModel / Service / Tool 不直接持有 `any *Providing`
- [ ] 能力协议只声明用到的成员，未照抄 Provider 全量接口
- [ ] 能力文件放在 `Capabilities/`（而非 `Providers/`）
- [ ] Adapter 在插件入口 `onBoot` 中创建并注入
- [ ] **Adapter 的生命周期有明确所有者**（入口持有，或被入口持有的 ViewModel 强引用）
- [ ] 优先内联自有事件枚举与句柄协议，未泄漏 Provider 的 `*ProvidingEvent` / `*ObserverHandle`
- [ ] 命名符合 `<Plugin前缀><Domain>Capability` / `Adapter`
- [ ] 可见性正确（内部消费 `internal`，跨插件共享下沉为 `Provider*` / `Kit*`）
- [ ] 能力协议与 Adapter 标注 `@MainActor`

---

## 相关规范

- [插件包目录结构规范](./plugin-package-structure.md) — `Sources/` 分层与包裹目录
- [插件目录结构规范](./plugin-directory-rules.md) — `LumiApp/Plugins/` 下的 monorepo 插件结构
- [插件国际化规范](./plugin-i18n-rules.md) — xcstrings 文件管理
- [Swift 日志记录规范](./swift-log.md) — Swift 日志记录标准
- [Commit 规范](./commit-convention.md) — Git 提交信息约定