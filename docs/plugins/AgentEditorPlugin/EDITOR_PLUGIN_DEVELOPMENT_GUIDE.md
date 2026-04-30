# Editor 插件开发指南

> 本文档面向插件开发者，介绍如何通过 `SuperPlugin` 协议扩展 Lumi 编辑器能力。

---

## 核心理念

**插件开发者只需要理解 `SuperPlugin` 协议。**

编辑器能力通过 `SuperPlugin` 上的高层函数暴露。你不需要理解内核内部机制（如 `EditorExtensionRegistry`、`EditorPluginManager` 等），只需实现对应的协议方法即可。

---

## 快速开始：最小 Editor 插件

以下是一个完整的 editor 插件骨架，它提供代码补全能力：

```swift
import Foundation
import SwiftUI

/// 最小 Editor 插件示例
actor MyEditorPlugin: SuperPlugin {
    static let id = "MyEditor"
    static let displayName = "My Editor Plugin"
    static let description = "A minimal editor plugin example"
    static let iconName = "star.fill"
    static let order = 100
    static let enable = true
    static var isConfigurable: Bool { true }

    // 声明：本插件提供编辑器扩展
    nonisolated var providesEditorExtensions: Bool { true }

    // 注入常规编辑器扩展（补全、hover、code action 等）
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(MyCompletionContributor())
    }
}
```

只需实现 `providesEditorExtensions` 和 `registerEditorExtensions(into:)`，你的插件就会被 `PluginVM` 自动发现并安装到编辑器内核。

---

## 编辑器扩展点

### 1. 常规 Contributor 扩展

通过 `registerEditorExtensions(into:)` 注册各类 contributor：

```swift
@MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
    // 代码补全
    registry.registerCompletionContributor(MyCompletionContributor())

    // 悬浮提示（纯文本）
    registry.registerHoverContributor(MyHoverContributor())

    // 悬浮提示（Markdown 内容）
    registry.registerHoverContentContributor(MyHoverContentContributor())

    // 代码动作 / 快速修复
    registry.registerCodeActionContributor(MyCodeActionContributor())

    // 命令
    registry.registerCommandContributor(MyCommandContributor())

    // 右键菜单
    registry.registerContextMenuContributor(MyContextMenuContributor())

    // 侧边面板
    registry.registerSidePanelContributor(MySidePanelContributor())

    // 工具栏
    registry.registerToolbarContributor(MyToolbarContributor())

    // 状态栏
    registry.registerStatusItemContributor(MyStatusItemContributor())

    // 快速打开
    registry.registerQuickOpenContributor(MyQuickOpenContributor())

    // 设置项
    registry.registerSettingsContributor(MySettingsContributor())

    // 行号装饰
    registry.registerGutterDecorationContributor(MyGutterDecorationContributor())

    // 交互回调（文本变更、选区变更）
    registry.registerInteractionContributor(MyInteractionContributor())

    // 主题
    registry.registerThemeContributor(MyThemeContributor())
}
```

### 2. 项目上下文能力

如果你的插件能为特定项目类型提供上下文信息（如 Xcode 项目的 scheme/target 信息），可以实现 `editorProjectContextCapability()`：

```swift
@MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)? {
    MyProjectContextCapability()
}
```

**协议定义**：

```swift
@MainActor
protocol SuperEditorProjectContextCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }                    // 多个能力提供者时，高优先级优先
    func canHandleProject(at path: String?) -> Bool
    func projectOpened(at path: String) async
    func projectClosed()
    func resyncProjectContext() async
    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot?
    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?)
}
```

**适用场景**：
- 为 `.xcodeproj` / `.xcworkspace` 项目提供构建上下文
- 为其他构建系统（CMake、Cargo 等）提供项目结构信息
- 让编辑器内核了解当前文件的 target 归属

### 3. 语义可用性能力

如果你的插件能为特定语言提供语义环境检查（如 sourcekit-lsp 是否可用），可以实现 `editorSemanticCapability()`：

```swift
@MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)? {
    MySemanticCapability()
}
```

**协议定义**：

```swift
@MainActor
protocol SuperEditorSemanticCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandle(uri: String?) -> Bool
    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport
    func preflightMessage(uri: String?, operation: String, symbolName: String?, strength: EditorSemanticPreflightStrength) -> String?
    func preflightError(uri: String?, operation: String, symbolName: String?, strength: EditorSemanticPreflightStrength) -> EditorLanguageFeatureError?
    func missingResultMessage(uri: String?, operation: String, symbolName: String?) -> String?
}
```

**适用场景**：
- 检查语言服务是否就绪
- 在执行「跳转定义」「查找引用」「重命名」等操作前做 preflight 检查
- 提供语义功能不可用时的友好错误信息

### 4. 语言服务项目集成能力

如果你的插件需要为特定语言定制 LSP 启动参数（如 workspace folders、initialization options），可以实现 `editorLanguageIntegrationCapabilities()`：

```swift
@MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability] {
    [MyLanguageIntegrationCapability()]
}
```

**协议定义**：

```swift
@MainActor
protocol SuperEditorLanguageIntegrationCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func supports(languageId: String, projectPath: String?) -> Bool
    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]?
    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]?
}
```

**适用场景**：
- 为 sourcekit-lsp 提供 Xcode 项目的 workspace folders
- 为特定语言的 LSP 服务器传递项目特有的初始化参数
- 支持多种语言的项目集成

---

## 完整示例

```swift
import Foundation
import SwiftUI

/// 完整的 Editor 插件示例
actor ExampleEditorPlugin: SuperPlugin {
    static let id = "ExampleEditor"
    static let displayName = "Example Editor"
    static let description = "Demonstrates all editor extension points"
    static let iconName = "pencil.and.outline"
    static let order = 50
    static let enable = true
    static var isConfigurable: Bool { true }

    // MARK: - 声明编辑器扩展

    nonisolated var providesEditorExtensions: Bool { true }

    // MARK: - 常规 Contributor

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerCompletionContributor(ExampleCompletionContributor())
        registry.registerHoverContributor(ExampleHoverContributor())
    }

    // MARK: - 项目上下文能力

    @MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)? {
        ExampleProjectContextCapability()
    }

    // MARK: - 语义能力

    @MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)? {
        ExampleSemanticCapability()
    }

    // MARK: - 语言集成能力

    @MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability] {
        [ExampleLanguageIntegrationCapability()]
    }
}
```

---

## 工作原理

插件开发者不需要深入理解以下机制，但了解它们有助于更好地设计插件：

1. **`PluginVM`** 在启动时自动发现所有 `SuperPlugin` 实现
2. 如果插件的 `providesEditorExtensions == true`，`PluginVM` 会将其传递给 `EditorPluginManager`
3. `EditorPluginManager` 调用插件上的 `registerEditorExtensions`、`editorProjectContextCapability()` 等方法
4. 注册的能力被缓存到 `EditorExtensionRegistry` 中
5. 编辑器内核按 `priority` 选择最匹配的能力实现来驱动行为

---

## 最佳实践

1. **只实现你需要的能力** — 所有高层能力函数都有默认空实现，不需要的返回 `nil` 或 `[]` 即可
2. **合理设置 `priority`** — 如果多个插件提供同类能力，高 `priority` 的会被优先选用
3. **做好 `canHandle` 检查** — 在能力协议的 `canHandle` / `canHandleProject` / `supports` 方法中精确匹配，避免误拦截
4. **能力缺席时优雅降级** — 内核已经处理了能力为空的情况，你的插件不需要额外担心
5. **遵循边界规范** — 插件之间不得相互依赖，共享逻辑应下沉到内核

---

## 参考

- [`SuperPlugin`](/LumiApp/Core/Proto/SuperPlugin.swift) — 插件主协议
- [`SuperPlugin+Editor`](/LumiApp/Core/Proto/SuperPlugin+Editor.swift) — editor 能力默认实现
- [`SuperEditorCapabilities`](/LumiApp/Core/Proto/SuperEditorCapabilities.swift) — 高层能力协议和模型定义
- [`XcodeProjectEditorPlugin`](/LumiApp/Plugins/XcodeProjectEditorPlugin/) — 完整的参考实现
