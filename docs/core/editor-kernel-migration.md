# Editor Kernel Migration Plan

> 将编辑器内核从 `AgentEditorPlugin` 插件中迁移到 `Core/Services/EditorService`，使编辑器成为 App 内核的一部分。
> `AgentEditorPlugin` 最终简化为一个普通插件，仅提供 Panel 视图路由。

## 背景

### 当前架构问题

```
Core/Proto/SuperPlugin.swift  →  引用  →  AgentEditorPlugin/Editor/EditorExtensionRegistry
        ↑                                           ↓
        | 依赖倒置                              包含 EditorState、
        |                                   60 个 Kernel 控制器、
        ↓                                   25 个 View、35 个 Workbench 组件
   80+ 个外部插件通过 registerEditorExtensions(into:) 向插件内部的 Registry 注入能力
```

- **依赖倒置**：`SuperPlugin`（Core 层）的 `registerEditorExtensions(into:)` 参数类型是 `EditorExtensionRegistry`，该类定义在 AgentEditorPlugin 中 → Core 依赖了 Plugin
- **职责错位**：编辑器内核（文件管理、光标、命令、LSP 集成、保存管线等）是 App 核心能力，不应藏在一个插件中
- **扩展性受阻**：80+ 个编辑器扩展插件（LSP、主题、补全等）的注册中心在一个插件内部

### 目标架构

```
Core/
  Services/EditorService/          ← 编辑器内核（从 AgentEditorPlugin 迁入）
    Protocols/                     ← 扩展点协议
    Registry/                      ← EditorExtensionRegistry
    Kernel/                        ← 80 个控制器
    Store/                         ← EditorState 等
    Views/                         ← 25 个视图
    Workbench/                     ← 35 个工作台组件
    Editor/                        ← 桥接/协调层
    Utilities/                     ← 工具类

Core/Proto/
  SuperPlugin.swift                ← 引用 Core 层的 Registry（依赖方向正确）

Plugins/AgentEditorPlugin/         ← 瘦身为普通插件
  EditorPlugin.swift               ← 仅保留 SuperPlugin 入口 + Panel 视图路由
```

---

## 迁移统计

| 模块 | 文件数 | 说明 |
|------|--------|------|
| Protocols/ | 3 | 扩展点协议（Contributor、LSP Client、Theme） |
| Editor/ | 8 | Registry、Coordinator、Bridge、Resolver 等 |
| Kernel/ | 80 | 控制器、状态、工具类 |
| Store/ | 14 | EditorState 及子状态 |
| Views/ | 25 | SwiftUI 视图 |
| Workbench/ | 35 | 工作台组件 |
| Utilities/ | 3 | 工具类 |
| Tests/ | 84 | 单元测试（9792 行） |
| **合计** | **~169 文件 + 84 测试** | |

受影响的外部插件（引用了编辑器内核类型）：**~80 个**

---

## Phase 0 — 准备工作

> 目标：建立目录结构，确保项目编译不中断

- [ ] **P0-1** 创建目录结构 `LumiApp/Core/Services/EditorService/`，含子目录：
  ```
  Protocols/
  Registry/
  Kernel/
  Store/
  Views/
  Workbench/
  Editor/
  Utilities/
  ```
- [ ] **P0-2** 将 `LumiApp/Plugins/AgentEditorPlugin/Protocols/` 下的 3 个文件**复制**到 `Core/Services/EditorService/Protocols/`：
  - `EditorExtensionContributors.swift`
  - `EditorLSPClient.swift`
  - `EditorThemeContributor.swift`
- [ ] **P0-3** 确认新文件加入 Xcode 项目（Build Phases → Compile Sources）
- [ ] **P0-4** 验证编译通过（此时新文件与旧文件共存，会有类型冲突，需要在旧文件或新文件中使用 `typealias` 或暂时重命名来验证结构正确）

> ⚠️ Phase 0 完成后：项目应该能编译通过，新旧代码并存

---

## Phase 1 — 迁移协议层与注册中心

> 目标：将编辑器扩展点协议和 `EditorExtensionRegistry` 迁入 Core，消除 Core → Plugin 的依赖倒置
> 这是整个迁移中**最关键的一步**

### 1.1 迁移协议文件

- [ ] **P1-1** 移动 `AgentEditorPlugin/Protocols/EditorExtensionContributors.swift` → `Core/Services/EditorService/Protocols/`
  - 包含 ~15 个 Contributor 协议和 ~20 个 Suggestion/Context 结构体
  - 这是所有编辑器扩展插件最基础的依赖
- [ ] **P1-2** 移动 `AgentEditorPlugin/Protocols/EditorLSPClient.swift` → `Core/Services/EditorService/Protocols/`
  - `EditorLSPClient` 协议，编辑器与 LSP 实现之间的解耦边界
- [ ] **P1-3** 移动 `AgentEditorPlugin/Protocols/EditorThemeContributor.swift` → `Core/Services/EditorService/Protocols/`
  - `EditorThemeContributor` 协议，主题插件的基础依赖

### 1.2 迁移 Kernel 中被协议/Registry 直接依赖的类型

- [ ] **P1-4** 移动 `Kernel/EditorGutterDecoration.swift` → `Core/Services/EditorService/Kernel/`
  - `EditorGutterDecorationContext`、`EditorGutterDecorationSuggestion` 等被 Contributor 协议引用
- [ ] **P1-5** 移动 `Kernel/EditorFindMatch.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-6** 移动 `Kernel/EditorInlinePresentation.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-7** 移动 `Kernel/EditorSurfaceOverlayPalette.swift` → `Core/Services/EditorService/Kernel/`
  - `EditorSurfaceHighlight` 等被 Store 和 View 引用
- [ ] **P1-8** 移动 `Kernel/EditorHoverOverlayStyle.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-9** 移动 `Kernel/EditorCodeActionOverlayStyle.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-10** 移动 `Kernel/EditorCommandCategory.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-11** 移动 `Kernel/EditorCommandSection.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-12** 移动 `Kernel/EditorCommandInvocationContext.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-13** 移动 `Kernel/EditorCommandPresentationModel.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-14** 移动 `Kernel/EditorStatusMessageCatalog.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-15** 移动 `Kernel/LargeFileMode.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-16** 移动 `Kernel/EditorPerformance.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-17** 移动 `Kernel/EditorCursorState.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-18** 移动 `Kernel/EditorSelectionSet.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-19** 移动 `Kernel/EditorSelectionMapper.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-20** 移动 `Kernel/EditorInlineRenameState.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-21** 移动 `Kernel/EditorSnippetSession.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-22** 移动 `Kernel/EditorSnippetParser.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-23** 移动 `Kernel/EditorTransaction.swift` → `Core/Services/EditorService/Kernel/`
- [ ] **P1-24** 移动 `Kernel/EditorMinimapPolicy.swift` → `Core/Services/EditorService/Kernel/`

### 1.3 迁移 EditorExtensionRegistry

- [ ] **P1-25** 移动 `Editor/EditorExtensionRegistry.swift` → `Core/Services/EditorService/Registry/`
  - 这是依赖链的核心节点：`SuperPlugin` 引用它，80+ 个插件注册到它
  - 迁移后 `SuperPlugin+Editor.swift` 中的 `registerEditorExtensions(into registry: EditorExtensionRegistry)` 将正确引用 Core 层类型

### 1.4 迁移 ExtensionResolver

- [ ] **P1-26** 移动 `Editor/ExtensionResolver.swift` → `Core/Services/EditorService/Registry/`
  - 后台扩展点解析器，被 `EditorState` 使用

### 1.5 更新 SuperPlugin 协议引用

- [ ] **P1-27** 更新 `Core/Proto/SuperPlugin+Editor.swift`，确认 `EditorExtensionRegistry` 引用指向 Core 层
- [ ] **P1-28** 更新 `Core/Proto/SuperPlugin.swift` 中相关 import

### 1.6 验证

- [ ] **P1-29** 全量编译通过
- [ ] **P1-30** 运行 `Tests/AgentEditorPluginTests/EditorExtensionRegistryTests.swift`，确认注册中心测试通过
- [ ] **P1-31** 抽查 3-5 个外部编辑器插件（如 `SampleDecorationEditorPlugin`、`ThemeMidnightPlugin`、`LSPServiceEditorPlugin`），确认编译通过

> ✅ Phase 1 完成标志：`SuperPlugin` 不再依赖 AgentEditorPlugin 中的任何类型，编辑器扩展点协议和注册中心属于 Core 层

---

## Phase 2 — 迁移 Store 层

> 目标：迁移 EditorState 及其子状态容器

### 2.1 迁移子状态容器（无或少外部依赖）

- [ ] **P2-1** 移动 `Store/EditorUIState.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-2** 移动 `Store/EditorFileState.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-3** 移动 `Store/EditorPanelState.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-4** 移动 `Store/EditorSettingsState.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-5** 移动 `Store/EditorFileTreeStore.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-6** 移动 `Store/EditorConfigStore.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-7** 移动 `Store/EditorSurfaceHighlightSupport.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-8** 移动 `Store/String+EditorPreviewLines.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-9** 移动 `Store/ReferenceResult.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-10** 移动 `Store/EditorStateSupportTypes.swift` → `Core/Services/EditorService/Store/`

### 2.2 迁移 EditorState 扩展

- [ ] **P2-11** 移动 `Store/EditorState+SaveWorkflow.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-12** 移动 `Store/EditorState+WorkspaceSearch.swift` → `Core/Services/EditorService/Store/`
- [ ] **P2-13** 移动 `Store/EditorState+LanguageActions.swift` → `Core/Services/EditorService/Store/`

### 2.3 迁移 EditorState 主文件

> ⚠️ 这是最大的单文件（3410 行），也是迁移风险最高的文件

- [ ] **P2-14** 移动 `Store/EditorState.swift` → `Core/Services/EditorService/Store/`
  - 注意：EditorState 内部大量引用 Kernel 控制器（~30 个），这些控制器此时可能还在 AgentEditorPlugin 中
  - **策略**：如果 Phase 3（Kernel 迁移）尚未完成，EditorState 的 `import` 需要能找到同 module 内的类型；由于都在同一个 App target 中编译，移动后无需额外 import

### 2.4 验证

- [ ] **P2-15** 全量编译通过
- [ ] **P2-16** 运行 EditorState 相关测试（如存在）

> ✅ Phase 2 完成标志：EditorState 及所有子状态容器位于 Core/Services/EditorService/Store/

---

## Phase 3 — 迁移 Kernel 控制器

> 目标：将 80 个 Kernel 控制器全部迁入 Core

### 3.1 迁移命令系统

- [ ] **P3-1** 移动 `Kernel/CommandRegistry.swift`
- [ ] **P3-2** 移动 `Kernel/CommandRouter.swift`
- [ ] **P3-3** 移动 `Kernel/CoreCommandRegistrations.swift`
- [ ] **P3-4** 移动 `Kernel/EditorCommandController.swift`
- [ ] **P3-5** 移动 `Kernel/EditorInputCommandController.swift`
- [ ] **P3-6** 移动 `Kernel/EditorKeybindingStore.swift`
- [ ] **P3-7** 移动 `Kernel/EditorShortcutCatalog.swift`
- [ ] **P3-8** 移动 `Kernel/EditorSettingsCatalog.swift`
- [ ] **P3-9** 移动 `Kernel/EditorSettingsQuickOpenController.swift`

### 3.2 迁移编辑操作

- [ ] **P3-10** 移动 `Kernel/EditorDocumentController.swift`
- [ ] **P3-11** 移动 `Kernel/EditorDocumentReplaceController.swift`
- [ ] **P3-12** 移动 `Kernel/EditorTransactionController.swift`
- [ ] **P3-13** 移动 `Kernel/EditorBuffer.swift`
- [ ] **P3-14** 移动 `Kernel/EditorUndoController.swift`
- [ ] **P3-15** 移动 `Kernel/EditorUndoManager.swift`
- [ ] **P3-16** 移动 `Kernel/EditorSaveController.swift`
- [ ] **P3-17** 移动 `Kernel/EditorSaveParticipantController.swift`
- [ ] **P3-18** 移动 `Kernel/EditorSavePipelineController.swift`
- [ ] **P3-19** 移动 `Kernel/EditorSaveStateController.swift`
- [ ] **P3-20** 移动 `Kernel/EditorSaveWorkflowController.swift`
- [ ] **P3-21** 移动 `Kernel/EditorFormattingController.swift`
- [ ] **P3-22** 移动 `Kernel/TextEditApplier.swift`
- [ ] **P3-23** 移动 `Kernel/TextEditTransactionBuilder.swift`
- [ ] **P3-24** 移动 `Kernel/LineEditingController.swift`
- [ ] **P3-25** 移动 `Kernel/BracketAndIndent.swift`

### 3.3 迁移查找与替换

- [ ] **P3-26** 移动 `Kernel/EditorFindController.swift`
- [ ] **P3-27** 移动 `Kernel/EditorFindReplaceController.swift`
- [ ] **P3-28** 移动 `Kernel/EditorFindReplaceTransactionBuilder.swift`

### 3.4 迁移光标与选区

- [ ] **P3-29** 移动 `Kernel/CursorMotionController.swift`
- [ ] **P3-30** 移动 `Kernel/EditorCursorController.swift`
- [ ] **P3-31** 移动 `Kernel/EditorMultiCursorController.swift`
- [ ] **P3-32** 移动 `Kernel/EditorMultiCursorWorkflowController.swift`
- [ ] **P3-33** 移动 `Kernel/EditorMultiCursorOverlay.swift`
- [ ] **P3-34** 移动 `Kernel/MultiCursorTransactionBuilder.swift`

### 3.5 迁移 LSP 集成

- [ ] **P3-35** 移动 `Kernel/LSPRequestPipeline.swift`
- [ ] **P3-36** 移动 `Kernel/LSPViewportScheduler.swift`
- [ ] **P3-37** 移动 `Kernel/EditorLSPActionController.swift`
- [ ] **P3-38** 移动 `Kernel/EditorLanguageActionFacade.swift`

### 3.6 迁移重命名与代码操作

- [ ] **P3-39** 移动 `Kernel/EditorRenameController.swift`
- [ ] **P3-40** 移动 `Kernel/EditorWorkspaceEditController.swift`

### 3.7 迁移导航与面板

- [ ] **P3-41** 移动 `Kernel/EditorQuickOpenController.swift`
- [ ] **P3-42** 移动 `Kernel/EditorCallHierarchyController.swift`
- [ ] **P3-43** 移动 `Kernel/EditorWorkspaceSearchController.swift`
- [ ] **P3-44** 移动 `Kernel/EditorPanelController.swift`
- [ ] **P3-45** 移动 `Kernel/DocumentSymbolProvider.swift`
- [ ] **P3-46** 移动 `Kernel/EditorFoldingController.swift`
- [ ] **P3-47** 移动 `Kernel/EditorSessionController.swift`
- [ ] **P3-48** 移动 `Kernel/EditorPeekController.swift`

### 3.8 迁移 Overlay 与外观

- [ ] **P3-49** 移动 `Kernel/EditorOverlayController.swift`
- [ ] **P3-50** 移动 `Kernel/EditorAppearanceController.swift`
- [ ] **P3-51** 移动 `Kernel/EditorRuntimeModeController.swift`
- [ ] **P3-52** 移动 `Kernel/EditorStatusToastController.swift`
- [ ] **P3-53** 移动 `Kernel/EditorTextInputController.swift`

### 3.9 迁移文件与外部操作

- [ ] **P3-54** 移动 `Kernel/EditorExternalFileController.swift`
- [ ] **P3-55** 移动 `Kernel/EditorExternalFileWorkflowController.swift`
- [ ] **P3-56** 移动 `Kernel/EditorFileWatcherController.swift`
- [ ] **P3-57** 移动 `Kernel/EditorFileTreeRefreshCoordinator.swift`
- [ ] **P3-58** 移动 `Kernel/EditorFileTreeWatcher.swift`
- [ ] **P3-59** 移动 `Kernel/EditorConfigController.swift`

### 3.10 验证

- [ ] **P3-60** 全量编译通过
- [ ] **P3-61** 运行 `Tests/AgentEditorPluginTests/` 下所有 Kernel 相关测试（~70 个测试文件）

> ✅ Phase 3 完成标志：所有 80 个 Kernel 控制器位于 `Core/Services/EditorService/Kernel/`

---

## Phase 4 — 迁移 Editor 桥接层

> 目标：迁移 Editor/ 目录下的桥接和协调类

- [ ] **P4-1** 移动 `Editor/EditorCoordinator.swift` → `Core/Services/EditorService/Editor/`
- [ ] **P4-2** 移动 `Editor/EditorInputRouter.swift` → `Core/Services/EditorService/Editor/`
- [ ] **P4-3** 移动 `Editor/EditorPluginManager.swift` → `Core/Services/EditorService/Editor/`
- [ ] **P4-4** 移动 `Editor/SourceEditorAdapter.swift` → `Core/Services/EditorService/Editor/`
- [ ] **P4-5** 移动 `Editor/ScrollCoordinator.swift` → `Core/Services/EditorService/Editor/`
- [ ] **P4-6** 移动 `Editor/TextViewBridge.swift` → `Core/Services/EditorService/Editor/`
  - 注意：引用了 `EditorJumpToDefinitionDelegate`（定义在 LSPContextCommandsEditorPlugin 中），需确认跨插件引用方式
- [ ] **P4-7** 全量编译通过

> ✅ Phase 4 完成标志：`AgentEditorPlugin/Editor/` 目录清空

---

## Phase 5 — 迁移 Workbench

> 目标：将 35 个工作台组件迁入 Core

- [ ] **P5-1** 移动全部 `Workbench/*.swift`（35 个文件） → `Core/Services/EditorService/Workbench/`
  - 包括：EditorSession、EditorGroup、EditorTab、EditorNavigationController、EditorFoldingState 等
- [ ] **P5-2** 全量编译通过
- [ ] **P5-3** 运行 EditorSession 相关测试

> ✅ Phase 5 完成标志：`AgentEditorPlugin/Workbench/` 目录清空

---

## Phase 6 — 迁移 Utilities

> 目标：迁移工具类

- [ ] **P6-1** 移动 `Utilities/EditorThemeAdapter.swift` → `Core/Services/EditorService/Utilities/`
- [ ] **P6-2** 移动 `Utilities/LineOffsetTable.swift` → `Core/Services/EditorService/Utilities/`
- [ ] **P6-3** 移动 `Utilities/EditorFileTreeService.swift` → `Core/Services/EditorService/Utilities/`
- [ ] **P6-4** 全量编译通过

> ✅ Phase 6 完成标志：`AgentEditorPlugin/Utilities/` 目录清空

---

## Phase 7 — 迁移 Views

> 目标：将 25 个编辑器视图迁入 Core
> 注意：Views 可以考虑放到 `Core/Views/Editor/` 而非 Services 下，但为了保持迁移简单，先统一放到 `Core/Services/EditorService/Views/`

- [ ] **P7-1** 移动全部 `Views/*.swift`（25 个文件） → `Core/Services/EditorService/Views/`
  - 包括：EditorPanelView、EditorRootView、EditorRootOverlay、SourceEditorView、EditorCommandPaletteView 等
  - **注意**：`EditorLoadedPluginsView.swift`（已加载插件列表）是否迁入 Core 需要讨论，它展示的是编辑器子插件信息，可能在瘦身后变成一个通用设置视图
- [ ] **P7-2** 全量编译通过
- [ ] **P7-3** 手动验证编辑器 UI 正常渲染

> ✅ Phase 7 完成标志：`AgentEditorPlugin/Views/` 目录清空

---

## Phase 8 — 瘦身 AgentEditorPlugin

> 目标：AgentEditorPlugin 只保留 `EditorPlugin.swift` 入口文件

- [ ] **P8-1** 确认 `AgentEditorPlugin/` 目录下只剩 `EditorPlugin.swift` 和 `LumiEditor.xcstrings`
- [ ] **P8-2** 精简 `EditorPlugin.swift`：
  - 保留 `addRootView()` → 返回 `EditorRootOverlay`
  - 保留 `addPanelView()` → 返回 `EditorPanelView`
  - 保留 `addStatusBarTrailingView()` → 返回已加载插件入口
  - 保留 `panelNeedsSidebar = true`
  - 其他所有逻辑已由 Core/Services/EditorService 承担
- [ ] **P8-3** 确认 `EditorPlugin` 的 `providesEditorExtensions` 行为（它自身不是编辑器扩展插件，只是编辑器外壳）
- [ ] **P8-4** 全量编译通过
- [ ] **P8-5** 手动测试编辑器完整功能：文件打开、编辑、保存、LSP 补全、hover、跳转、命令面板、多光标

> ✅ Phase 8 完成标志：AgentEditorPlugin 是一个轻量级插件壳，~50 行代码

---

## Phase 9 — 迁移测试

> 目标：将编辑器测试从 `Tests/AgentEditorPluginTests/` 迁移到 `Tests/CoreTests/Editor/`

- [ ] **P9-1** 创建 `Tests/CoreTests/Editor/` 目录
- [ ] **P9-2** 移动全部 84 个测试文件从 `Tests/AgentEditorPluginTests/` → `Tests/CoreTests/Editor/`
- [ ] **P9-3** 更新测试中的 `@testable import` 引用（如有）
- [ ] **P9-4** 运行全部测试，确认通过率不低于迁移前
- [ ] **P9-5** 删除空的 `Tests/AgentEditorPluginTests/` 目录

> ✅ Phase 9 完成标志：编辑器测试归属于 CoreTests

---

## Phase 10 — 清理与收尾

> 目标：清理残留，更新文档

- [ ] **P10-1** 删除 `LumiApp/Plugins/AgentEditorPlugin/` 下已迁移的空子目录（Kernel/、Store/、Views/、Workbench/、Editor/、Protocols/、Utilities/）
- [ ] **P10-2** 确认 `AgentEditorPlugin/` 最终只包含：
  ```
  EditorPlugin.swift
  LumiEditor.xcstrings
  ```
- [ ] **P10-3** 更新 `README.md` 中的架构图
- [ ] **P10-4** 更新 `.agent/rules/` 中的相关规则文档（如有）
- [ ] **P10-5** 全量编译 + 全量测试通过
- [ ] **P10-6** 提交 PR，标题：`refactor: migrate editor kernel from AgentEditorPlugin to Core/Services/EditorService`

> ✅ Phase 10 完成标志：迁移完成，编辑器内核是 App Core 的一部分

---

## 风险与注意事项

### 编译风险
- 同一 App target 内移动文件，**不需要改 import**（Swift 在同一个 module 内可直接引用）
- 但需要确保 Xcode 项目文件（`project.pbxproj`）中的文件引用路径正确更新
- 建议使用 Xcode 的 Refactor → Move 功能，或在移动后手动调整 Build Phases

### 跨插件引用
- `EditorJumpToDefinitionDelegate`（定义在 LSPContextCommandsEditorPlugin 中）被 `TextViewBridge` 引用
- `CodeActionItem`、`InlayHintItem`、`FoldingRangeItem` 等 Provider 模型类型定义在各自的 LSP 插件中
- 这些类型通过 `SuperEditorProviderCapabilities.swift`（Core/Proto）中的协议抽象访问，迁移不影响

### 测试策略
- 每个 Phase 完成后都要求全量编译通过
- Phase 3 完成后运行全量 Kernel 测试
- Phase 8 完成后进行手动功能验证

### 回滚策略
- 每个 Phase 独立提交，出问题可以逐 Phase 回滚
- 建议在单独的分支上操作：`refactor/editor-kernel-migration`

---

## 预期收益

| 维度 | 改善 |
|------|------|
| 依赖方向 | Core ← Plugins（正确），不再有 Core → Plugin 的倒置 |
| AgentEditorPlugin | 从 ~169 文件瘦身为 ~1 文件 |
| 可测试性 | 编辑器内核测试归入 CoreTests，与 AgentEditorPlugin 解耦 |
| 可扩展性 | 编辑器扩展点协议和 Registry 属于 Core，新插件开发更直观 |
| 架构一致性 | 与 ContextService、TaskService 等平级，编辑器内核是 App 核心能力 |
