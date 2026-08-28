# Lumi 编辑器内核与插件体系完整重构方案

> 状态：目标架构与实施蓝图  
> 适用范围：`KernelLumi`、`EditorKernel`、`EditorService`、`EditorSource`、`EditorTextView`、`EditorLanguageRuntime`、所有编辑器及开发工具插件  
> 当前架构说明：[`editor-architecture.md`](./editor-architecture.md)  
> 原则：本文描述最终目标和迁移方法；迁移期间不得以破坏当前可用编辑体验为代价一次性重写。

## 1. 文档目的

本文给出 Lumi 从“具备较多编辑器底层能力，但 Kernel 契约和正式 UI 尚未闭环”的现状，演进为完整、稳定、可扩展代码编辑工作台的实施方案。

开发者应能依据本文完成以下工作：

1. 重构 Kernel 对外编辑器契约。
2. 建立唯一的 Editor Host 和稳定的插件贡献生命周期。
3. 迁移现有文件、标签、搜索、诊断、符号、引用、预览和语言插件。
4. 接通补全、Hover、签名帮助、跳转、重构、格式化、诊断等标准语言功能。
5. 增加 Diff/Merge、SCM、Task、Debug、Testing、Remote、Workspace Trust 等工作台能力。
6. 完成 Lumi 特有的编辑器与 Agent/Chat 深度集成。
7. 通过依赖检查、契约测试、性能测试和真实 UI 验证保证架构不会重新退化。

本文不是单次提交计划。它是多阶段目标架构；每个阶段都必须保持可编译、可运行、可回滚。

## 2. 当前基线与根因

### 2.1 已有基础

当前仓库已经具备大量可复用实现：

- `EditorKernel`：选择集、多光标、查找替换、保存、导航、折叠、命令、Workspace Edit、LSP 请求策略和大文件策略。
- `EditorService`：文档、Session、标签、配置、主题、LSP、面板和运行时状态门面。
- `EditorSource` / `EditorTextView`：原生 macOS 文本输入、布局、光标、滚动、查找、建议列表、gutter、minimap、折叠和 Tree-sitter 接入。
- `EditorLanguageRuntime`：语言识别、grammar 和查询资源管理。
- 插件目录中已有 Problems、Search、Outline、References、Call Hierarchy、Symbols、Sticky Symbol Bar、Swift、Preview、Git、Terminal 等实现或原型。

因此本方案不是另起炉灶，而是重新确定公开边界、状态所有权和装配方式。

### 2.2 当前根因

当前主要问题不是缺少所有实现，而是以下边界没有闭环：

1. `KernelLumi.EditorProviding` 只公开视图、文件路径和主题等少量能力。
2. `EditorExtensionRegistrar` 只公开语言、grammar、高亮，补全、Hover、Code Action 等仍在 `EditorService/Proto`。
3. 多个功能插件直接依赖具体 `EditorService`，没有真正做到“插件只面对 Kernel”。
4. `EditorKernelPlugin` 与 `EditorProviderPlugin` 分开装配，存在启动顺序约束和具体服务穿透。
5. `ProjectProviding` 与 Editor Session 同时维护当前文件和打开文件，存在双状态源。
6. 正式 `EditorSurfaceView` 只接入基础协调器，高级 Overlay 和交互管线没有完整装配。
7. 扩展注册依赖全量 `reset()` 和回放，不能原子替换单个插件贡献，也难以正确取消旧异步任务。
8. 语言、LSP 和 UI 贡献同时混在一个注册表中，功能归属和解析策略不清晰。
9. 多窗口、工作区信任、插件权限、版本兼容、遥测和性能预算没有成为契约的一部分。

## 3. 目标与非目标

### 3.1 目标

- 插件只能通过 `KernelLumi` 编辑器契约访问编辑器。
- 除 Editor Host 外，插件不能导入 `EditorService`、`EditorSource`、`EditorTextView` 或 `EditorKernel`。
- Kernel 中只出现中立、稳定、`Sendable` 的值类型和能力协议。
- 编辑器核心状态只有一个事实源。
- 所有插件贡献都可按插件原子安装、替换、撤回和取消。
- 标准语言功能使用统一 UI，插件提供数据而非各画一套交互。
- 能力不存在、插件禁用、服务器崩溃或文件过大时均可优雅降级。
- 支持未来多窗口、多工作区、Remote 和第三方插件，不要求再次重构公开协议。

### 3.2 非目标

- 第一阶段不替换 `EditorTextView` 渲染引擎。
- 第一阶段不一次性删除现有 `EditorService`。
- 不要求所有 VS Code 功能在同一个版本完成。
- 不把所有实现下沉到 Kernel；Kernel 只声明能力、数据和规则。
- 不允许为了“插件化”把高频文本存储复制到每个插件。

## 4. 核心设计原则

### 4.1 三类契约，一个宿主

编辑器 API 分为三类：

1. **Host Capability**：文档、Session、选择、事务、导航、命令和配置。每个编辑器作用域只有一个实现。
2. **Feature Contribution**：补全、诊断、格式化、语法、调试器、测试提供器等。允许多个插件实现。
3. **UI Contribution**：Toolbar、Status、Panel、Context Menu、自定义 Editor。标准语言 Overlay 不属于任意 UI，由 Host 统一绘制。

唯一的 `EditorHostPlugin` 使用 `EditorService` 实现 Host Capability，并装配 Feature/UI Contribution。

### 4.2 Kernel 中不泄露实现类型

以下类型禁止出现在 `KernelLumi` 编辑器公开 API：

- `NSTextStorage`、`NSTextView`、`NSView`
- `EditorState`、`EditorSession`、`SourceEditorState`
- `TextViewController`
- Tree-sitter `Language` 或 `OpaquePointer`
- `LanguageServerProtocol` 包中的类型
- 某个插件定义的 ViewModel 或 Service

插件读取不可变 Snapshot，修改通过带 revision 的事务提交。

### 4.3 单一状态源

- Workspace/Project：拥有项目根、工作区文件夹和工作区身份。
- Editor：拥有打开文档、当前文档、Session、标签、脏状态、选择和导航历史。
- File Tree：只展示文件系统状态和 Editor 高亮状态。
- Tab Strip：只展示 Editor Session 状态。
- Breadcrumb：只展示 Editor 当前文档和符号状态。

`ProjectProviding.currentFileURL/openFileURLs` 最终移除或变为只读兼容映射，不再写入独立状态。

### 4.4 值类型跨边界，可变对象留在 Host

- Kernel DTO 默认 `Sendable`、`Equatable`；有稳定身份的类型实现 `Identifiable`。
- 可变 Buffer、Parser、Language Client、Text View 和 Undo Manager 留在 Host 或 Provider 内部。
- 任何异步结果都携带 document revision、provider generation 或 request ID。

### 4.5 能力缺失是正常状态

所有消费者必须处理：

- 没有 Provider
- Provider 暂不可用
- 工作区未信任
- 大文件模式禁用
- 请求取消
- 文档 revision 已过期
- 插件被禁用
- Language Server 重启

不得用强制解包或默认假设某个语言插件存在。

## 5. 最终模块架构

```text
┌─────────────────────────────────────────────────────────────────┐
│ LumiPlugin / Feature Plugins                                    │
│ Languages · IntelliSense · Search · Problems · SCM · Debug ...  │
│ 只依赖 KernelLumi（UI 插件可额外依赖 LumiUI）                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │ contribution bundles / commands
┌──────────────────────────────▼──────────────────────────────────┐
│ KernelLumi Editor Contracts                                    │
│ Models · Host Capabilities · Feature APIs · UI Contributions   │
│ Lifecycle · Resolution Rules · Context Keys · Permissions      │
└──────────────────────────────┬──────────────────────────────────┘
                               │ implements / adapts
┌──────────────────────────────▼──────────────────────────────────┐
│ EditorHostPlugin                                               │
│ creates EditorService · registers Kernel services              │
│ owns contribution registry · builds editor surface             │
└───────────────┬───────────────────────────────┬─────────────────┘
                │                               │
┌───────────────▼──────────────┐  ┌────────────▼─────────────────┐
│ EditorService / EditorSource │  │ EditorKernel                 │
│ runtime state and native UI  │  │ pure domain models/policies  │
└───────────────┬──────────────┘  └──────────────────────────────┘
                │
┌───────────────▼────────────────────────────────────────────────┐
│ EditorTextView / EditorLanguageRuntime                         │
│ native text rendering and engine-specific adapters             │
└────────────────────────────────────────────────────────────────┘
```

## 6. 依赖矩阵

| 模块 | 可以依赖 | 禁止依赖 |
|---|---|---|
| `KernelLumi` | Foundation、Combine、必要的 `LumiUI` 中立 UI 类型 | EditorService、EditorSource、EditorKernel、插件、LSP 库 |
| `EditorKernel` | Foundation、中立协议库；当前过渡期可保留 LSP 依赖 | SwiftUI、AppKit UI、EditorService、插件 |
| `EditorService` | KernelLumi、EditorKernel、EditorSource、基础编辑器包 | 任何插件 |
| `EditorHostPlugin` | KernelLumi、EditorService、LumiUI | 其他插件 |
| 语言/功能插件 | KernelLumi、自身需要的 parser/server SDK | EditorService、EditorSource、EditorTextView、其他插件 |
| UI 插件 | KernelLumi、LumiUI | EditorService、其他插件 |

CI 必须扫描 `Package.swift` 和 import，阻止依赖规则回退。

## 7. Kernel 中立领域模型

### 7.1 强类型标识

新增以下 `RawRepresentable`、`Hashable`、`Sendable` 标识：

```swift
public struct EditorWindowID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorWorkspaceID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorGroupID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorSessionID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorDocumentID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorRequestID: RawRepresentable, Hashable, Sendable { public let rawValue: UUID }
public struct EditorCommandID: RawRepresentable, Hashable, Sendable { public let rawValue: String }
```

不要继续让裸 `UUID` 同时表示窗口、Session 和文档。

### 7.2 位置、范围与文档 URI

```swift
public struct EditorPosition: Equatable, Hashable, Sendable {
    public var line: Int       // zero-based
    public var character: Int  // UTF-16 offset
}

public struct EditorRange: Equatable, Hashable, Sendable {
    public var start: EditorPosition
    public var end: EditorPosition
}

public struct EditorLocation: Equatable, Hashable, Sendable {
    public var uri: URL
    public var range: EditorRange
}
```

跨插件契约统一使用 zero-based UTF-16，与 LSP 和 Cocoa 字符索引适配成本最低。UI 如需显示 one-based 行列，只在展示层转换。

### 7.3 文档 Snapshot

```swift
public struct EditorDocumentSnapshot: Equatable, Sendable {
    public let id: EditorDocumentID
    public let uri: URL
    public let languageID: String
    public let revision: UInt64
    public let text: String
    public let encoding: EditorTextEncoding
    public let lineEnding: EditorLineEnding
    public let isDirty: Bool
    public let isReadOnly: Bool
    public let largeFileMode: EditorLargeFileMode
}
```

完整文本 Snapshot 只按需获取。常规状态 Publisher 使用不含 `text` 的 `EditorDocumentSummary`，避免每次按键复制整份文档。

### 7.4 编辑事务

```swift
public struct EditorTextEdit: Equatable, Sendable {
    public let range: EditorRange
    public let newText: String
}

public struct EditorWorkspaceEdit: Equatable, Sendable {
    public let documentEdits: [EditorDocumentEdit]
    public let fileOperations: [EditorFileOperation]
}

public struct EditorEditOptions: Sendable {
    public let undoStopBefore: Bool
    public let undoStopAfter: Bool
    public let saveAfterApplying: Bool
    public let label: String
}
```

Host 必须：

- 验证 edit 不重叠或按明确规则排序。
- 验证 expected revision。
- 在应用 Workspace Edit 前生成预览摘要。
- 文件创建、重命名、删除通过 Workspace 权限校验。
- 支持事务失败回滚或明确报告部分失败。

## 8. Host Capability 设计

### 8.1 总入口

```swift
@MainActor
public protocol EditorProviding: AnyObject {
    var scope: EditorScope { get }
    var documents: any EditorDocumentProviding { get }
    var sessions: any EditorSessionProviding { get }
    var selections: any EditorSelectionProviding { get }
    var navigation: any EditorNavigationProviding { get }
    var commands: any EditorCommandProviding { get }
    var configuration: any EditorConfigurationProviding { get }
    var extensions: any EditorExtensionHosting { get }
    var surface: any EditorSurfaceProviding { get }
}
```

`EditorScope` 至少包含 window ID 和 workspace ID。即使当前只有单窗口，也必须从第一版契约开始携带作用域，避免未来用全局单例重构。

### 8.2 文档能力

```swift
@MainActor
public protocol EditorDocumentProviding: AnyObject {
    var activeDocument: EditorDocumentSummary? { get }
    var statePublisher: AnyPublisher<EditorDocumentState, Never> { get }

    func snapshot(documentID: EditorDocumentID) async throws -> EditorDocumentSnapshot
    func open(_ request: EditorOpenRequest) async throws -> EditorSessionID
    func save(documentID: EditorDocumentID, reason: EditorSaveReason) async throws
    func saveAll(reason: EditorSaveReason) async throws
    func revert(documentID: EditorDocumentID) async throws
    func reload(documentID: EditorDocumentID) async throws
    func loadFullDocument(documentID: EditorDocumentID) async throws
    func apply(
        _ edit: EditorWorkspaceEdit,
        expectedRevisions: [EditorDocumentID: UInt64],
        options: EditorEditOptions
    ) async throws -> EditorWorkspaceEditResult
}
```

### 8.3 Session、标签和 Editor Group

```swift
@MainActor
public protocol EditorSessionProviding: AnyObject {
    var state: EditorWorkbenchState { get }
    var statePublisher: AnyPublisher<EditorWorkbenchState, Never> { get }

    func activate(sessionID: EditorSessionID)
    func close(sessionID: EditorSessionID, policy: EditorClosePolicy) async throws
    func closeOthers(keeping sessionID: EditorSessionID) async throws
    func closeToLeft(of sessionID: EditorSessionID) async throws
    func closeToRight(of sessionID: EditorSessionID) async throws
    func setPinned(_ pinned: Bool, sessionID: EditorSessionID)
    func move(sessionID: EditorSessionID, before: EditorSessionID?, in groupID: EditorGroupID)
    func split(sessionID: EditorSessionID, direction: EditorSplitDirection) -> EditorGroupID
    func move(sessionID: EditorSessionID, to groupID: EditorGroupID)
    func navigateBack()
    func navigateForward()
}
```

`EditorWorkbenchState` 包含 groups、sessions、active group、active session。第一阶段可只实现一个 group，但 DTO 和命令从一开始支持多个 group。

### 8.4 选择能力

```swift
@MainActor
public protocol EditorSelectionProviding: AnyObject {
    var snapshot: EditorSelectionSnapshot { get }
    var statePublisher: AnyPublisher<EditorSelectionSnapshot, Never> { get }

    func setSelections(_ selections: [EditorSelection], reveal: EditorRevealPolicy)
    func selectedText() async -> String?
    func addCursor(at position: EditorPosition)
    func addNextOccurrence()
    func addAllOccurrences()
    func clearSecondaryCursors()
}
```

选择状态是高频状态，Provider 自己发布精准事件；Kernel 不转发全局 `objectWillChange`。只有编辑器相关视图直接订阅。

### 8.5 导航能力

```swift
@MainActor
public protocol EditorNavigationProviding: AnyObject {
    func open(_ location: EditorLocation, options: EditorOpenOptions)
    func reveal(_ range: EditorRange, in documentID: EditorDocumentID)
    func peek(_ locations: [EditorLocation], origin: EditorLocation?)
    func goBack()
    func goForward()
}
```

Problems、References、Search、Outline、Call Hierarchy 都调用同一导航协议。

### 8.6 命令能力

```swift
@MainActor
public protocol EditorCommandProviding: AnyObject {
    func execute(_ id: EditorCommandID, arguments: [EditorCommandArgument]) async throws
    func presentation(matching query: String, context: EditorCommandContext) -> EditorCommandPresentation
    func keybinding(for commandID: EditorCommandID, context: EditorCommandContext) -> EditorKeybinding?
}
```

所有菜单、Toolbar、右键菜单、快捷键和 Agent 编辑操作最终调用命令或事务，不直接调用某个 ViewModel。

### 8.7 配置能力

配置必须支持：

- User scope
- Workspace scope
- Language scope
- Profile scope（后续启用）
- 默认值、插件默认值、用户值、工作区值、语言覆盖的明确优先级
- 配置 schema、类型校验、枚举、范围、弃用与迁移

```swift
public protocol EditorConfigurationProviding: AnyObject {
    var snapshot: EditorConfigurationSnapshot { get }
    var statePublisher: AnyPublisher<EditorConfigurationSnapshot, Never> { get }

    func resolvedValue(for key: EditorSettingKey, context: EditorConfigurationContext) -> EditorSettingValue?
    func update(_ value: EditorSettingValue?, for key: EditorSettingKey, scope: EditorSettingScope) throws
}
```

### 8.8 并发与观察模型

公开协议必须统一遵守以下并发规则：

- Host 状态变更、Bundle 安装、命令分发和 UI 状态发布在 `@MainActor` 完成。
- 文档 Snapshot、请求 DTO 和 Provider 返回值必须 `Sendable`。
- Syntax、LSP、Search、Task、Debug、Testing Provider 使用 actor 或真正的 `Sendable` 实现，在后台执行耗时工作。
- Provider 不得通过 `MainActor.assumeIsolated` 包裹耗时操作来压制编译器检查。
- 文件 IO、进程启动、解析和索引不得阻塞主线程。
- 所有 async API 遵循 Swift Task cancellation；额外 cancellation handle 只用于外部进程或协议请求。

状态观察规则：

- Kernel 能力协议不继承 `ObservableObject`，避免 existential 约束和整个 Kernel 重绘。
- `statePublisher` 具有 `CurrentValue` 语义：新订阅者先收到当前 Snapshot，再接收后续变化。
- UI adapter 在主线程订阅，并只观察自己需要的子服务。
- 文档内容变化事件携带 revision 和增量 change，不在每次键入时广播完整文本。
- Selection、viewport、streaming diagnostics 等高频状态禁止经 Kernel 全局 `objectWillChange` 广播；由对应 Provider 或局部 ViewModel 发布。
- 状态 Publisher 不以 failure 结束；操作错误由 async throws 或结果对象返回。

### 8.9 State 与 Event 分离

- State 表示可随时读取和重放的当前事实，如 active document、tabs、diagnostics snapshot。
- Event 表示一次性动作，如 save completed、provider crashed、external conflict detected。
- UI 恢复时依赖 State，不依赖历史 Event。
- Event 必须带 scope 和稳定 ID，消费者自行去重。
- 不使用 NotificationCenter 传递新的编辑器领域事件；仅在兼容旧消费者期间由 adapter 转发。

## 9. Feature Contribution 体系

### 9.1 贡献包

插件不再直接操作具体注册表，而是创建完整贡献包：

```swift
public struct EditorContributionBundle {
    public let pluginID: String
    public let apiVersion: EditorPluginAPIVersion
    public let generation: UInt64
    public let languages: [EditorLanguageContribution]
    public let providers: [any EditorFeatureProvider]
    public let commands: [EditorCommandContribution]
    public let settings: [EditorSettingContribution]
    public let ui: [EditorUIContribution]
}
```

`LumiPlugin` 的唯一编辑器贡献入口改为：

```swift
@MainActor
public protocol LumiPlugin: AnyObject {
    // 省略其他既有贡献点
    func editorContributionBundle(kernel: KernelLumi) async throws -> EditorContributionBundle?
}
```

默认实现返回 `nil`。这一个入口最终替换现有的：

- `registerEditorExtensions(into: AnyObject, kernel:)`
- `configureEditorRuntime(kernel:)`
- `editorPlugins(kernel:)`

Bundle 构建阶段只能创建描述符和 Provider，不应启动 Language Server、watcher 或后台任务；资源启动由 Host 在 Bundle 原子安装成功后执行。这样构建失败不会留下运行资源。

Host API：

```swift
public protocol EditorExtensionHosting: AnyObject {
    func replaceBundle(for pluginID: String, with bundle: EditorContributionBundle?) async throws
    func availability(for feature: EditorFeature, document: EditorDocumentSummary) -> EditorFeatureAvailability
}
```

### 9.2 PluginManager 装配算法

启动流程：

1. `EditorHostPlugin` 作为 always-on 基础设施先完成 `onBoot`，注册空的 Editor Host。
2. 所有插件完成普通 `onBoot/onReady` 后，PluginManager 只向已启用且 API 兼容的插件请求 Bundle。
3. PluginManager 为每个 Bundle 盖上可信的 plugin ID、启用 generation 和权限上下文，不能信任插件自己伪造归属。
4. Host 按插件维度原子安装 Bundle；一个插件失败只影响自己，不回滚其他已成功插件。
5. 全部安装完成后 Host 统一重新解析 active document 能力并发布 availability。

运行时启用：构建新 Bundle → 校验权限/版本 → 原子安装 → 激活资源 → 发布一次变化。

运行时禁用：先阻止新请求 → 取消该 generation → 撤回 Bundle → 关闭资源 → 发布一次变化。撤回不应通过全量重放其他插件完成。

插件更新：新 Bundle 校验成功后 swap generation；失败时旧 Bundle 继续运行，并向插件管理 UI 报告更新失败。

Editor Host 不存在时，PluginManager 暂存“待安装插件 ID”，而不是持有 Provider 实例；Host 恢复后重新向插件请求 Bundle。最终装配完成后应通过启动顺序保证 Host 始终先存在，暂存逻辑只用于容错。

### 9.3 生命周期

每个 Bundle 遵守以下事务语义：

1. 校验 API version、重复 ID、依赖、选择器和权限。
2. 在临时 registry 中构建新状态。
3. 校验成功后一次性切换 generation。
4. 取消旧 generation 的所有请求和后台任务。
5. 关闭不再使用的 Language Server、parser session、watcher 和进程。
6. 发布一次 registry changed 事件。
7. 失败时保留旧 Bundle，不允许出现半注册状态。

不再使用全局 `reset()` 清空所有贡献。

### 9.4 Provider 基协议

```swift
public protocol EditorFeatureProvider: AnyObject, Sendable {
    var id: String { get }
    var selector: EditorDocumentSelector { get }
    var priority: Int { get }
    var requiredTrust: EditorWorkspaceTrustRequirement { get }
}
```

`EditorDocumentSelector` 支持：

- language ID
- URL scheme
- 文件名 glob
- 文件扩展名
- workspace folder 类型
- 是否要求本地文件
- `when` 上下文表达式

### 9.5 解析策略

| 能力 | 默认策略 |
|---|---|
| Completion | 所有匹配 Provider 并发执行，合并、去重、排序 |
| Hover | 聚合多个 Provider，按 section 展示 |
| Signature Help | 最高优先级成功结果 |
| Definition/References | 合并 Location 并去重 |
| Rename | 最高优先级可用 Provider |
| Formatting | 用户显式选择或最高优先级 Provider |
| Code Action | 合并，按 kind、preferred、priority 排序 |
| Diagnostics | 按 source 聚合，不同 source 不相互覆盖 |
| Semantic Tokens | 一个主 Provider，可叠加独立 Decoration |
| Inlay Hints | 合并并按位置稳定排序 |
| Document Symbols | 一个主 Provider，失败时回退 Tree-sitter |
| Workspace Symbols | 多 Provider 合并 |
| Call Hierarchy | 选择能 prepare 当前 symbol 的 Provider |
| Syntax | 每个 language 一个主 Provider |

所有聚合算法写在 `EditorKernel` 或 Host 的中立 resolver 中，并有确定性测试。

## 10. 标准语言功能协议

Kernel 至少提供以下协议族：

- `EditorCompletionProvider`
- `EditorHoverProvider`
- `EditorSignatureHelpProvider`
- `EditorDefinitionProvider`
- `EditorDeclarationProvider`
- `EditorTypeDefinitionProvider`
- `EditorImplementationProvider`
- `EditorReferenceProvider`
- `EditorRenameProvider`
- `EditorCodeActionProvider`
- `EditorFormattingProvider`
- `EditorDocumentSymbolProvider`
- `EditorWorkspaceSymbolProvider`
- `EditorCallHierarchyProvider`
- `EditorFoldingProvider`
- `EditorInlayHintProvider`
- `EditorSemanticTokenProvider`
- `EditorDiagnosticProvider`
- `EditorDocumentHighlightProvider`
- `EditorLinkProvider`
- `EditorColorProvider`

示例：

```swift
public protocol EditorCompletionProvider: EditorFeatureProvider {
    var triggerCharacters: Set<Character> { get }
    func completions(for request: EditorCompletionRequest) async throws -> EditorCompletionList
    func resolve(_ item: EditorCompletionItem, request: EditorResolveRequest) async throws -> EditorCompletionItem
}

public protocol EditorRenameProvider: EditorFeatureProvider {
    func prepareRename(_ request: EditorPositionRequest) async throws -> EditorRenamePreparation?
    func rename(_ request: EditorRenameRequest) async throws -> EditorWorkspaceEdit
}
```

请求统一包含：scope、document ID、URI、language ID、revision、position/range、request ID、cancellation token 和触发原因。

## 11. Syntax 与高亮重构

### 11.1 最终目标

Kernel 不暴露 Tree-sitter 指针。插件内部可使用任意 parser，向 Host 返回中立 token：

```swift
public protocol EditorSyntaxProvider: EditorFeatureProvider {
    func makeSession(for document: EditorDocumentSnapshot) async throws -> any EditorSyntaxSession
}

public protocol EditorSyntaxSession: AnyObject, Sendable {
    func apply(_ changes: [EditorContentChange], revision: UInt64) async
    func highlights(in range: EditorRange, revision: UInt64) async throws -> [EditorSyntaxToken]
    func foldingRanges(revision: UInt64) async throws -> [EditorFoldingRange]
    func symbols(revision: UInt64) async throws -> [EditorDocumentSymbol]
    func close() async
}
```

### 11.2 迁移策略

为避免一次性重写高亮管线：

1. 保留现有 Tree-sitter 适配器，重命名为 `LegacyTreeSitterGrammarAdapter`。
2. 先将语言元数据和资源归属迁入 Bundle。
3. Editor Host 在内部把 Legacy Provider 适配到当前 `LanguageRegistry`。
4. 新语言插件优先使用中立 Syntax Session API。
5. 所有语言迁移后删除 Kernel 中 `OpaquePointer` 和 engine-specific API。

## 12. LSP 架构

### 12.1 分层

```text
Language Plugin
  └─ contributes EditorLanguageServerFactory / language configuration

EditorHostPlugin
  └─ LSP lifecycle host: start · stop · restart · document sync · cancellation

LSP Adapter
  └─ maps raw LanguageServerProtocol types to Kernel editor DTOs
```

### 12.2 Language Server Factory

```swift
public protocol EditorLanguageServerFactory: EditorFeatureProvider {
    func configuration(for context: EditorLanguageServerContext) async throws -> EditorLanguageServerConfiguration
}
```

Configuration 描述 executable、arguments、environment、workspace folders、initialization options 和 capability policy，但启动进程由 Host 完成。插件不能偷偷使用全局静态 `LSPConfig`。

### 12.3 生命周期要求

- 按 workspace + language + configuration identity 复用 Server。
- 文档 open/change/save/close 顺序确定。
- 增量 change 携带 revision。
- Server crash 有指数退避和用户可见状态。
- Workspace 切换后关闭旧 Server。
- 插件禁用后关闭其 Server。
- Workspace 未信任时禁止自动启动可执行文件。
- 所有请求支持取消、超时和 stale result 丢弃。
- 日志进入统一 Output Channel，而不是直接散落到 Console。

## 13. UI 与 Editor Surface

### 13.1 标准 Surface 由 Host 统一组装

最终 `EditorSurfaceView` 必须包含：

```text
EditorGroup
├─ Tab Strip
├─ Breadcrumb / Sticky Symbols
├─ Text Surface
│  ├─ TextView
│  ├─ Gutter Decorations
│  ├─ Diagnostics Squiggles
│  ├─ Semantic/Document Highlights
│  ├─ Inlay Hints
│  ├─ Completion Popup
│  ├─ Hover
│  ├─ Signature Help
│  ├─ Rename Input
│  ├─ Code Action Indicator/Menu
│  ├─ Peek View
│  └─ Inline Chat / Proposed Edits
└─ Editor Status Area
```

标准语言功能只由 Host 绘制。Provider 返回数据，不返回任意 SwiftUI View。

### 13.2 自定义 UI 贡献

允许以下中立 UI 贡献：

- `EditorToolbarContribution`
- `EditorStatusContribution`
- `EditorPanelContribution`
- `EditorContextMenuContribution`
- `EditorGutterDecorationProvider`
- `EditorOverviewRulerProvider`
- `EditorCustomDocumentProvider`

自定义 View 使用 `AnyView` 时必须位于 KernelLumi 的 UI 契约分区，不能混入纯文本/语言协议。

### 13.3 Context Key 与 when 条件

命令、菜单、快捷键和 UI 可见性统一使用 Context Key：

- `editorFocus`
- `editorHasSelection`
- `editorIsReadOnly`
- `editorLanguageID`
- `editorHasMultipleSelections`
- `editorHasDiagnostics`
- `editorCanRename`
- `editorWorkspaceTrusted`
- `editorLargeFileMode`
- `resourceScheme`

支持 `==`、`!=`、`&&`、`||`、`!`、`in` 等有限表达式。解析器属于 `EditorKernel`，禁止插件执行任意表达式代码。

## 14. Command、快捷键和菜单

### 14.1 命令是所有操作的统一入口

核心命令包括：

- 文件：open、save、saveAll、revert、close
- 标签：next、previous、pin、closeOthers、split
- 编辑：undo、redo、format、organizeImports、comment、indent
- 选择：addCursor、nextOccurrence、allOccurrences
- 导航：definition、references、implementation、back、forward
- 重构：rename、codeAction、refactor
- 面板：problems、search、outline、references、terminal
- 工作台：commandPalette、quickOpen、settings

### 14.2 快捷键解析

- Keybinding 是插件贡献或用户配置，不写死在 View。
- 多段快捷键支持 chord。
- Context Key 决定是否生效。
- 冲突按用户覆盖、插件 priority、注册顺序确定性解析。
- 提供可搜索、可修改、可恢复默认的快捷键 UI。

## 15. 完整编辑功能规划

### 15.1 基础编辑

- Unicode/IME 正确输入
- 多光标和列选择
- Undo/Redo 与事务标签
- 自动缩进、括号配对、注释切换
- Find/Replace、正则、大小写、全词
- 文件编码和行尾格式
- Auto Save、Hot Exit、外部文件冲突
- 空白字符、控制字符、缩进提示线
- 大文件模式和二进制文件降级
- 折叠、minimap、overview ruler

### 15.2 Workbench

- Preview tab、Pinned tab、Dirty indicator
- MRU 切换
- 多 Editor Group
- 横向/纵向 Split
- 拖拽标签跨 Group
- 同一文档多视图但共享 Buffer
- 会话恢复和未保存内容恢复
- Breadcrumb、Sticky Symbol、Outline

### 15.3 IntelliSense 与导航

- Completion、resolve、snippet、documentation
- Signature Help
- Hover 和可点击链接
- Definition/Declaration/Type Definition/Implementation
- References 和 Peek
- Document/Workspace Symbols
- Rename、Code Action、Refactor Preview
- Inlay Hint、Semantic Token、Document Highlight

### 15.4 Search 与 Problems

- 当前文件 Find/Replace
- Workspace Search/Replace
- include/exclude、ignore files、regex
- 搜索结果分组、预览、批量替换和撤销
- Problems 按文件、severity、source 分组
- 诊断导航、Quick Fix、状态栏计数

### 15.5 Diff 与 Merge

新增统一 `EditorDiffProviding` 和 `EditorMergeProviding`：

- 文本双栏和 inline diff
- 当前工作区对 Git 基线 diff
- 任意两文件比较
- 可编辑 Diff
- 行内 stage/revert
- 三方 Merge：base、incoming、current、result
- 冲突块接受 current/incoming/both
- Agent 修改预览和逐块接受/拒绝复用同一 Diff 基础设施

### 15.6 SCM

定义中立 `SourceControlProviding`，Git 只是一个实现插件：

- repository discovery
- working tree/staged changes
- stage/unstage/commit
- branch、tag、stash、worktree
- fetch/pull/push/sync
- blame、timeline、gutter decorations
- merge conflict 和 Diff/Merge 集成
- 多 repository 支持

`GitPlugin` 不再自己维护另一套文件打开和 Diff 导航逻辑。

### 15.7 Terminal 与 Task

Terminal 保持独立插件，但通过 Kernel 接收 workspace、theme、URI 打开和 command link 能力。

新增 Task 契约：

- `EditorTaskProvider`
- `EditorTaskDefinition`
- `EditorProblemMatcher`
- `EditorTaskExecution`
- compound/background/watch task
- build/test/default task
- 任务输出进入 Terminal 或 Output Channel
- Problem Matcher 产生 Editor Diagnostics

### 15.8 Debug

新增 Debug Adapter 中立契约：

- launch/attach configuration
- breakpoint、conditional breakpoint、logpoint
- variables、watch、call stack、threads
- continue、pause、step in/out/over、restart、stop
- debug console
- exception breakpoint
- source mapping
- inline values 和当前执行行 decoration

具体 Swift/LLDB、Node、Python 调试器由插件实现。Kernel 不依赖 DAP SDK。

### 15.9 Testing

新增 Testing 契约：

- test discovery
- Test Explorer tree
- run/debug/cancel
- current file/current test/all tests
- result、message、duration、attachment
- gutter run/debug action
- coverage file/line/branch data
- test output panel
- 与 Task、Debug、Diagnostics 集成

### 15.10 Output 与日志

新增 `OutputChannelProviding`：

- Language Server、Task、Debug、Testing、Git 分别使用独立 Channel。
- 支持 append、replace、clear、severity 和 timestamp。
- 日志与用户可见 Output 分离。
- 禁止插件直接把正常运行信息散落到系统 Console。

### 15.11 Settings、Profiles 与同步

- Settings schema 由插件贡献。
- 支持 UI 和 JSON 两种编辑方式。
- 支持默认、用户、Workspace、语言覆盖。
- Profiles 包含设置、快捷键、启用插件和布局。
- 同步是上层服务，不让编辑器插件直接访问账户。

### 15.12 Workspace Trust 与权限

工作区信任必须在启动外部进程前生效：

- 不可信工作区仍允许纯文本编辑。
- 默认禁止 Language Server、Task、Debug、Testing 和 workspace executable。
- Provider 声明所需权限：文件读取、文件写入、进程、网络。
- Kernel 根据用户授权返回 capability token。
- 插件不能因安装即获得隐式权限。

### 15.13 Remote

从 URI 开始支持 Remote，而不是假设所有资源都是本地 path：

- `file://` 只是一个 scheme。
- 文档、File System、Terminal、Task、LSP 通过 workspace authority 工作。
- SSH/Container 等插件实现 Remote Workspace Provider。
- 本地 Editor Host 仍渲染 UI，远端执行文件和进程操作。

### 15.14 Accessibility

- 所有 Editor chrome 有稳定 accessibility label、role 和 action。
- Completion、Hover、Diagnostics 和 Diff 支持 VoiceOver。
- 不只依赖颜色表达诊断或 Git 状态。
- 支持减少动画、提高对比度和键盘全操作。
- UI 自动化测试覆盖焦点顺序、菜单和 Overlay。

## 16. Lumi Agent/Chat 编辑器集成

这是 Lumi 区别于通用编辑器的核心能力，应复用编辑器标准事务、Diff 和权限系统。

### 16.1 功能

- 将当前文件、选择、诊断、符号或 Diff 加入对话。
- 选区解释、重构、生成测试、修复诊断。
- Editor Inline Chat。
- Agent 生成 `EditorWorkspaceEdit`，先展示 Diff Preview。
- 用户逐文件、逐块接受或拒绝。
- 接受后形成一个可撤销事务。
- 修改后自动保存、格式化和诊断刷新由策略控制。
- Agent 操作必须显示来源、修改范围和权限。

### 16.2 契约

新增：

- `EditorContextProviding`
- `EditorProposedEditProviding`
- `EditorReviewSessionProviding`
- `EditorChatContextItem`
- `EditorProposedWorkspaceEdit`

Chat 插件只消费 Kernel Snapshot，不读取 `EditorState`。Editor 插件也只通过 Kernel 的 Conversation Input 能力加入上下文。

## 17. 插件改造方案

### 17.1 插件分类

| 分类 | 示例 | 行为 |
|---|---|---|
| Host | `EditorHostPlugin` | 唯一持有 EditorService |
| Shell UI | `EditorPanelPlugin` | 提供 ViewContainer，调用 `kernel.editor.surface` |
| Workbench UI | ProjectFiles、Breadcrumb、Problems、Search、Outline | 消费 Kernel Snapshot，贡献 UI |
| Language | Swift、SQL、未来 Go/JS/Python | 贡献语言、Syntax、Server Factory |
| Intelligence | LSP adapter、lint、formatter | 贡献 Feature Provider |
| Development | Git、Terminal、Task、Debug、Testing | 贡献工作台能力 |
| AI | EditorChat、Proposed Edit Review | 消费 Snapshot，提交 Workspace Edit |

### 17.2 现有插件迁移矩阵

| 当前插件 | 目标改造 |
|---|---|
| `EditorKernelPlugin` | 与 Provider 合并为 `EditorHostPlugin` |
| `EditorProviderPlugin` | 迁入 Host；移除弱引用、pending plugin 和启动顺序补偿 |
| `EditorPanelPlugin` | 仅依赖 KernelLumi/LumiUI；调用 Surface Provider |
| `ProjectFilesPlugin` | 改读 `editor.sessions.statePublisher`，不读 Project open files |
| `ProjectFileBreadcrumbPlugin` | 改读 active document + document symbols |
| `ProjectFileTreePlugin` | 使用 editor.documents.open 和 editor state publisher；删除单独 coordination |
| `QuickFileSearchPlugin` | 选择文件后调用 editor.documents.open；索引未来迁入 Workspace Search Provider |
| `EditorSearchPlugin` | 移除 EditorService；正式启用 Workspace Search UI |
| `EditorProblemsPlugin` | 移除 EditorService；消费 diagnostics snapshot，正式启用 |
| `EditorOutlinePlugin` | 消费 document symbol provider 和 active document publisher |
| `EditorSymbolsPlugin` | 与 Outline/Workspace Symbol 职责重新命名，避免重复 |
| `EditorReferencesPlugin` | 消费 references state，并通过 navigation 打开位置 |
| `EditorCallHierarchyPlugin` | 消费 call hierarchy session，不持有 EditorService |
| `EditorStickySymbolBarPlugin` | 消费 visible range + document symbols |
| `EditorPreviewPlugin` | 通过 document snapshot/revision/save API；禁止直接改 NSTextStorage |
| `EditorSwiftPlugin` | 恢复被排除功能，拆成语言、LSP/项目上下文、Build/Run 可组合贡献 |
| `DatabaseManagerPlugin` SQL | 使用同一语言/Syntax API，保持可选插件归属 |
| `GitPlugin` | 实现 SCM Provider，Diff/导航走 Kernel 编辑器能力 |
| `TerminalPlugin` | 接入 workspace URI、Output、Task 和 terminal link |
| `EditorChatPlugin` | 改为 Inline Chat + Proposed Edit Review，正式启用 |

### 17.3 语言插件模板

语言插件只需要：

```swift
@MainActor
final class SwiftEditorPlugin: LumiPlugin {
    let id = "com.coffic.lumi.editor.swift"
    let apiVersion = EditorPluginAPIVersion.current

    func editorContributionBundle(kernel: KernelLumi) async throws -> EditorContributionBundle? {
        EditorContributionBundle(
            pluginID: id,
            apiVersion: apiVersion,
            generation: 1,
            languages: [SwiftLanguage.contribution],
            providers: [SwiftSyntaxProvider(), SourceKitLSPFactory()],
            commands: SwiftCommands.all,
            settings: SwiftSettings.all,
            ui: []
        )
    }
}
```

禁止语言插件：

- resolve `EditorService.self`
- 操作 `EditorExtensionRegistry`
- 写全局静态 `LSPConfig`
- 直接启动未经过 Workspace Trust 的进程
- 持有全局当前文件

## 18. Editor Host 改造

### 18.1 初始化

`EditorHostPlugin.onBoot`：

1. 创建一个 scope-aware `EditorService`。
2. 创建 Kernel DTO adapter。
3. 创建 contribution registry。
4. 注册完整 `EditorProviding`。
5. 注册时关闭高频状态向 Kernel 全局转发。

`onReady`：

1. 绑定 Project/Workspace publisher。
2. 恢复 Session。
3. 应用主题和配置。
4. 安装当前启用插件 Bundle。
5. 启动允许自动启动的 Provider。

`onDisable/teardown`：

1. 请求保存或 Hot Exit snapshot。
2. 取消请求。
3. 关闭 parser/server/task/debug session。
4. 移除 watcher 和 observers。
5. 释放 TextView 与 Session。

### 18.2 禁止全局桥

逐步删除：

- `EditorSettingsLifecycle` 全局 closure
- `EditorPreviewRuntimeBridge` 静态 provider
- `EditorStickySymbolBarBridge` 静态 provider
- `LSPConfig` 全局注册表
- 通过 NotificationCenter 传递本可类型化的编辑器状态

它们统一替换为 scope-aware service 或 contribution context。

## 19. 建议文件布局

```text
Packages/KernelLumi/Sources/KernelLumi/Editor/
├── Models/
│   ├── EditorIdentifiers.swift
│   ├── EditorScope.swift
│   ├── EditorPosition.swift
│   ├── EditorDocumentModels.swift
│   ├── EditorSessionModels.swift
│   ├── EditorEditModels.swift
│   ├── EditorDiagnosticModels.swift
│   └── EditorFeatureModels.swift
├── Services/
│   ├── EditorProviding.swift
│   ├── EditorDocumentProviding.swift
│   ├── EditorSessionProviding.swift
│   ├── EditorSelectionProviding.swift
│   ├── EditorNavigationProviding.swift
│   ├── EditorCommandProviding.swift
│   └── EditorConfigurationProviding.swift
├── Contributions/
│   ├── EditorPlugin.swift
│   ├── EditorContributionBundle.swift
│   ├── EditorFeatureProvider.swift
│   ├── EditorDocumentSelector.swift
│   ├── EditorLanguageContributions.swift
│   ├── EditorIntelligenceProviders.swift
│   └── EditorUIContributions.swift
├── Workbench/
│   ├── EditorContextKeys.swift
│   ├── EditorCommands.swift
│   ├── EditorTasks.swift
│   ├── EditorDebug.swift
│   ├── EditorTesting.swift
│   └── EditorSourceControl.swift
└── Registration/
    ├── KernelLumi+EditorRegistration.swift
    └── KernelLumi+EditorServices.swift

Plugins/EditorHostPlugin/
├── Host/
├── Adapters/
├── Contributions/
├── Surface/
└── Lifecycle/
```

## 20. 迁移实施阶段

### Phase 0：冻结边界与建立护栏

目标：后续开发不再增加新的实现穿透。

- 添加依赖扫描脚本。
- CI 禁止非 Host 插件依赖 EditorService/EditorSource/EditorKernel。
- 记录当前可用编辑行为和性能基线。
- 为当前打开、编辑、保存、切换标签、IME 和大文件建立回归测试。
- 暂不删除旧 API。

验收：新 PR 无法继续引入直接 EditorService 插件依赖。

### Phase 1：Kernel V2 模型和 Host Capability

- 新增强类型 ID、Position、Range、Location、Snapshot、Edit。
- 新增 Document、Session、Selection、Navigation、Command、Configuration 子能力。
- 旧 `EditorProviding` 标记 deprecated。
- `EditorService` 添加 Adapter，不重写内部实现。
- 契约测试覆盖 revision、状态 publisher、错误和取消。

验收：使用仅依赖 KernelLumi 的测试插件可以打开、读取、编辑、保存和导航文件。

### Phase 2：合并 Editor Host

- 创建 `EditorHostPlugin`。
- 合并 `EditorKernelPlugin` 和 `EditorProviderPlugin` 装配逻辑。
- 删除启动顺序假设、pending plugin 和弱引用兜底。
- `EditorPanelPlugin` 改走 `kernel.editor.surface`。

验收：关闭/重开 Host、切换插件启用状态不会出现“Editor service unavailable”竞态。

### Phase 3：统一文件与 Session 状态

- Project 只保留 workspace/project 状态。
- ProjectFiles 改为 Session snapshot。
- Breadcrumb、File Tree、Quick File Search 改走 Kernel Editor。
- 恢复、pin、reorder、close left/right 使用同一 Session API。
- 删除 `FileTreeEditorCoordination` 和 `EditorTabStripCoordination`。

验收：标签、当前文件、文件树高亮、面包屑在打开、关闭、重命名、删除和恢复后始终一致。

### Phase 4：贡献包和插件生命周期

- 实现 Bundle 原子安装和撤回。
- 实现 selector、priority、generation 和 capability availability。
- Swift 与 SQL 首先迁移。
- 移除 `registerEditorExtensions(into: AnyObject, ...)`。
- 移除 registry 全量 reset。

验收：运行时禁用语言插件后，其语言、命令、设置、Provider 和后台进程全部撤回，其他插件不受影响。

### Phase 5：语言功能和标准 Overlay

- 迁移 Completion、Hover、Signature、Definition、References。
- 接通 Diagnostics、Code Action、Rename、Formatting。
- 接通 Inlay Hint、Semantic Token、Document Highlight。
- Surface 统一装配 Overlay 和 keyboard routing。

验收：Swift 文件完成从输入到补全、诊断、修复、跳转、重命名和格式化的完整链路。

### Phase 6：启用 Workbench 插件

- Problems
- Search
- Outline
- Symbols
- References
- Call Hierarchy
- Sticky Symbol Bar
- Preview

验收：这些插件不导入 EditorService，启用/禁用可即时生效且没有贡献残留。

### Phase 7：Editor Groups、Diff 与 SCM

- 多 Group/Split。
- 通用 Diff/Merge。
- Git 迁移为 SCM Provider。
- gutter、blame、stage/revert、冲突解决接入 Editor。

### Phase 8：Task、Debug 与 Testing

- 先完成 Kernel 中立协议和 UI Shell。
- Swift 插件实现首个 Task/LLDB/Swift Testing Provider。
- 再开放给其他语言插件。

### Phase 9：Agent 编辑闭环

- Inline Chat。
- Proposed Workspace Edit。
- Diff Review。
- 逐块接受/拒绝。
- Undo、保存、格式化、诊断刷新闭环。

### Phase 10：安全、Remote 与生态

- Workspace Trust。
- Provider 权限声明。
- 插件 API version 和兼容性。
- Remote URI/File System/Process。
- Profiles 和同步。

## 21. 测试策略

### 21.1 Kernel 契约测试

- DTO 编码、相等性和 range 转换。
- revision mismatch。
- Workspace Edit 排序、重叠和回滚。
- selector 和 priority。
- contribution bundle 原子替换。
- 插件撤回和 generation 取消。
- Context Key 和 keybinding 解析。
- Provider 聚合确定性。

### 21.2 Host 集成测试

- 打开/关闭/切换/恢复 Session。
- Dirty、Auto Save、Hot Exit。
- 外部文件修改冲突。
- 多窗口 scope 隔离。
- Language Server crash/restart。
- 插件运行时启用/禁用。
- 大文件模式能力降级。

### 21.3 UI 测试

- IME 输入和 marked text。
- Placeholder/Overlay 不阻挡点击。
- Completion、Hover、Rename、Code Action 的焦点与键盘路由。
- Tab 拖拽、Split、关闭确认。
- Problems/Search/References 导航。
- Diff/Merge 接受操作。
- VoiceOver label 和全键盘操作。

### 21.4 性能测试

建立固定数据集与预算：

- 1 MB、10 MB、100 MB 文件打开时间。
- 首屏渲染和滚动帧时间。
- 每次键入主线程耗时。
- 增量高亮和 LSP change 开销。
- Completion 首结果延迟。
- Workspace Search 首结果和完成时间。
- 10、50、200 个标签的内存和切换时间。
- 插件启用/禁用后的资源释放。

性能测试必须测真实 UI/运行时边界，不能只依赖纯模型单测。

## 22. 监控与诊断

统一记录：

- request ID、provider ID、plugin ID、document revision、generation
- 请求开始、取消、完成、超时、stale discard
- Language Server 生命周期
- Parser 和高亮耗时
- 主线程长任务
- Workspace Edit 失败原因
- 插件贡献安装/撤回

开发模式提供 Editor Diagnostics 页面，显示：

- 当前 active document/session/group
- 已匹配 Provider
- capability availability
- Language Server 状态
- pending requests
- large file policy
- contribution generations

## 23. 错误模型

Kernel 定义统一错误：

- `capabilityUnavailable`
- `workspaceNotTrusted`
- `permissionDenied`
- `documentNotFound`
- `revisionMismatch`
- `readOnlyDocument`
- `providerFailed`
- `requestCancelled`
- `requestTimedOut`
- `invalidWorkspaceEdit`
- `externalFileConflict`
- `largeFileRestriction`

用户可操作错误通过 Toast/Panel 展示；调试细节进入 Output/Log。禁止只打印日志而不给用户状态。

## 24. 版本与第三方插件兼容

- `EditorPluginAPIVersion` 使用 major/minor。
- Major 不兼容时拒绝安装并说明原因。
- Minor 新能力必须可选发现。
- Bundle 声明最低 Lumi 版本、所需权限和支持的工作区信任状态。
- Provider ID 在插件内唯一，完整 ID 自动加 plugin namespace。
- Kernel 保存弃用周期，至少跨一个稳定版本提供迁移警告。

## 25. 持久化、灰度与回滚

### 25.1 持久化数据版本

Editor Workbench 持久化必须有独立 schema version，至少覆盖：

- workspace identity
- window/group/session IDs
- tab 顺序、pin 和 preview 状态
- URI、selection、scroll、folding 和 view state
- Hot Exit buffer 或恢复引用
- editor settings/profile reference

迁移规则：

1. 读取旧数据时先解码旧 schema，再映射到 V2 DTO。
2. V2 成功写入前保留旧文件备份。
3. 不持久化 Provider 实例、插件对象或实现类型名。
4. 插件缺失时保留文档 Session，但相关能力显示 unavailable。
5. URI 无法访问时保留恢复记录并向用户说明，不静默删除。

### 25.2 灰度开关

迁移期至少准备以下内部开关：

- `editor.contracts.v2`
- `editor.host.v2`
- `editor.sessions.v2`
- `editor.contributions.v2`
- `editor.surface.overlays.v2`

开关仅用于迁移和故障回退，不得形成两套长期维护的产品逻辑。每个开关必须在对应阶段完成后删除。

### 25.3 禁止双写

迁移阶段允许旧 API 从 V2 状态派生只读兼容值，但禁止 V1/V2 同时独立写入当前文件、Session 或脏状态。需要兼容旧消费者时采用：

```text
V2 single source of truth
    └─ V1 read-only compatibility adapter
```

不得采用双向同步；双向同步会重新引入循环更新和状态竞争。

### 25.4 回滚条件

出现以下任一情况应关闭对应灰度开关并回退到上一个稳定阶段：

- 文档内容丢失或错误覆盖
- IME/输入法回归
- Session 恢复损坏
- 插件禁用后资源泄漏
- 主线程键入性能明显退化
- 完整 App 构建失败
- 标准 Overlay 阻挡文本焦点或鼠标交互

回滚只切换运行路径，不回滚或删除用户文档。

## 26. 需要删除或替换的旧设计

完成对应迁移阶段后删除：

- 旧的巨型/窄版 `EditorProviding`
- `registerEditorExtensions(into: AnyObject, ...)`
- 插件直接 resolve `EditorService.self`
- `FileTreeEditorCoordination`
- `EditorTabStripCoordination`
- Project 侧打开文件和当前文件独立状态
- Editor registry 全量 `reset()` 回放
- `EditorSettingsLifecycle` 静态回调
- `EditorPreviewRuntimeBridge` 等静态服务桥
- `LSPConfig` 全局注册表
- Kernel 中 Tree-sitter `OpaquePointer`
- 插件 Package 对 EditorService/EditorSource/EditorKernel 的依赖

删除必须在消费者全部迁移且集成测试通过后执行，不能提前破坏兼容链路。

## 27. 验证命令与证据要求

实施者应根据变更层级运行对应验证，不能用较低层验证代替较高层验证。

### 27.1 Package 验证

```sh
swift test --package-path Packages/KernelLumi
swift test --package-path Packages/EditorKernel
swift test --package-path Packages/EditorService
swift test --package-path Plugins/EditorHostPlugin
```

每个迁移插件还必须单独运行自身 `swift test --package-path ...`。如果插件没有测试 Target，应先增加最小注册和撤回测试。

### 27.2 完整 Lumi 构建

```sh
xcodebuild \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -configuration Debug \
  -sdk macosx \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  build
```

只有日志明确出现 `BUILD SUCCEEDED` 才能宣称完整 App 构建成功。Package 测试或单个插件构建不能替代它。

### 27.3 真实运行时证据

以下功能必须在本次构建出的 Debug App 中验证：

- 打开项目和多个文件
- 编辑、保存、撤销、切换标签
- 中文 IME marked text
- Completion/Hover/Rename/Code Action 的焦点和键盘处理
- 插件运行时启用/禁用
- Problems/Search/References 跳转
- Split/Diff/Merge 交互
- Language Server 崩溃与重启
- 未信任工作区的能力降级

报告必须区分：单元测试、Package 构建、完整 App 构建和真实 UI 验证。

### 27.4 依赖证据

CI 检查至少验证：

```text
KernelLumi does not import EditorService/EditorSource/EditorKernel/plugins
EditorKernel does not import SwiftUI/plugin modules
non-host plugins do not depend on EditorService/EditorSource/EditorTextView/EditorKernel
plugins do not depend on other plugins
```

## 28. Definition of Done

整个重构只有同时满足以下条件才算完成：

### 架构

- [ ] 非 Host 插件只通过 Kernel 编辑器契约工作。
- [ ] Kernel 不引用编辑器实现类型或 LSP/Tree-sitter 具体类型。
- [ ] 插件贡献可原子安装、撤回和取消。
- [ ] 文档、Session、当前文件只有一个事实源。
- [ ] 多窗口和 workspace scope 不使用全局静态状态。

### 编辑体验

- [ ] 基础编辑、Find/Replace、多光标、保存和恢复稳定。
- [ ] Completion、Hover、Signature、Diagnostics、Code Action、Rename、Formatting 完整接通。
- [ ] Definition、References、Symbols、Call Hierarchy 和 Peek 可用。
- [ ] Problems、Search、Outline、References 等插件正式启用。
- [ ] Tab Group、Split、Diff 和 Merge 可用。

### 工作台

- [ ] SCM、Terminal、Task、Debug、Testing 使用 Kernel 契约集成。
- [ ] Settings、Commands、Keybindings 和 Context Keys 统一。
- [ ] Workspace Trust 在外部进程启动前生效。
- [ ] Agent 修改通过 Workspace Edit + Diff Review + Undo 闭环。

### 质量

- [ ] Kernel、Host、插件契约测试通过。
- [ ] Lumi 完整 Debug 构建出现明确 `BUILD SUCCEEDED`。
- [ ] Swift 文件真实运行时交互验证通过。
- [ ] IME、焦点、Overlay、Tab、导航和保存有 UI 验证。
- [ ] 大文件、插件重载和 Language Server crash 有压力验证。
- [ ] 性能不低于迁移前基线，关键路径满足预算。
- [ ] 文档、示例插件和插件模板同步更新。

## 29. 实施时的强制检查清单

每个编辑器相关 PR 必须回答：

1. 这是 Host Capability、Feature Contribution 还是 UI Contribution？
2. 新类型是否中立，是否泄露 EditorService/AppKit/LSP/Tree-sitter？
3. 状态事实源在哪里？是否创建了第二份当前文件或 Session 状态？
4. 插件禁用后如何撤回贡献、取消任务和关闭进程？
5. 异步结果如何校验 revision 和 generation？
6. 多窗口/多工作区是否隔离？
7. 未信任工作区和权限不足时如何降级？
8. 大文件模式是否需要禁用或降级？
9. 标准功能是否复用了 Host UI，而不是插件自绘一套？
10. 验证包含 package test、完整 app build 还是实际 UI？必须准确表述。

## 30. 推荐的第一批实施任务

第一批只建立稳定地基，不同时迁移所有 LSP/UI：

1. 新建 `KernelLumi/Editor/Models` 中立模型。
2. 新建 `EditorProviding V2` 和 Document/Session/Selection/Navigation 子协议。
3. 为 `EditorService` 编写 V2 Adapter。
4. 建立 revision-aware Workspace Edit。
5. 合并 `EditorKernelPlugin` 与 `EditorProviderPlugin` 为 `EditorHostPlugin`。
6. 迁移 `EditorPanelPlugin`。
7. 迁移 ProjectFiles、Breadcrumb、File Tree、Quick File Search。
8. 删除当前文件双状态源。
9. 建立依赖扫描和测试用最小插件。
10. 完成一次真实 UI 验证后，再进入贡献包和 LSP 迁移。

这十项完成后，编辑器架构才具备继续实现完整功能的稳定基础。
