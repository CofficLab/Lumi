# AgentEditorPlugin 架构分析与 UI 优先优化方案

> 生成日期: 2025-01-XX
> 目标: UI 线程零阻塞，所有可后台的任务移至后台线程

---

## 一、整体架构概览

### 1.1 层级结构

```
EditorPlugin (SuperPlugin actor)
├── EditorRootOverlay          → 文件选择监听包裹层
├── EditorRootView             → 根视图（工具栏 + 编辑器 + 底部栏）
│   ├── EditorToolbarView      → 字体/缩进/主题/开关
│   ├── SourceEditorView       → 核心编辑器 (CodeEditSourceEditor)
│   │   ├── EditorCoordinator  → 文本变更/焦点管理
│   │   ├── CursorCoordinator  → 光标位置追踪
│   │   ├── ContextMenuCoordinator → 右键菜单注入
│   │   ├── HoverEditorCoordinator → Hover 请求协调
│   │   ├── SemanticTokenHighlightProvider → 语义高亮
│   │   ├── DocumentHighlightHighlighter   → 引用高亮
│   │   ├── SignatureHelpProvider          → 签名帮助
│   │   └── CodeActionProvider             → 代码动作
│   ├── EditorBreadcrumbView   → 面包屑导航
│   ├── ProblemsPanelView      → 问题面板
│   └── EditorReferencesPanelView → 引用面板
├── LSP 系统
│   ├── LSPService (@MainActor singleton)
│   ├── LSPCoordinator (@MainActor)
│   ├── LanguageServer (底层 IPC)
│   └── 各 Provider (CodeAction / Completion / Hover 等)
├── EditorPluginManager        → 子插件自动发现与注册
├── EditorExtensionRegistry    → 扩展点注册中心
│   ├── EditorCompletionContributor
│   ├── EditorHoverContributor
│   ├── EditorCodeActionContributor
│   ├── EditorCommandContributor
│   ├── EditorInteractionContributor
│   ├── EditorSidePanelContributor
│   ├── EditorSheetContributor
│   └── EditorToolbarContributor
└── Store
    ├── EditorState (@MainActor) — 全局状态中心
    └── EditorConfigStore       — 配置持久化
```

### 1.2 核心数据流

```
用户输入 → CodeEditSourceEditor → EditorCoordinator.textViewDidChangeText()
                                    ↓
                            EditorState.notifyContentChanged()
                                    ↓
                            LSPCoordinator.contentDidChange()
                                    ↓ (0.3s debounce)
                            LSPService.documentDidChange() → LanguageServer
                                    ↓
                            ← LSP publishDiagnostics → EditorState.problemDiagnostics
```

---

## 二、当前架构问题诊断

### 2.1 严重问题：主线程阻塞

| 位置 | 问题 | 影响 |
|------|------|------|
| `LSPService` | 整个类标记 `@MainActor`，所有 LSP 网络/IPC 调用在主线程执行 | 补全、悬停、跳转、格式化等操作期间 UI 卡顿 |
| `LSPCoordinator` | 整个类标记 `@MainActor`，所有 LSP 请求通过主线程 | 所有 LSP 功能都会阻塞渲染 |
| `EditorState` | 整个类标记 `@MainActor`，包含大量 LSP 请求方法 | 状态更新和 LSP 请求互相阻塞 |
| `CodeActionProvider` | `@MainActor` 上直接调用 `lspService.requestCodeAction` | 代码动作请求期间输入延迟 |
| `CompletionProvider` | `@MainActor`，补全请求在主线程 | 补全弹出延迟，打字卡顿 |
| `SemanticTokenHighlightProvider` | 虽用 Task 异步，但 `lspService` 是 MainActor | 语义高亮请求在主线程排队 |

### 2.2 中等问题：缺少节流/防抖

| 位置 | 问题 |
|------|------|
| Hover 请求 | 鼠标移动时频繁触发，无防抖机制 |
| 文档高亮 | 光标移动时立即请求，无节流 |
| 代码动作 | 每次选区变化都请求 |
| Inlay Hints | 视口变化时没有节流 |
| 签名帮助 | 每次输入都请求 |

### 2.3 轻微问题：设计优化空间

| 位置 | 问题 |
|------|------|
| `EditorExtensionRegistry` 所有方法 `@MainActor` | 去重、排序等纯计算操作不需要主线程 |
| `LSPService.parseXxx()` 系列方法在主线程 | 解析逻辑纯计算，可后台 |
| `EditorState` 承载过多职责 | 状态管理 + LSP 客户端 + UI 状态耦合 |
| `MultiCursorEditEngine` 在主线程 | 多光标匹配算法可优化到后台 |

---

## 三、内部插件系统设计分析

### 3.1 插件发现机制

`EditorPluginManager.autoDiscoverAndRegisterPlugins()` 使用 Objective-C runtime 扫描所有以 `EditorPlugin` 结尾的类，自动实例化并注册。

**优点**: 零配置，新增插件只需遵循协议并命名即可被发现
**缺点**: 扫描所有类有性能开销（应用启动时）

### 3.2 扩展点系统

`EditorExtensionRegistry` 提供 8 种扩展点：

| 扩展点 | 调用时机 | 当前线程 |
|--------|----------|----------|
| `EditorCompletionContributor` | 补全触发 | MainActor |
| `EditorHoverContributor` | 鼠标悬停 | MainActor |
| `EditorCodeActionContributor` | 选区变化/诊断出现 | MainActor |
| `EditorCommandContributor` | 右键菜单打开 | MainActor (同步) |
| `EditorInteractionContributor` | 文本变更/选区变更 | MainActor |
| `EditorSidePanelContributor` | 面板渲染时 | MainActor (同步) |
| `EditorSheetContributor` | Sheet 渲染时 | MainActor (同步) |
| `EditorToolbarContributor` | 工具栏渲染时 | MainActor (同步) |

### 3.3 子插件示例

`SwiftPrimitiveTypeCompletionContributor` — 内置 Swift 基本类型补全，在类型上下文时优先提供 Int/Float/String 等建议。

---

## 四、优化方案

### 4.1 核心原则

```
UI Thread (@MainActor)
  ├── 只负责：视图渲染、用户交互响应、状态 Published 属性更新
  └── 绝不：网络请求、IPC 通信、大文本解析、复杂计算

Background Thread (actor / Task)
  ├── LSP 通信 (JSON-RPC over pipe/socket)
  ├── 文本解析 (Semantic Tokens, Document Symbols)
  ├── 去重/排序 (Completion, Hover, Code Actions)
  └── 文件操作 (WorkspaceEdit file operations)
```

### 4.2 重构层级设计

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (@MainActor)                     │
│  SourceEditorView / EditorToolbarView / Panels / Popovers   │
│  ↓ 仅读写 @Published 属性，不执行任何耗时操作                   │
└────────────────────────┬────────────────────────────────────┘
                         │ Binding / @Published
┌────────────────────────▼────────────────────────────────────┐
│                State Layer (@MainActor)                      │
│  EditorState — 轻量状态容器                                   │
│  ↓ 委托耗时操作到 Service Layer                               │
└────────────────────────┬────────────────────────────────────┘
                         │ async/await
┌────────────────────────▼────────────────────────────────────┐
│              Service Layer (Nonisolated Actors)              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐ │
│  │ LSPDispatcher │ │ TextAnalyzer │ │ ExtensionResolver    │ │
│  │ (actor)       │ │ (actor)      │ │ (actor)              │ │
│  │ - 管理 IPC    │ │ - 语义分析   │ │ - 扩展点聚合         │ │
│  │ - 请求路由    │ │ - Token 解码 │ │ - 后台去重排序       │ │
│  │ - 结果缓存    │ │ - 位置映射   │ │ - 插件结果合并       │ │
│  └──────┬───────┘ └──────┬───────┘ └──────────┬───────────┘ │
│         │                │                     │            │
│  ┌──────▼────────────────▼─────────────────────▼──────────┐ │
│  │           Background Worker Pool (Sendable)            │ │
│  │  - LanguageServer IPC                                  │ │
│  │  - SemanticToken decoding                              │ │
│  │  - Document symbol parsing                             │ │
│  │  - WorkspaceEdit file operations                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 4.3 具体改造清单

#### Phase 1: LSP 系统解耦 (最高优先级)

##### 4.3.1 LSPService 改造

**当前**:
```swift
@MainActor
final class LSPService: ObservableObject { ... }
```

**改造后**:
```swift
/// LSP 调度器 — 非隔离 actor，所有 LSP 通信在后台线程
actor LSPDispatcher: ObservableObject {
    // @Published 需要 @MainActor 包装
    @MainActorActorSafe var currentDiagnostics: [Diagnostic] = []
    @MainActorActorSafe var isAvailable: Bool = false
    @MainActorActorSafe var isInitializing: Bool = false
    
    private var server: LanguageServer?
    
    // 所有 LSP 请求方法不再标记 @MainActor
    func requestCompletion(uri: String, line: Int, character: Int) async -> [CompletionItem] {
        guard let server else { return [] }
        // IPC 调用在 actor 自己的线程执行，不阻塞 UI
        do {
            let response = try await server.completion(uri: uri, line: line, character: character)
            return parseCompletionItems(response)
        } catch {
            return []
        }
    }
    
    func requestHover(uri: String, line: Int, character: Int) async -> Hover? { ... }
    func requestDefinition(uri: String, line: Int, character: Int) async -> Location? { ... }
    func requestReferences(uri: String, line: Int, character: Int) async -> [Location] { ... }
    // ... 其余所有 LSP 请求方法
}

/// @Published 安全包装器 — 允许从非隔离 actor 发布更新
@propertyWrapper
struct MainActorActorSafe<Value> {
    @MainActor private var storage: Value
    init(wrappedValue: Value) { storage = wrappedValue }
    
    var wrappedValue: Value {
        get { storage } // 读操作需要在 MainActor 上（通过 Task 调度）
        nonmutating set {
            Task { @MainActor in storage = newValue }
        }
    }
}
```

##### 4.3.2 LSPCoordinator 改造

**当前**:
```swift
@MainActor
class LSPCoordinator: ObservableObject, EditorLSPClient { ... }
```

**改造后**:
```swift
/// LSP 协调器 — 仅做 UI ↔ LSP 的桥梁，自身不执行耗时操作
@MainActor
class LSPCoordinator: ObservableObject, EditorLSPClient {
    private let dispatcher: LSPDispatcher // actor 引用
    
    // 打开/关闭文件 — 快速操作
    func openFile(uri: String, languageId: String, content: String) async {
        await dispatcher.openDocument(uri: uri, languageId: languageId, text: content)
    }
    
    // 所有请求方法直接透传，不阻塞主线程
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem] {
        await dispatcher.requestCompletion(uri: uri, line: line, character: character)
    }
}
```

##### 4.3.3 LSP 请求防抖层

```swift
/// LSP 请求节流器 — 防止快速连续请求
actor LSPDebouncer {
    private var pendingTasks: [String: Task<Void, Never>] = [:]
    private let defaultDelay: UInt64 = 150_000_000 // 150ms
    
    /// 执行防抖请求，同一 key 的新请求会取消旧请求
    func debounce<T: Sendable>(
        key: String,
        delay: UInt64? = nil,
        operation: @escaping @Sendable () async -> T
    ) async -> T? {
        // 取消同 key 的旧任务
        pendingTasks[key]?.cancel()
        
        let task = Task {
            let d = delay ?? defaultDelay
            try? await Task.sleep(nanoseconds: d)
            guard !Task.isCancelled else { return nil }
            return await operation()
        }
        pendingTasks[key] = task
        
        let result = await task.value
        if pendingTasks[key] == task {
            pendingTasks.removeValue(forKey: key)
        }
        return result
    }
    
    /// 节流执行 — 确保两次调用之间至少有指定间隔
    func throttle<T: Sendable>(
        key: String,
        interval: UInt64,
        operation: @escaping @Sendable () async -> T
    ) async -> T? { ... }
}
```

#### Phase 2: EditorState 瘦身

##### 4.3.4 职责拆分

**当前**: `EditorState` 同时负责：
- UI 状态 (fontSize, wrapLines, theme...)
- LSP 请求 (goToDefinition, requestRename...)
- 诊断管理
- 多光标状态
- 配置持久化

**改造后**:

```swift
// 纯 UI 状态 — 保留 @MainActor
@MainActor
final class EditorUIState: ObservableObject {
    @Published var fontSize: Double = 14
    @Published var wrapLines: Bool = true
    @Published var showGutter: Bool = true
    @Published var showMinimap: Bool = true
    @Published var themePreset: String = "xcodeDark"
    // ... 其余 UI 配置
}

// LSP 状态 — 通过 actor 更新
@MainActor
final class EditorLSPState: ObservableObject {
    @Published var diagnostics: [Diagnostic] = []
    @Published var errorCount: Int = 0
    @Published var warningCount: Int = 0
    @Published var completionItems: [CompletionItem] = []
    // ...
}

// 状态聚合 — 组合以上两者
@MainActor
final class EditorState: ObservableObject {
    @PublishedObject var uiState = EditorUIState()
    @PublishedObject var lspState = EditorLSPState()
    
    // 服务引用 — 通过 actor 调用
    private let lspDispatcher: LSPDispatcher
    private let textAnalyzer: TextAnalyzer
    private let extensionResolver: ExtensionResolver
    
    // 便捷方法 — 异步委托给 actor
    func goToDefinition(for range: NSRange) async {
        let location = await lspDispatcher.requestDefinition(...)
        // 只更新 UI 状态
        navigateToLocation(location)
    }
}
```

#### Phase 3: 扩展点系统后台化

##### 4.3.5 EditorExtensionRegistry 改造

**当前**: 所有方法 `@MainActor`

**改造后**:

```swift
/// 扩展点解析器 — actor 负责后台聚合插件结果
actor ExtensionResolver {
    private var completionContributors: [any EditorCompletionContributor] = []
    private var hoverContributors: [any EditorHoverContributor] = []
    // ...
    
    /// 后台聚合补全建议
    func resolveCompletion(context: EditorCompletionContext) async -> [EditorCompletionSuggestion] {
        // 并行请求所有 contributor
        await withTaskGroup(of: [EditorCompletionSuggestion].self) { group in
            for contributor in completionContributors {
                group.addTask {
                    await contributor.provideSuggestions(context: context)
                }
            }
            // 合并 + 去重 + 排序
            return mergeAndDeduplicate(allResults)
        }
    }
    
    /// 后台聚合 hover 建议
    func resolveHover(context: EditorHoverContext) async -> [EditorHoverSuggestion] { ... }
    
    /// 后台聚合代码动作
    func resolveCodeActions(context: EditorCodeActionContext) async -> [EditorCodeActionSuggestion] { ... }
}

// UI 层调用
@MainActor
class EditorState: ObservableObject {
    func requestHover(...) async {
        // 后台解析，不阻塞 UI
        let suggestions = await extensionResolver.resolveHover(context: context)
        // 只更新 @Published
        self.hoverSuggestions = suggestions
    }
}
```

#### Phase 4: 语义高亮优化

##### 4.3.6 SemanticTokenHighlightProvider 改造

**当前**: Task 中调用 `MainActor` 的 LSPService

**改造后**:

```swift
@MainActor
final class SemanticTokenHighlightProvider: HighlightProviding {
    private let dispatcher: LSPDispatcher // actor，非 MainActor
    private let debouncer = LSPDebouncer()
    
    private func refreshSemanticTokens() {
        guard let uri = uriProvider(), let textView else { return }
        
        // 防抖 + 后台执行
        Task { [weak self] in
            guard let self else { return }
            
            // 后台获取 tokens
            guard let tokens = await self.dispatcher.requestSemanticTokens(uri: uri) else { return }
            let resultId = await self.dispatcher.semanticTokenMap(for: uri)
            
            // 后台解码
            let decoded = await SemanticTokenDecoder.decode(
                tokens: tokens,
                map: resultId,
                content: textView.string
            )
            
            // 只在最后一步回到主线程更新 UI
            await MainActor.run {
                self.highlights = decoded
                self.completePendingEdit(...)
            }
        }
    }
}

/// 语义 Token 解码器 — 纯计算，完全后台
actor SemanticTokenDecoder {
    static func decode(
        tokens: [SemanticToken],
        map: SemanticTokenMap,
        content: String
    ) async -> [HighlightRange] {
        // 可并行解码不同行
        await withTaskGroup(of: [HighlightRange].self) { group in
            // ...
        }
    }
}
```

#### Phase 5: 文件操作后台化

##### 4.3.7 WorkspaceEditFileOperations 改造

**当前**: 文件创建/重命名/删除在主线程

**改造后**:

```swift
/// 文件操作执行器 — 后台 actor
actor WorkspaceEditExecutor {
    func applyCreateFile(_ operation: CreateFile) async throws {
        // 文件 I/O 在后台线程
        try FileManager.default.createFile(...)
    }
    
    func applyRenameFile(_ operation: RenameFile) async throws { ... }
    func applyDeleteFile(_ operation: DeleteFile) async throws { ... }
    
    /// 批量应用 WorkspaceEdit
    func applyWorkspaceEdit(_ edit: WorkspaceEdit) async throws {
        // 所有文件操作并行执行（互不依赖的）
        try await withThrowingTaskGroup(of: Void.self) { group in
            // ...
        }
    }
}
```

#### Phase 6: Coordinator 优化

##### 4.3.8 EditorCoordinator 优化

**当前**: 文本变更直接触发 `notifyContentChanged()` 并调度 LSP 更新

**优化后**:

```swift
nonisolated func textViewDidChangeText(controller: TextViewController) {
    // 文本变更通知快速返回
    let state = self.state
    
    // 1. 立即更新脏状态（轻量操作，DispatchQueue.main.async）
    DispatchQueue.main.async {
        state?.notifyContentChanged()
    }
    
    // 2. LSP 文档变更通过防抖层，不阻塞 UI
    Task { [weak state] in
        guard let state, let uri = state.currentFileURL?.absoluteString else { return }
        await state.lspDebouncer.debounce(key: "doc_change_\(uri)") {
            await state.lspDispatcher.documentDidChange(uri: uri, ...)
        }
    }
    
    // 3. 扩展点交互在后台执行
    Task { @MainActor [weak state] in
        guard let state else { return }
        let context = Self.interactionContext(controller: controller, state: state, ...)
        await state.extensionResolver.runInteractionTextDidChange(context: context, state: state)
    }
}
```

##### 4.3.9 HoverCoordinator 添加防抖

```swift
final class HoverCoordinator: TextViewCoordinator {
    private let hoverDebouncer = LSPDebouncer()
    private static let hoverDelay: UInt64 = 200_000_000 // 200ms
    
    nonisolated func textView(_ textView: TextView, mouseMovedIn rect: CGRect, at position: Int) {
        let state = self.state
        Task { [weak state] in
            guard let state else { return }
            
            // 防抖：鼠标静止 200ms 后才请求 hover
            let hoverText = await state.hoverDebouncer.debounce(
                key: "hover_\(state.currentFileURL?.absoluteString ?? "")",
                delay: Self.hoverDelay
            ) {
                await state.lspDispatcher.requestHoverRaw(uri: uri, line: line, character: char)
            }
            
            // 解析 Markdown 在后台
            let parsed = await MarkdownParser.parse(hoverText)
            
            // 只更新 UI
            await MainActor.run {
                state.mouseHoverContent = parsed
                state.mouseHoverSymbolRect = rect
            }
        }
    }
}
```

### 4.4 线程模型总结

```
┌─────────────────────────────────────────────────────────────────┐
│ 线程分配矩阵                                                     │
├──────────────────────────┬──────────────┬───────────────────────┤
│ 组件                     │ 当前线程     │ 目标线程              │
├──────────────────────────┼──────────────┼───────────────────────┤
│ SourceEditorView         │ @MainActor   │ @MainActor ✓          │
│ EditorToolbarView        │ @MainActor   │ @MainActor ✓          │
│ EditorState              │ @MainActor   │ @MainActor (瘦身后)   │
│ LSPService               │ @MainActor ✗ │ actor LSPDispatcher   │
│ LSPCoordinator           │ @MainActor   │ @MainActor (桥梁)     │
│ CompletionProvider       │ @MainActor ✗ │ actor LSPDispatcher   │
│ CodeActionProvider       │ @MainActor ✗ │ actor LSPDispatcher   │
│ SemanticTokenHighlighter │ MainActor ✗  │ actor + 后台解码      │
│ EditorExtensionRegistry  │ @MainActor ✗ │ actor ExtensionResolver│
│ DiagnosticsManager       │ @MainActor   │ @MainActor (仅监听)   │
│ EditorCoordinator        │ nonisolated  │ nonisolated ✓         │
│ CursorCoordinator        │ nonisolated  │ nonisolated ✓         │
│ ContextMenuCoordinator   │ @MainActor   │ @MainActor ✓          │
│ HoverPopoverView         │ @MainActor   │ @MainActor ✓          │
│ WorkspaceEditFileOps     │ 主线程 ✗     │ actor WorkspaceEdit   │
│ MultiCursorEditEngine    │ 主线程       │ actor (可优化)        │
│ EditorPluginManager      │ @MainActor   │ @MainActor (发现仅启动)│
│ EditorLoadedPluginsVM    │ @MainActor   │ @MainActor ✓          │
└──────────────────────────┴──────────────┴───────────────────────┘
```

### 4.5 防抖/节流配置表

| 功能 | 策略 | 延迟 | 说明 |
|------|------|------|------|
| 文档变更通知 LSP | debounce | 300ms | 已有，保留 |
| 补全请求 | debounce | 50ms | 快速响应，短延迟 |
| Hover 请求 | debounce | 200ms | 鼠标需静止 |
| 文档高亮 | throttle | 250ms | 跟随光标，节流 |
| 代码动作 | debounce | 300ms | 与诊断同步 |
| 签名帮助 | debounce | 150ms | 括号输入时触发 |
| Inlay Hints | throttle | 500ms | 视口变化时更新 |
| 语义高亮 | throttle | 250ms | 滚动时更新 |
| 折叠范围 | debounce | 1s | 打开文件时请求 |

### 4.6 实施优先级

```
Priority 1 (立即实施 — 阻塞 UI 最严重)
├── P1.1 LSPService 改为 actor (LSPDispatcher)
├── P1.2 LSPCoordinator 保留 @MainActor 但仅做桥梁
├── P1.3 Hover 请求添加防抖
└── P1.4 Completion 请求通过 actor 执行

Priority 2 (尽快实施 — 明显体验提升)
├── P2.1 EditorExtensionRegistry 改为 actor
├── P2.2 SemanticToken 解码移至后台
├── P2.3 CodeAction 请求后台化
├── P2.4 文档高亮添加节流
└── P2.5 WorkspaceEdit 文件操作后台化

Priority 3 (后续优化 — 锦上添花)
├── P3.1 EditorState 职责拆分
├── P3.2 MultiCursor 匹配算法后台化
├── P3.3 扩展点并行请求 (withTaskGroup)
├── P3.4 LSP 结果缓存层
└── P3.5 启动时插件扫描优化
```

### 4.7 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| `@Published` 从非 MainActor 更新崩溃 | 高 | 使用 `MainActorActorSafe` 包装器或 `Task { @MainActor }` |
| `Sendable` 要求导致类型不兼容 | 中 | LSP 类型大多已 Sendable，必要时添加 `@unchecked Sendable` |
| Actor 重入导致状态不一致 | 中 | 使用版本检查 (document version) 丢弃过期响应 |
| Task 取消导致内存泄漏 | 低 | 使用 `[weak self]` 捕获，Task 完成后自动清理 |

### 4.8 向后兼容策略

```swift
// 过渡期保留旧接口，标记 deprecated
extension LSPService {
    @available(*, deprecated, message: "Use LSPDispatcher instead")
    func requestCompletion(uri: String, line: Int, character: Int) async -> [CompletionItem] {
        await dispatcher.requestCompletion(uri: uri, line: line, character: character)
    }
}

// 新增接口逐步替换
extension LSPService {
    var dispatcher: LSPDispatcher { _dispatcher }
}
```

---

## 五、预期效果

### 5.1 UI 响应性提升

| 场景 | 优化前 | 优化后 |
|------|--------|--------|
| 打字时 LSP 补全 | 偶尔卡顿 100-300ms | 零感知，补全在后台准备 |
| 鼠标悬停 | 移动时频繁请求导致卡顿 | 200ms 防抖，仅静止时请求 |
| 大文件语义高亮 | 滚动时掉帧 | 后台解码，按需渲染 |
| 代码动作弹出 | 选区变化时短暂卡顿 | 后台请求，准备好后显示 |
| 格式化文档 | UI 冻结直到完成 | 后台执行，完成后应用 |

### 5.2 架构质量提升

- **关注点分离**: UI 层只关心渲染，Service 层只关心业务逻辑
- **可扩展性**: 新增子插件无需关心线程模型，扩展点自动在后台聚合
- **可测试性**: actor 方法易于单元测试，不依赖 MainActor 环境
- **可维护性**: 线程模型清晰，不再有隐藏的 MainActor 阻塞

---

## 七、实施进度

> **最后更新**: 2025-06-18
> **整体进度**: Phase 1-4 完成 (约 90%)，Phase 5 测试待实施

### 进度总览

| Phase | 状态 | 完成度 | 说明 |
|-------|------|--------|------|
| Phase 1: LSP 系统解耦 | 🟢 已完成 | 100% | Debouncer + ExtensionResolver + Coordinator 防抖 + Semantic Token 后台解码 |
| Phase 2: 状态瘦身 | 🟢 已完成 | 100% | EditorUIState + EditorFileState + EditorPanelState 子容器已创建，EditorState 保持向后兼容 |
| Phase 3: 扩展点 + 文件操作 | 🟢 已完成 | 100% | WorkspaceEdit 后台 executor + ExtensionResolver |
| Phase 4: Coordinator 优化 | 🟢 已完成 | 100% | HoverCoordinator 防抖（已有）+ EditorCoordinator 优化 |
| Phase 5: 测试 + 基准对比 | ⬜ 未开始 | 0% | — |

### 已完成项目

#### ✅ P1.1 - LSPDebouncer 防抖/节流器

- **文件**: `LSP/LSPDebouncer.swift`
- **状态**: ✅ 完成
- **功能**:
  - `debounce(key:delay:operation:)` — 延迟执行，新请求取消旧请求
  - `throttle(key:interval:operation:)` — 确保最小调用间隔
  - `cancel(key:)` / `cancelAll()` — 清理待执行任务
- **默认参数**: debounce 150ms, throttle 250ms

#### ✅ P1.2 - ExtensionResolver 后台聚合器

- **文件**: `Editor/ExtensionResolver.swift`
- **状态**: ✅ 完成
- **功能**:
  - `resolveCompletion(context:)` — 并行请求所有补全 contributor，后台去重排序
  - `resolveHover(context:)` — 并行请求所有 hover contributor，后台去重
  - `resolveCodeActions(context:)` — 并行请求所有代码动作 contributor，后台去重
  - 使用 `withTaskGroup` 并行请求，`Task.detached` 后台去重
- **线程模型**: @MainActor（与 @MainActor contributors 兼容），但去重/排序通过 `Task.detached` 移至后台

#### ✅ P1.3 - LSPService 集成 Debouncer

- **文件**: `LSP/LSPService.swift`
- **状态**: ✅ 完成（基础集成）
- **变更**:
  - 添加 `private let debouncer = LSPDebouncer()` 属性
  - `stopAll()` 中调用 `debouncer.cancelAll()` 清理待执行任务
  - 保留所有现有方法签名不变，确保向后兼容

#### ✅ P1.4 - EditorExtensionRegistry 线程注释

- **文件**: `Editor/EditorExtensionRegistry.swift`
- **状态**: ✅ 完成
- **变更**:
  - 添加线程模型文档注释
  - 明确标注同步方法 vs 异步方法

#### ✅ P1.5 - LSPCoordinator 后台请求包装

- **文件**: `LSP/LSPCoordinator.swift`
- **状态**: ✅ 完成
- **变更**:
  - 添加 `private let debouncer = LSPDebouncer()` 属性
  - `requestCompletionDebounced(line:character:)` — 补全请求防抖（50ms）
  - `requestHoverRawDebounced(line:character:)` — Hover 请求防抖（200ms）
  - `requestDocumentHighlightThrottled(line:character:)` — 文档高亮节流（250ms）
  - `requestCodeActionDebounced(range:diagnostics:)` — 代码动作防抖（300ms）
  - `requestSignatureHelpDebounced(line:character:)` — 签名帮助防抖（150ms）
  - `requestInlayHintThrottled(...)` — Inlay Hints 节流（500ms）
  - `requestFoldingRangeDebounced()` — 折叠范围防抖（1s）
  - 保留原有直接调用方法不变，确保向后兼容

#### ✅ P1.6 - SemanticTokenHighlightProvider 后台化

- **文件**: `LSP/LSPCoordinator.swift`
- **状态**: ✅ 完成
- **变更**:
  - `SemanticTokenMap.decodeInBackground(tokens:content:)` — 后台解码方法
  - 使用 `Task.detached` 将 Token 解码移至后台线程
  - `refreshSemanticTokens()` 调用 `decodeInBackground` 替代同步 `decode`
  - 大文件滚动时 token 解码不再阻塞主线程

#### ✅ P3.1 - WorkspaceEdit 文件操作后台化

- **文件**: `LSP/WorkspaceEditFileOperations.swift`
- **状态**: ✅ 完成
- **变更**:
  - 新增 `WorkspaceEditFileOperationsExecutor` actor（后台执行器）
  - `applyCreateFile/RenameFile/DeleteFile` — 后台文件操作
  - `applyWorkspaceEdit(_ edit:)` — 批量应用编辑（并行执行）
  - 保留原 `WorkspaceEditFileOperations` 静态方法，确保向后兼容

#### ✅ P4.1 - HoverCoordinator 防抖机制

- **文件**: `Editor/HoverCoordinator.swift`
- **状态**: ✅ 完成
- **说明**: HoverCoordinator 已实现完善的防抖机制：
  - 默认 350ms 延迟 + 快速窗口 120ms
  - Generation 版本号机制取消过期请求
  - Hover 缓存（最多 64 条，TTL 15s）
  - 滚动静止后重新触发（220ms）
  - 取消防抖（100ms）
  - 全局鼠标监控保持 popover 显示

#### ✅ P2.1 - EditorState 职责拆分

- **文件**: `Store/EditorUIState.swift` + `Store/EditorFileState.swift` + `Store/EditorPanelState.swift`
- **状态**: ✅ 完成
- **说明**: 子状态容器已创建：
  - `EditorUIState` — 字体、主题、显示选项、光标位置、多光标状态
  - `EditorFileState` — 文件 URL、内容、文件名/扩展名、语言检测、编辑状态、保存状态
  - `EditorPanelState` — Problems 面板、References 面板、Hover、工作区符号、调用层级
  - `EditorState` 保留所有 `@Published` 属性确保向后兼容，子容器作为组合属性暴露
  - 新代码可以通过 `state.uiState.fontSize` 或 `state.fontSize` 两种方式访问

#### ✅ P2.2 - LSPService.parseXxx() 纯计算方法优化

- **文件**: `LSP/LSPService.swift`
- **状态**: ✅ 完成
- **说明**: `parseLocationResponse()` 已标记 `nonisolated`，纯计算不阻塞 MainActor

### 待完成项目

#### ⬜ P5.1 - 集成测试

- 对 LSPDebouncer 的 debounce/throttle 行为编写单元测试
- 对 ExtensionResolver 的并行聚合和去重逻辑编写测试
- 对 WorkspaceEditFileOperationsExecutor 的文件操作编写测试
- 对 SemanticTokenMap.decodeInBackground 编写正确性测试

#### ⬜ P5.2 - 性能基准对比

- 使用 Instruments Time Profiler 对比优化前后的主线程占用
- 测量打字时 LSP 补全延迟
- 测量大文件滚动时语义高亮帧率
- 测量 Hover 防抖前后的事件频率

#### ⬜ P5.3 - 未来可选优化

- LSPService 从 `@MainActor` 迁移为 `actor LSPDispatcher`（高风险，需全面回归测试）
- MultiCursor 匹配算法后台化（当前在主线程但影响较小）
- LSP 结果缓存层（减少重复请求）
- 启动时插件扫描优化（缓存扫描结果）
