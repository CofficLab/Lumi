# Editor Kernel Refactor Plan

## 目标

把 Editor 内核收敛到和 Lumi 整体插件体系一致的模式：

1. 插件开发者只面向 `SuperPlugin`
2. 插件通过实现 `SuperPlugin` 上的高层 editor 能力函数来扩展编辑器
3. Editor 内核只认识 `SuperPlugin`
4. Editor 内核不直接依赖任何具体插件类型
5. `EditorExtensionRegistry`、provider、bridge 这类机制只作为内核内部实现细节存在

## 目标架构

最终希望插件作者的心智模型是：

```swift
actor MyEditorPlugin: SuperPlugin {
    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // 常规补全 / hover / code action / toolbar 等
    }

    @MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)? { ... }
    @MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)? { ... }
    @MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability] { ... }
}
```

也就是说：

- 对插件作者公开的是 `SuperPlugin`
- 对内核公开的是“高层能力函数”
- registry / provider 只是内核拿来聚合插件能力的实现方式

## 当前问题

现在编辑器体系只做到了“一部分一致”。

一致的地方：

- `SuperPlugin` 已经定义了 `providesEditorExtensions`
- 插件已经能通过 `registerEditorExtensions(into:)` 注入 editor 能力

不一致的地方：

1. `LSPServiceEditorPlugin` 直接依赖 `XcodeProjectContextBridge`
   - [LSPService.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/LSPServiceEditorPlugin/LSPService.swift)

2. `AgentEditorPlugin` 直接依赖 Xcode 具体实现
   - [EditorState.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Store/EditorState.swift)
   - [EditorState+LanguageActions.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Store/EditorState+LanguageActions.swift)
   - [EditorRootView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/EditorRootView.swift)

3. 内核状态模型和流程里仍然带有 `Xcode*` 命名
   - `xcodeContextSnapshot`
   - `XcodeSemanticAvailability`
   - `XcodeEditorContextSnapshot`

这意味着现在还是：

- 插件入口抽象了
- 运行时主链路还没有抽象

## 设计原则

1. `SuperPlugin` 是插件作者唯一需要理解的公开入口
2. editor 能力要提升到高层语义，而不是让插件作者理解内核细节
3. 内核只聚合能力，不认识插件名
4. 能力缺席时内核必须自然退化
5. 先做适配层，再迁主链路，最后删旧耦合

## 高层能力设计

建议把 editor 能力收敛成三类高层能力函数，直接挂在 `SuperPlugin` 上。

### 1. 项目上下文能力

职责：

- 项目打开 / 关闭
- 项目上下文重同步
- 当前文件的项目上下文快照

建议形态：

```swift
@MainActor
protocol SuperEditorProjectContextCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandleProject(at path: String?) -> Bool
    func projectOpened(at path: String) async
    func projectClosed()
    func resyncProjectContext() async
    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot?
    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?)
}
```

然后在 `SuperPlugin` 上新增：

```swift
@MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)?
```

### 2. 语义可用性能力

职责：

- 当前文件语义环境检查
- preflight message / error
- 语言能力不可用时的错误归类

建议形态：

```swift
@MainActor
protocol SuperEditorSemanticCapability: AnyObject {
    var id: String { get }
    var priority: Int { get }
    func canHandle(uri: String?) -> Bool
    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport
    func preflightMessage(uri: String?, operation: String, symbolName: String?, strength: EditorSemanticPreflightStrength) -> String?
    func preflightError(uri: String?, operation: String, symbolName: String?, strength: EditorSemanticPreflightStrength) -> EditorLanguageFeatureError?
}
```

然后在 `SuperPlugin` 上新增：

```swift
@MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)?
```

### 3. 语言服务项目集成能力

职责：

- 为某种语言生成 workspace folders
- 为某种语言生成 initialization options
- 控制项目型语言服务如何接到 editor 内核

建议形态：

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

然后在 `SuperPlugin` 上新增：

```swift
@MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability]
```

## 内核应该怎么消费这些能力

内核以后不该这样做：

- 直接写 `XcodeProjectContextBridge.shared`
- 直接写 `XcodeSemanticAvailability`
- 直接写 `XcodeLSPErrorTaxonomy`

内核应该这样做：

1. 从所有已启用 `SuperPlugin` 中收集高层能力
2. 按 `priority` 选择最匹配的能力实现
3. 通过能力接口驱动 editor 内核行为

也就是说，`EditorExtensionRegistry` 的角色会变成：

- 继续处理 completion / hover / code action / toolbar 这类 contributor 型能力
- 额外作为内核内部的能力聚合缓存
- 但它不再是插件作者需要直接理解的主要编程模型

## 重构阶段

## Phase 1: 定义高层能力模型

目标：先把最终要暴露给 `SuperPlugin` 的高层能力形状定下来。

清单：

- [x] 定义 `EditorProjectContextCapability`
- [x] 定义 `EditorSemanticCapability`
- [x] 定义 `EditorLanguageIntegrationCapability`
- [x] 定义通用模型：`EditorProjectContextSnapshot`
- [x] 定义通用模型：`EditorWorkspaceFolder`
- [x] 定义通用模型：`EditorLanguageFeatureError`
- [x] 在 `SuperPlugin` 上新增对应高层能力函数
- [x] 给这些函数补默认空实现

## Phase 2: 用内核内部适配层承接能力

目标：让内核先能从 `SuperPlugin` 聚合能力，但不要求插件作者立刻全部迁移。

清单：

- [x] `EditorPluginManager` 在安装插件时收集高层能力
- [x] `EditorExtensionRegistry` 内部支持缓存这些能力
- [x] `EditorExtensionRegistry` 提供统一的能力解析入口
- [x] 保留现有 registry contributor 机制不动
- [x] 明确 registry 是内核内部机制，不作为长期对外主模型

## Phase 3: 让 `LSPServiceEditorPlugin` 只依赖高层能力

目标：先切掉最关键的主链路耦合。

清单：

- [x] `LSPService` 不再直接调用 `XcodeProjectContextBridge`
- [x] `projectOpened` / `projectClosed` 改走 `EditorProjectContextCapability`
- [x] `workspaceFolders` 改走 `EditorLanguageIntegrationCapability`
- [x] `initializationOptions` 改走 `EditorLanguageIntegrationCapability`
- [x] `LSPServiceEditorPlugin` 中不再出现 `Xcode*` 直接引用

## Phase 4: 让 `AgentEditorPlugin` 只依赖高层能力

目标：把 editor 状态层从 Xcode 具体实现里抽出来。

清单：

- [x] `EditorState` 使用通用项目上下文快照
- [x] `EditorRootView` 不再直接调用 `XcodeProjectContextBridge`
- [x] `EditorState+LanguageActions` 改走 `SuperEditorSemanticCapability`
- [x] `EditorPanelState` 不再直接依赖 Xcode 语义 reason 类型
- [x] 内核中移除 `xcodeContextSnapshot` 这类专有命名

## Phase 5: 让 `XcodeProjectEditorPlugin` 只做实现

目标：把 Xcode 插件收敛成纯实现方。

清单：

- [x] `XcodeProjectEditorPlugin` 返回 `editorProjectContextCapability()`
- [x] `XcodeProjectEditorPlugin` 返回 `editorSemanticCapability()`
- [x] `XcodeProjectEditorPlugin` 返回 `editorLanguageIntegrationCapabilities()`
- [x] `XcodeProjectContextBridge` 从“全局入口”退化成插件内部实现细节
- [x] `XcodeSemanticAvailability` / `XcodeLSPErrorTaxonomy` 只作为插件内部实现

## Phase 6: 清理过渡层

目标：让插件作者真正只需要看 `SuperPlugin`。

清单：

- [x] 清理不再需要直接暴露的 provider 型接口（已移除 `registerProjectContextProvider`、`registerLanguageProjectIntegrationProvider`、`registerSemanticAvailabilityProvider` 三个别名方法及 `all*Providers()` 方法）
- [x] 统一内部存储和方法命名：`projectContextProviders` → `projectContextCapabilities`、`semanticAvailabilityProviders` → `semanticCapabilities`、`languageProjectIntegrationProviders` → `languageIntegrationCapabilities`；查询方法统一为 `projectContextCapability(for:)`、`semanticCapability(for:)`、`languageIntegrationCapability(for:)`
- [x] 保留必须存在的内核内部适配层（`EditorExtensionRegistry` 标注为「内核内部能力聚合」），不鼓励插件直接使用
- [x] 更新 editor 插件开发文档，只以 `SuperPlugin` 为入口讲解（见 `docs/plugins/AgentEditorPlugin/EDITOR_PLUGIN_DEVELOPMENT_GUIDE.md`）
- [x] 文档中包含最小示例插件骨架，证明只实现 `SuperPlugin` 就能接 editor 能力

## 迁移策略

这轮重构建议采用“双轨迁移”：

1. 先在 `SuperPlugin` 上加高层能力函数
2. 内核内部暂时仍可用适配层承接旧实现
3. `XcodeProjectEditorPlugin` 先通过适配器把现有 bridge / semantic / build context 包起来
4. 等主链路都切完，再删旧直接耦合

这样做的好处是：

- 不会一次性打碎现有 editor 能力
- 能边迁移边保持构建通过
- 能避免为了追求“纯”而在中途停机

## 完成标准

只有满足下面条件，才算这轮 editor 内核重构真正完成：

1. 插件作者扩展 editor 时，只需要看 `SuperPlugin`
2. `AgentEditorPlugin` 和 `LSPServiceEditorPlugin` 中不再直接引用任何 `Xcode*` 具体实现
3. 去掉 `XcodeProjectEditorPlugin` 后，editor 内核仍可正常运行，只是失去 Xcode 项目增强能力
4. `XcodeProjectEditorPlugin` 加回后，只通过 `SuperPlugin` 高层能力函数恢复能力

## 当前状态

**所有 6 个阶段已完成。** Editor 内核重构达到最终形态：

- [x] Phase 1-5: 高层能力模型定义、适配层、主链路迁出、实现方收敛
- [x] Phase 6: 过渡层清理、旧命名统一、开发文档和示例

### 完成标准验证

1. ✅ 插件作者扩展 editor 时，只需要看 `SuperPlugin`（开发指南：`docs/plugins/AgentEditorPlugin/EDITOR_PLUGIN_DEVELOPMENT_GUIDE.md`）
2. ✅ `AgentEditorPlugin` 和 `LSPServiceEditorPlugin` 中不再直接引用任何 `Xcode*` 具体实现
3. ✅ 去掉 `XcodeProjectEditorPlugin` 后，editor 内核仍可正常运行，只是失去 Xcode 项目增强能力
4. ✅ `XcodeProjectEditorPlugin` 加回后，只通过 `SuperPlugin` 高层能力函数恢复能力
