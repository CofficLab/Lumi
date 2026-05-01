# Editor Kernel Migration Plan

> 将编辑器内核从 `AgentEditorPlugin` 迁入 `Core/Services/EditorService`，让编辑器成为 App Core 的正式能力。
> 本版是“可执行施工计划”，重点是降低编译风险、减少大爆炸迁移，并且**暂不考虑单元测试迁移**。

## 这版计划解决什么问题

原始方案的方向是对的，但执行上有 4 个明显风险：

1. 把“复制文件并存”作为起步步骤，容易在同一 module 内造成重名类型冲突。
2. 把“搬文件”当成主线，却没有先处理真正的耦合边界。
3. 低估了 `EditorState`、`EditorExtensionRegistry`、`EditorPluginManager.activeRegistry`、`EditorJumpToDefinitionDelegate` 这些枢纽点的风险。
4. 把测试目录迁移和架构迁移绑在一起，增加了无关复杂度。

因此，这版计划采用三个原则：

- **先改依赖边界，再移动文件路径**
- **先抽稳定接口，再迁重实现**
- **每一步都要求可编译、可手动验证、可独立回滚**

---

## 当前已确认的真实耦合

以下耦合决定了迁移不能只靠机械移动文件：

- `Core/Proto/SuperPlugin.swift` 直接暴露 `EditorExtensionRegistry`
- `EditorExtensionRegistry` 不只保存 contributor，还直接依赖 `EditorState`
- `EditorState` 持有 `EditorPluginManager`，并在内部安装 editor 扩展插件
- `EditorPluginManager.activeRegistry` 被 `LSPServiceEditorPlugin` 等插件侧逻辑直接读取
- `TextViewBridge`、`EditorCoordinator`、`EditorState` 直接引用 `EditorJumpToDefinitionDelegate`
- `EditorJumpToDefinitionDelegate` 目前定义在 `LSPContextCommandsEditorPlugin` 中，但被编辑器内核代码反向依赖

这意味着迁移的第一目标不是“把 169 个文件搬到新目录”，而是先把这些边界调整正确。

---

## 范围与非目标

### 本次范围

- 将编辑器内核代码迁入 `Core/Services/EditorService`
- 纠正 Core → Plugin 的依赖方向
- 将 `AgentEditorPlugin` 缩减为 UI 外壳插件
- 保持现有功能可手动验证

### 本次不做

- 不迁移单元测试目录
- 不新建 `CoreTests`
- 不顺手重写 editor 扩展协议
- 不在这次迁移里做功能重构或 UI 改版

---

## 目标架构

```text
Core/
  Services/EditorService/
    Protocols/
    Registry/
    Store/
    Kernel/
    Editor/
    Workbench/
    Views/
    Utilities/

Plugins/
  AgentEditorPlugin/
    EditorPlugin.swift
    LumiEditor.xcstrings
```

迁移完成后，依赖方向应为：

```text
Core editor kernel  ->  被插件调用/扩展
Plugins             ->  依赖 Core 提供的 editor protocols / registry / state
```

而不是：

```text
Core/Proto/SuperPlugin -> 依赖 AgentEditorPlugin 内类型
```

---

## 施工策略

整次迁移分成 6 个可落地阶段：

1. 建立新目录与命名空间，但不复制同名类型
2. 先迁协议与注册中心边界
3. 清理跨插件反向依赖
4. 迁移运行时核心对象：`EditorPluginManager`、`EditorState`
5. 分批迁移 Kernel / Workbench / Views / Utilities
6. 瘦身 `AgentEditorPlugin`

每个阶段的结束标准都只有 3 个：

- 能编译
- 能启动
- 能完成对应的手动冒烟验证

---

## Phase 0 — 建立落点，但不制造重名类型

> 目标：先把新目录准备好，但**不做同名文件复制共存**

- [ ] 创建目录 `LumiApp/Core/Services/EditorService/`
- [ ] 创建子目录：
  - `Protocols/`
  - `Registry/`
  - `Store/`
  - `Kernel/`
  - `Editor/`
  - `Workbench/`
  - `Views/`
  - `Utilities/`
- [ ] 在目录中添加一个占位文档或占位 Swift 文件，确保 Xcode 工程能纳入新分组
- [ ] 约定迁移方式：
  - 不采用“先复制，再靠 typealias/重命名消冲突”
  - 采用“单文件移动或移动后立即删除旧引用”的方式

### Phase 0 验证

- [ ] Xcode 工程可打开
- [ ] App 可编译

---

## Phase 1 — 先修依赖边界，不急着搬大文件

> 目标：消除最关键的 Core → Plugin 依赖倒置

### 1.1 先迁协议层

- [ ] 移动 `Protocols/EditorExtensionContributors.swift` → `Core/Services/EditorService/Protocols/`
- [ ] 移动 `Protocols/EditorLSPClient.swift` → `Core/Services/EditorService/Protocols/`
- [ ] 移动 `Protocols/EditorThemeContributor.swift` → `Core/Services/EditorService/Protocols/`

### 1.2 迁移协议直接依赖的小型基础类型

先只迁那些被协议或 registry 直接引用、且相对独立的类型：

- [ ] `Kernel/EditorGutterDecoration.swift`
- [ ] `Kernel/EditorFindMatch.swift`
- [ ] `Kernel/EditorInlinePresentation.swift`
- [ ] `Kernel/EditorSurfaceOverlayPalette.swift`
- [ ] `Kernel/EditorHoverOverlayStyle.swift`
- [ ] `Kernel/EditorCodeActionOverlayStyle.swift`
- [ ] `Kernel/EditorCommandCategory.swift`
- [ ] `Kernel/EditorCommandSection.swift`
- [ ] `Kernel/EditorCommandInvocationContext.swift`
- [ ] `Kernel/EditorCommandPresentationModel.swift`
- [ ] `Kernel/EditorStatusMessageCatalog.swift`
- [ ] `Kernel/LargeFileMode.swift`
- [ ] `Kernel/EditorPerformance.swift`
- [ ] `Kernel/EditorCursorState.swift`
- [ ] `Kernel/EditorSelectionSet.swift`
- [ ] `Kernel/EditorSelectionMapper.swift`
- [ ] `Kernel/EditorInlineRenameState.swift`
- [ ] `Kernel/EditorSnippetSession.swift`
- [ ] `Kernel/EditorSnippetParser.swift`
- [ ] `Kernel/EditorTransaction.swift`
- [ ] `Kernel/EditorMinimapPolicy.swift`

### 1.3 迁移注册中心

- [ ] 移动 `Editor/EditorExtensionRegistry.swift` → `Core/Services/EditorService/Registry/`
- [ ] 移动 `Editor/ExtensionResolver.swift` → `Core/Services/EditorService/Registry/`
- [ ] 更新 `Core/Proto/SuperPlugin.swift`
- [ ] 更新 `Core/Proto/SuperPlugin+Editor.swift`

### 1.4 Phase 1 的关键约束

- `EditorExtensionRegistry` 迁移后，`SuperPlugin` 不得再引用 `AgentEditorPlugin` 路径下的任意 editor 类型
- 如果 `Registry` 还依赖 `EditorState`，这是允许的，但 `EditorState` 的定义位置将成为下一阶段优先事项

### Phase 1 验证

- [ ] 全量编译通过
- [ ] 抽查至少 3 个 editor 扩展插件仍能编译：
  - `LSPServiceEditorPlugin`
  - `SampleDecorationEditorPlugin`
  - `ThemeMidnightPlugin`

---

## Phase 2 — 先拆跨插件反向依赖

> 目标：把“Core editor kernel 反向依赖某个 editor 子插件”的问题先处理掉

这是整次迁移里最容易被忽略、但最该先处理的阶段。

### 2.1 处理 `EditorJumpToDefinitionDelegate`

当前问题：

- `EditorJumpToDefinitionDelegate` 定义在 `LSPContextCommandsEditorPlugin`
- 但 `TextViewBridge`、`EditorCoordinator`、`EditorState`、`SourceEditorView` 在反向依赖它

执行建议：

- [ ] 将 `EditorJumpToDefinitionDelegate` 移入 `Core/Services/EditorService/Editor/`，因为它本质上是 editor runtime 的交互桥接对象
- [ ] 仅把“LSP/AST/regex 找定义”的策略保留为它的内部实现
- [ ] 如果某些插件还要定制跳转能力，改为通过 protocol/capability 注入，而不是让 Core 依赖插件里的具体类

### 2.2 处理 `EditorPluginManager.activeRegistry`

当前问题：

- 插件侧代码把 `EditorPluginManager.activeRegistry` 当作一个全局访问点
- 这会让 `EditorPluginManager` 的存放位置变成整个系统的编译枢纽

执行建议：

- [ ] 将 `EditorPluginManager` 也视为 editor core 运行时对象，准备在下一阶段迁入 Core
- [ ] 暂时保留 `activeRegistry` 这个兼容入口，但把它迁到 Core 实现中
- [ ] 本次迁移不强行消灭 `activeRegistry`，只要求它不再定义在 `AgentEditorPlugin`

### Phase 2 验证

- [ ] 全量编译通过
- [ ] 手动验证 Cmd+Click / 跳转到定义功能仍可触发

---

## Phase 3 — 迁移运行时核心：`EditorPluginManager` 与 `EditorState`

> 目标：先迁真正的运行时中枢，再迁散落的实现文件

### 3.1 先迁 `EditorPluginManager`

- [ ] 移动 `Editor/EditorPluginManager.swift` → `Core/Services/EditorService/Editor/`
- [ ] 保持 `activeRegistry` 行为兼容
- [ ] 保持“根据 `providesEditorExtensions` 安装插件”的逻辑不变

### 3.2 迁移 `Store` 中的支撑类型

优先迁移 `EditorState` 明确依赖、但风险较低的 Store 文件：

- [ ] `Store/EditorUIState.swift`
- [ ] `Store/EditorFileState.swift`
- [ ] `Store/EditorPanelState.swift`
- [ ] `Store/EditorSettingsState.swift`
- [ ] `Store/EditorFileTreeStore.swift`
- [ ] `Store/EditorConfigStore.swift`
- [ ] `Store/EditorSurfaceHighlightSupport.swift`
- [ ] `Store/String+EditorPreviewLines.swift`
- [ ] `Store/ReferenceResult.swift`
- [ ] `Store/EditorStateSupportTypes.swift`
- [ ] `Store/EditorState+SaveWorkflow.swift`
- [ ] `Store/EditorState+WorkspaceSearch.swift`
- [ ] `Store/EditorState+LanguageActions.swift`

### 3.3 再迁 `EditorState.swift`

- [ ] 移动 `Store/EditorState.swift` → `Core/Services/EditorService/Store/`
- [ ] 迁移后优先修复以下编译关系：
  - `EditorState` ↔ `EditorPluginManager`
  - `EditorState` ↔ `EditorExtensionRegistry`
  - `EditorState` ↔ `EditorJumpToDefinitionDelegate`
  - `EditorState` ↔ `SourceEditorState`

### 3.4 Phase 3 的成功标准

- `EditorState` 已位于 Core
- 插件贡献能力仍通过 registry 正常安装
- 没有任何 editor runtime 核心对象继续定义在 `AgentEditorPlugin/Store` 或 `AgentEditorPlugin/Editor` 中

### Phase 3 验证

- [ ] 全量编译通过
- [ ] 手动验证：
  - 打开文件
  - 编辑文本
  - 切换标签
  - 保存文件
  - 基本命令面板可用

---

## Phase 4 — 分批迁移 Kernel，而不是一次搬 80 个文件

> 目标：按依赖簇迁移 Kernel，降低回归面

不建议“一口气迁完 80 个文件”。建议按功能簇迁移，每簇完成后立刻编译和手测。

### 4.1 命令与输入簇

- [ ] `Kernel/CommandRegistry.swift`
- [ ] `Kernel/CommandRouter.swift`
- [ ] `Kernel/CoreCommandRegistrations.swift`
- [ ] `Kernel/EditorCommandController.swift`
- [ ] `Kernel/EditorInputCommandController.swift`
- [ ] `Kernel/EditorKeybindingStore.swift`
- [ ] `Kernel/EditorShortcutCatalog.swift`
- [ ] `Kernel/EditorSettingsCatalog.swift`
- [ ] `Kernel/EditorSettingsQuickOpenController.swift`
- [ ] `Kernel/EditorTextInputController.swift`

手动验证：

- [ ] 命令面板
- [ ] 快捷键
- [ ] 文本输入

### 4.2 文档编辑与保存簇

- [ ] `Kernel/EditorDocumentController.swift`
- [ ] `Kernel/EditorDocumentReplaceController.swift`
- [ ] `Kernel/EditorTransactionController.swift`
- [ ] `Kernel/EditorBuffer.swift`
- [ ] `Kernel/EditorUndoController.swift`
- [ ] `Kernel/EditorUndoManager.swift`
- [ ] `Kernel/EditorSaveController.swift`
- [ ] `Kernel/EditorSaveParticipantController.swift`
- [ ] `Kernel/EditorSavePipelineController.swift`
- [ ] `Kernel/EditorSaveStateController.swift`
- [ ] `Kernel/EditorSaveWorkflowController.swift`
- [ ] `Kernel/EditorFormattingController.swift`
- [ ] `Kernel/TextEditApplier.swift`
- [ ] `Kernel/TextEditTransactionBuilder.swift`
- [ ] `Kernel/LineEditingController.swift`
- [ ] `Kernel/BracketAndIndent.swift`

手动验证：

- [ ] 编辑
- [ ] 撤销重做
- [ ] 保存
- [ ] 格式化

### 4.3 查找、选区、多光标簇

- [ ] `Kernel/EditorFindController.swift`
- [ ] `Kernel/EditorFindReplaceController.swift`
- [ ] `Kernel/EditorFindReplaceTransactionBuilder.swift`
- [ ] `Kernel/CursorMotionController.swift`
- [ ] `Kernel/EditorCursorController.swift`
- [ ] `Kernel/EditorMultiCursorController.swift`
- [ ] `Kernel/EditorMultiCursorWorkflowController.swift`
- [ ] `Kernel/EditorMultiCursorOverlay.swift`
- [ ] `Kernel/MultiCursorTransactionBuilder.swift`

手动验证：

- [ ] 查找替换
- [ ] 光标移动
- [ ] 多光标

### 4.4 LSP 与语言能力簇

- [ ] `Kernel/LSPRequestPipeline.swift`
- [ ] `Kernel/LSPViewportScheduler.swift`
- [ ] `Kernel/EditorLSPActionController.swift`
- [ ] `Kernel/EditorLanguageActionFacade.swift`
- [ ] `Kernel/EditorRenameController.swift`
- [ ] `Kernel/EditorWorkspaceEditController.swift`
- [ ] `Kernel/EditorQuickOpenController.swift`
- [ ] `Kernel/EditorCallHierarchyController.swift`
- [ ] `Kernel/EditorWorkspaceSearchController.swift`
- [ ] `Kernel/DocumentSymbolProvider.swift`
- [ ] `Kernel/EditorPeekController.swift`

手动验证：

- [ ] 补全
- [ ] Hover
- [ ] Code Action
- [ ] Rename
- [ ] Jump to Definition
- [ ] Workspace Search

### 4.5 UI 状态与外部文件簇

- [ ] `Kernel/EditorPanelController.swift`
- [ ] `Kernel/EditorFoldingController.swift`
- [ ] `Kernel/EditorSessionController.swift`
- [ ] `Kernel/EditorOverlayController.swift`
- [ ] `Kernel/EditorAppearanceController.swift`
- [ ] `Kernel/EditorRuntimeModeController.swift`
- [ ] `Kernel/EditorStatusToastController.swift`
- [ ] `Kernel/EditorExternalFileController.swift`
- [ ] `Kernel/EditorExternalFileWorkflowController.swift`
- [ ] `Kernel/EditorFileWatcherController.swift`
- [ ] `Kernel/EditorFileTreeRefreshCoordinator.swift`
- [ ] `Kernel/EditorFileTreeWatcher.swift`
- [ ] `Kernel/EditorConfigController.swift`

手动验证：

- [ ] 折叠
- [ ] 面板状态
- [ ] 外部文件变更提示
- [ ] 文件树刷新

### Phase 4 验证

- [ ] 每个功能簇迁完都全量编译
- [ ] 每个功能簇迁完都做对应手动验证

---

## Phase 5 — 迁移桥接层、Workbench、Views、Utilities

> 目标：当运行时核心已经稳定后，再迁 UI 和外围结构

### 5.1 桥接层

- [ ] `Editor/EditorCoordinator.swift`
- [ ] `Editor/EditorInputRouter.swift`
- [ ] `Editor/SourceEditorAdapter.swift`
- [ ] `Editor/ScrollCoordinator.swift`
- [ ] `Editor/TextViewBridge.swift`

### 5.2 Workbench

- [ ] 迁移 `Workbench/*.swift`
- [ ] 优先检查 `EditorSession`、`EditorGroup`、`EditorTab`、`EditorNavigationController` 等核心类型

### 5.3 Utilities

- [ ] `Utilities/EditorThemeAdapter.swift`
- [ ] `Utilities/LineOffsetTable.swift`
- [ ] `Utilities/EditorFileTreeService.swift`

### 5.4 Views

普通 editor 视图应迁入 Core：

- [ ] `EditorPanelView`
- [ ] `EditorRootView`
- [ ] `EditorRootOverlay`
- [ ] `SourceEditorView`
- [ ] `EditorCommandPaletteView`
- [ ] 其余 editor runtime 视图

需要单独判断是否留在插件壳中的视图：

- [ ] `EditorLoadedPluginsView`

判定原则：

- 如果它展示的是“editor core 自身状态”，迁入 Core
- 如果它展示的是“插件壳的管理入口”，可以保留在 `AgentEditorPlugin`

### Phase 5 验证

- [ ] 全量编译通过
- [ ] 编辑器主界面正常渲染
- [ ] 多分栏/多标签正常
- [ ] 状态栏与面板入口正常

---

## Phase 6 — 瘦身 `AgentEditorPlugin`

> 目标：插件只剩壳，不再承载 editor 内核实现

- [ ] 删除已迁空目录：
  - `Protocols/`
  - `Editor/`
  - `Store/`
  - `Kernel/`
  - `Workbench/`
  - `Views/`
  - `Utilities/`
- [ ] 检查 `EditorPlugin.swift` 只保留壳层职责：
  - `addRootView()`
  - `addPanelView()`
  - `addStatusBarTrailingView()`，如果这个入口仍有保留必要
  - `panelNeedsSidebar = true`
- [ ] 确认 `EditorPlugin` 本身不是 editor 扩展提供者
- [ ] 最终目录尽量收敛到：
  - `EditorPlugin.swift`
  - `LumiEditor.xcstrings`
  - 以及确实必须留在插件壳的少量展示视图

### Phase 6 验证

- [ ] 全量编译通过
- [ ] 手动完整冒烟：
  - 打开文件
  - 编辑
  - 保存
  - 补全
  - Hover
  - Jump to Definition
  - Code Action
  - 命令面板
  - 多光标
  - 外部文件冲突提示

---

## 手动验证清单

由于本次暂不考虑单元测试迁移，必须把手动验证写得更明确。

### 每阶段通用

- [ ] App 能启动
- [ ] 编辑器面板能打开
- [ ] 当前工程能正常打开一个文本文件

### 核心编辑能力

- [ ] 输入文本
- [ ] 删除文本
- [ ] 撤销/重做
- [ ] 保存
- [ ] 文件失焦自动保存行为正常

### 导航与命令

- [ ] 命令面板打开
- [ ] Quick Open 可用
- [ ] 多标签切换
- [ ] 多分栏切换

### 语言能力

- [ ] 补全
- [ ] Hover
- [ ] Code Action
- [ ] Rename
- [ ] Jump to Definition

### 复杂场景

- [ ] 多光标
- [ ] 查找替换
- [ ] 外部文件改动检测
- [ ] 大文件保护模式未明显退化

---

## 回滚策略

- 每个 Phase 单独提交
- 每个功能簇单独提交
- 一旦某簇迁移后编译面过大，不继续推进下一簇，先在当前簇内收敛
- 不做跨多个阶段的大合并提交

建议分支名：

- `codex/editor-kernel-migration`

---

## 完成标志

满足以下条件即可认为迁移完成：

- `SuperPlugin` 不再依赖 `AgentEditorPlugin` 中的 editor 类型
- `EditorState`、`EditorExtensionRegistry`、`EditorPluginManager`、`EditorJumpToDefinitionDelegate` 已进入 Core
- editor runtime 的主要实现位于 `Core/Services/EditorService`
- `AgentEditorPlugin` 只保留 UI 外壳职责
- 手动冒烟流程通过

---

## 一句话执行顺序

先迁协议和 registry，接着拆掉跨插件反向依赖，再迁 `EditorPluginManager` 和 `EditorState`，之后按功能簇迁 Kernel，最后再迁 UI 与瘦身插件壳。
