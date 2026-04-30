# Editor Kernel Plugin Boundary Refactor Plan

## 目标

把 `AgentEditorPlugin` 和编辑器相关基础设施收敛成纯内核层。

重构完成后，内核只负责：

1. 定义编辑器扩展点
2. 定义通用协议和数据模型
3. 提供插件注册、发现、调用机制

内核不再负责：

1. 直接引用任何具体插件类型
2. 直接调用任何插件单例
3. 直接持有任何插件专属命名的数据模型

## 目标状态

目标架构是：

- `AgentEditorPlugin`
  - 定义 `EditorExtensionRegistry`
  - 定义编辑器扩展协议
  - 定义项目上下文、语义可用性、语言服务初始化所需的通用协议
- `LSPServiceEditorPlugin`
  - 只依赖编辑器内核协议
  - 不知道 `XcodeProjectEditorPlugin` 是否存在
- `XcodeProjectEditorPlugin`
  - 实现 Xcode 项目识别、build context、semantic preflight、workspace folders、initialization options
  - 通过协议注册到内核

## 当前问题

目前还没有达到这个边界，主要耦合点如下：

1. `LSPServiceEditorPlugin` 直接依赖 `XcodeProjectContextBridge`
   - [LSPService.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/LSPServiceEditorPlugin/LSPService.swift)
   - 直接调用 `projectOpened`、`projectClosed`、`makeWorkspaceFolders`、`makeInitializationOptions`

2. `AgentEditorPlugin` 直接依赖 Xcode 具体类型
   - [EditorState.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Store/EditorState.swift)
   - [EditorState+LanguageActions.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Store/EditorState+LanguageActions.swift)
   - [EditorRootView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/EditorRootView.swift)

3. 内核状态模型带有 Xcode 专属命名
   - `xcodeContextSnapshot`
   - `refreshXcodeContextSnapshot`
   - `XcodeEditorContextSnapshot`

4. 语义预检能力没有抽象成内核协议
   - `XcodeSemanticAvailability`
   - `XcodeLSPErrorTaxonomy`

这说明当前是“扩展点注册是插件式的”，但“项目上下文主链路仍然是内核知道 Xcode 插件实现”。

## 设计原则

1. 内核只面向能力，不面向插件名
2. 通用模型不使用 `Xcode*` 命名
3. 一个能力一组协议，不把所有职责塞进一个大接口
4. 插件可以缺席，内核照常工作
5. 先加抽象层，再迁调用点，最后删旧入口

## 核心抽象

建议在 `AgentEditorPlugin` 内核层新增以下协议和模型。

### 项目上下文

```swift
@MainActor
protocol EditorProjectContextProvider: AnyObject {
    var id: String { get }
    func projectOpened(at path: String) async
    func projectClosed()
    func resyncProjectContext() async
    func makeEditorContextSnapshot(currentFileURL: URL?) -> EditorProjectContextSnapshot?
    func updateLatestEditorSnapshot(_ snapshot: EditorProjectContextSnapshot?)
}
```

```swift
struct EditorProjectContextSnapshot: Equatable, Sendable {
    let projectPath: String
    let workspaceName: String
    let workspacePath: String
    let activeScheme: String?
    let activeConfiguration: String?
    let activeDestination: String?
    let contextStatus: String
    let isStructuredProject: Bool
    let currentFilePath: String?
    let currentFilePrimaryTarget: String?
    let currentFileMatchedTargets: [String]
    let currentFileIsInTarget: Bool
}
```

### 语言服务项目集成

```swift
@MainActor
protocol EditorLanguageProjectIntegrationProvider: AnyObject {
    var id: String { get }
    func supports(languageId: String) -> Bool
    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]?
    func initializationOptions(for languageId: String) -> [String: String]?
}
```

### 语义可用性

```swift
@MainActor
protocol EditorSemanticAvailabilityProvider: AnyObject {
    var id: String { get }
    func inspectCurrentFileContext(uri: String?) -> EditorSemanticAvailabilityReport
    func preflightMessage(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> String?
    func preflightError(
        uri: String?,
        operation: String,
        symbolName: String?,
        strength: EditorSemanticPreflightStrength
    ) -> EditorLanguageFeatureError?
}
```

### 内核注册中心

建议给 `EditorExtensionRegistry` 或平级内核容器补这几类注册入口：

- `registerProjectContextProvider`
- `registerLanguageProjectIntegrationProvider`
- `registerSemanticAvailabilityProvider`

同时提供当前激活 provider 的解析策略：

1. 按 `languageId` / `projectPath` 过滤
2. 多个 provider 时按 `priority` 或注册顺序选一个
3. 没有 provider 时返回空能力

## 分阶段方案

## Phase 1: 先定义内核协议和通用模型

目标：先把边界定义出来，不急着迁实现。

清单：

- [x] 新增 `EditorProjectContextProvider`
- [x] 新增 `EditorLanguageProjectIntegrationProvider`
- [x] 新增 `EditorSemanticAvailabilityProvider`
- [x] 新增 `EditorProjectContextSnapshot`
- [x] 新增 `EditorWorkspaceFolder`
- [x] 新增 `EditorLanguageFeatureError`
- [x] 在内核注册中心增加对应 provider 注册入口
- [x] 允许 provider 缺席时内核退化为 no-op

## Phase 2: 把 `LSPServiceEditorPlugin` 改成只依赖协议

目标：先切掉语言服务层对 Xcode 具体实现的直接依赖。

清单：

- [ ] `LSPService` 不再直接调用 `XcodeProjectContextBridge.shared`
- [ ] `LSPService` 改为读取 `EditorLanguageProjectIntegrationProvider`
- [ ] `projectOpened` / `projectClosed` 生命周期改为经由 `EditorProjectContextProvider`
- [ ] `workspaceFolders` 生成改为经由协议
- [ ] `initializationOptions` 生成改为经由协议
- [ ] 确认没有 `Xcode*` 类型出现在 `LSPServiceEditorPlugin`

## Phase 3: 把 `AgentEditorPlugin` 状态层改成通用命名

目标：清掉内核状态模型里的 Xcode 专属命名和直接依赖。

清单：

- [ ] `xcodeContextSnapshot` 重命名为通用上下文字段
- [ ] `refreshXcodeContextSnapshot()` 改为通用刷新入口
- [ ] `EditorRootView` 不再直接调用 `XcodeProjectContextBridge`
- [ ] `EditorState+LanguageActions` 改为调用 `EditorSemanticAvailabilityProvider`
- [ ] `EditorPanelState` 不再依赖 `XcodeSemanticAvailability.Reason`
- [ ] 确认 `AgentEditorPlugin` 不再直接引用 `XcodeProjectContextBridge`

## Phase 4: 让 `XcodeProjectEditorPlugin` 实现协议

目标：把现有 Xcode 能力收敛成插件实现，而不是内核特例。

清单：

- [ ] `XcodeProjectContextBridge` 实现 `EditorProjectContextProvider`
- [ ] Xcode build context / workspace folders 适配到 `EditorLanguageProjectIntegrationProvider`
- [ ] `XcodeSemanticAvailability` 适配到 `EditorSemanticAvailabilityProvider`
- [ ] `XcodeLSPErrorTaxonomy` 输出适配到通用 `EditorLanguageFeatureError`
- [ ] `XcodeProjectEditorPlugin` 在注册阶段完成这些 provider 注入

## Phase 5: 删除旧耦合入口

目标：完成收尾，防止未来回流耦合。

清单：

- [ ] 删除内核中残留的 `Xcode*` 直接引用
- [ ] 禁止新的插件专属类型进入 `AgentEditorPlugin`
- [ ] 为内核协议层补单元测试
- [ ] 为“无项目集成插件”场景补回归测试
- [ ] 为“Xcode 插件存在”场景补集成测试

## 实施顺序建议

建议按下面顺序推进：

1. 先做 Phase 1
2. 再做 Phase 2
3. 然后做 Phase 3
4. 再做 Phase 4
5. 最后做 Phase 5

这样做的原因是：

- 先稳定协议，再迁调用点，风险最小
- `LSPService` 是最关键的解耦点，应先脱离 Xcode 具体实现
- `EditorState` 的命名和状态迁移会更大，放在第二波更安全

## 完成标准

满足以下条件，才算这个内核重构完成：

1. `AgentEditorPlugin` 和 `LSPServiceEditorPlugin` 中不再出现对 `XcodeProjectEditorPlugin` 具体类型的直接引用
2. 内核层不再出现 `Xcode*` 命名的公共状态模型
3. 移除 `XcodeProjectEditorPlugin` 后，编辑器仍能正常运行，只是没有 Xcode 项目增强能力
4. 加回 `XcodeProjectEditorPlugin` 后，Xcode 项目能力通过协议恢复

## 暂不处理

本轮内核重构先不处理以下问题：

- [ ] `Cmd+Click` 真实工程可用性细节
- [ ] scheme switch 具体行为优化
- [ ] sourcekit-lsp 失败恢复细节
- [ ] Xcode 项目功能继续扩展

这些都应放在内核边界清理完成后，再专注推进插件实现。
