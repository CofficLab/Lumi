# AgentEditorPlugin VS Code 体验复刻路线图

## 目标

不是只做一个“内核更强的原生编辑器”，而是以 Swift 为基础，把 `AgentEditorPlugin` 逐步推进成一个在用户体验上尽可能接近 VS Code 的完整编辑器工作台。

## 对齐 VS Code 的设计原则

### 1. Model First

核心状态不能继续主要围绕"当前展示的文件"和"当前 TextView"组织。

要逐步切换成以下模型：

1. `EditorDocument` — 文档身份（URL、语言、编码、元信息）
2. `EditorBuffer` — 文本内容与版本号，编辑真相来源
3. `WorkingCopy` — dirty 状态、保存状态、外部修改冲突、恢复状态
4. `EditorSession` — 已打开编辑器实例的状态（光标、选区、滚动、折叠、查找）
5. `EditorGroup` — 分栏中的 tab 集合和当前活跃 session
6. `EditorWorkbenchState` — 整个编辑工作台的布局、活跃 group、导航历史、预览 tab

### 2. Transaction First

所有编辑行为都应该走统一事务管线，而不是分散在：

1. TextView 输入回调
2. coordinator 同步逻辑
3. 多光标 helper
4. LSP 编辑应用逻辑

理想链路：

```
EditorTransaction → apply to buffer → update selections → push undo stack → notify language pipelines → refresh visible UI
```

覆盖范围：普通输入、粘贴、删除、多光标批量编辑、format document、rename symbol、code action 修改、replace all。

### 3. Session and Workbench First

VS Code 的核心体验不只是"编辑一个文件"，而是：多 tab、预览 tab / 固定 tab、split editor、editor groups、navigation history、reopen closed editor、dirty tabs。

当前以单个选中文件驱动的方式，需要逐步让位给 session/workbench 驱动。

### 4. Async Language Pipelines

每个异步语言功能都要有：

1. 文档版本感知
2. 请求代际
3. stale response 丢弃
4. cancellation
5. viewport/cursor 敏感刷新

覆盖范围：completion、hover、diagnostics、code actions、semantic tokens、inlay hints、references、rename。

### 5. UX Is Part of the Product, Not Just Decoration

如果目标是接近 VS Code，体验层不能被视为“内核完成后的装饰”，而必须被当成一等能力处理。

重点包括：

1. command palette / quick open 的 discoverability
2. breadcrumb / outline / minimap / gutter / panel 的连续工作流
3. hover / code action / diagnostics / references 的统一交互
4. 设置、快捷键、上下文菜单、状态栏入口的一致性
5. 插件贡献的 UI 能力是否可被稳定挂接

### 6. Performance Is Part of the Kernel

性能不是后期补丁，而是内核设计的一部分：

1. 大文件模式
2. 长行保护
3. 增量高亮
4. viewport 限界更新
5. overlay 更新限流
6. 主线程最小化压力

## 目标架构

这份架构不再只描述“文本内核”，而是描述“完整编辑器体验栈”。

### Layer 1: Text Core

新增核心文本层：

| 模块 | 职责 |
|------|------|
| `EditorBuffer` | 存储 canonical text，应用编辑事务，管理版本号 |
| `EditorSnapshot` | 输出不可变快照 |
| `EditorRange` | 编辑范围表达 |
| `EditorSelection` | 选区模型 |
| `EditorTransaction` | 统一编辑事务 |
| `EditorUndoManager` | 驱动 undo/redo |

> `NSTextStorage` 和 `CodeEditSourceEditor` 应逐步退化为"适配器层"，而不再是最终真相来源。

### Layer 2: Session Core

新增会话层：

| 模块 | 职责 |
|------|------|
| `EditorSession` | 每个打开文件的独立编辑状态 |
| `EditorTab` | tab 展示单元 |
| `EditorFindReplaceState` | 查找状态 |
| `EditorDecorationState` | 高亮/装饰状态 |
| `EditorNavigationHistory` | 导航历史 |

职责：保存每个打开文件的独立编辑状态；在切 tab 后恢复上下文；承载查找、高亮、折叠、scroll、selection 等局部状态。

### Layer 3: Workbench Core

新增工作台层：

| 模块 | 职责 |
|------|------|
| `EditorGroup` | 管理 tab groups、split editor |
| `EditorWorkbenchState` | 管理布局、active editor/group |
| `EditorCommandContext` | 管理命令启用状态 |

### Layer 4: Language Core

新增语言特性协调层：

| 模块 | 职责 |
|------|------|
| `CompletionPipeline` | 与 buffer snapshot 对齐 |
| `HoverPipeline` | 管理 cancellation |
| `DiagnosticsPipeline` | 拒绝过期结果 |
| `CodeActionPipeline` | 做局部刷新 |
| `SemanticTokensPipeline` | — |
| `InlayHintPipeline` | — |

### Layer 5: Native Rendering Bridge

保留并重构原生桥接层：

| 模块 | 职责 |
|------|------|
| `SourceEditorAdapter` | 把核心模型映射到 `CodeEditSourceEditor` |
| `TextViewBridge` | 把原生事件转换为编辑事务 |
| `OverlayLayoutSystem` | 统一 overlay 定位与刷新 |
| `EditorInputRouter` | 输入路由 |

## 总体拆分策略

不要一次性重写，而是按"抽内核、保 UI、逐步迁移"的方式推进。

第一波重构只做三件事：

1. 把文本真相从视图侧拉出来
2. 把编辑行为统一到事务管线
3. 把单文件状态升级为 session 状态

这三件事做完，后面的 tab、split、command、find/replace 才会真正好做。

## Phase 0: 立规则与测基线

在大改之前先把规则定清楚。

### 执行原则

1. 不再继续把 `EditorState.swift` 当作长期唯一中心
2. 所有新增编辑能力优先走 transaction 模型
3. 视图层只负责展示和桥接，不负责持有核心编辑真相

### 任务

1. 明确"谁是文本真相来源"
2. 定义今后的编辑行为必须向 transaction 模型收敛
3. 列出现存内核问题清单
4. 增加性能基线指标

### 建议关注的性能指标

1. 打开文件耗时
2. 打字延迟
3. completion 延迟
4. hover 延迟
5. rename 延迟
6. 大文件打开表现

### 验收

1. 后续改造有统一约束
2. 可以量化回归

### ✅ Phase 0 完成清单

- [x] 明确"谁是文本真相来源" — `EditorBuffer` 已成为 canonical text holder，`EditorDocumentController` 持有 buffer 并管理 NSTextStorage 桥接
- [x] 定义编辑行为向 transaction 模型收敛 — `EditorTransaction` 已统一表达 replace/insert/delete/apply text edits/replace selections
- [x] 列出现存内核问题清单 — 路线图文档"当前代码里的核心问题"章节已完成
- [x] `Kernel/` 目录已建立，核心文本模型已落地
- [x] 性能基线指标 — `EditorPerformance` 骨架已建立（24 种事件类型、慢速阈值、统计摘要、报告生成）；当前仅部分事件已完成实际埋点接线

---

## Phase 1: Buffer / Transaction Core

### 目标

在不立刻推翻 UI 的前提下，建立新的核心文本模型。

### 任务

1. 建立 `EditorBuffer / EditorSnapshot / EditorTransaction` 这组文本核心对象
2. 把编辑真相从 `NSTextStorage` 拉回内核 buffer
3. 把 format、rename、code action、多光标 replacement 等编辑行为统一到 transaction 入口
4. 让 `EditorState` 开始通过统一入口驱动文本改动，而不是继续散落落地

### 验收

1. format 不再直接操纵 text storage 为主
2. rename 不再直接按旧路径分散落地
3. 至少三类编辑行为走同一个 transaction 入口
4. `EditorBuffer` 成为明确存在的文本核心对象

### ✅ Phase 1 完成清单

- [x] `Kernel/` 目录已建立
- [x] `EditorBuffer` — 持有 canonical text + version，提供 `snapshot()`、`apply(_:)`、`replaceText(_:)`
- [x] `EditorSnapshot` — 不可变快照（内嵌于 EditorBuffer.swift）
- [x] `EditorRange` — 编辑范围表达（内嵌于 EditorTransaction.swift）
- [x] `EditorSelection` — 选区模型（内嵌于 EditorTransaction.swift）
- [x] `EditorTransaction` — 统一编辑事务，支持多 replacement + updatedSelections
- [x] `EditorEditResult` — 编辑结果（内嵌于 EditorBuffer.swift）
- [x] `EditorDocumentController` — 封装 buffer + NSTextStorage 双写管理，提供 `load()`、`apply(transaction:)`、`applyTextEdits(_:)`、`syncBufferFromTextStorageIfNeeded()`
- [x] `TextEditTransactionBuilder` — LSP TextEdits → EditorTransaction 转换器
- [x] `TextEditApplier` — TextEdit 应用器
- [x] `MultiCursorTransactionBuilder` — 多光标编辑 → Transaction 构建器
- [x] `applyEditorTransaction(_:reason:)` 统一入口已在 EditorState 中实现
- [x] `formatDocumentWithLSP()` 已改走 transaction（通过 `applyTextEditsToCurrentDocument`）
- [x] `renameSymbolWithLSP()` 已改走 transaction（通过 `applyTextEditsToCurrentDocument`）
- [x] code action text edits 已改走 transaction
- [x] 多光标 replacement 已改走 transaction（`multi_cursor_replace`）
- [x] 多光标操作已改走 transaction（`multi_cursor_operation`）
- [x] `EditorBufferTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] `EditorUndoManager` — 已落地为独立快照式 undo/redo 管理器，并接入 transaction 路径、原生文本输入路径与 `builtin.undo / builtin.redo` 命令链
- [x] NSTextStorage 与 buffer 双写风险已收敛到应急兜底级别（transaction / save / undo / completion / 普通文本输入已走精确同步；`didReplaceContentsIn` 后的重复 `textDidChange` 重对齐已被抑制；带有 `textView.string` 的 `textDidChange` 旁路也会直接以当前视图文本重建 buffer；保留的 `syncBufferFromTextStorageIfNeeded()` 仅作为无法获取更精确信息时的应急补偿钩子）
- [x] selection 映射在 format/rename 后的光标稳定性已编写专项测试用例（`EditorSelectionStabilityTests` 覆盖 `changes` 与 `documentChanges` 两条 `WorkspaceEdit` 路径；待 test target / test plan 接入后运行验证）

---

## Phase 2: Selection / Cursor Core

### 目标

把最影响编码手感的部分先稳定下来。

### 任务

1. 建立 `EditorSelectionSet / EditorSelectionMapper / EditorCursorState`
2. 区分 canonical selection 与原生 TextView selection
3. 让普通输入与多光标输入共享统一编辑入口
4. 稳定 completion、format、rename 后的选区恢复

### 验收

1. 多光标下不再出现结构性丢光标问题
2. 普通输入和多光标输入共享统一编辑入口
3. format/rename/completion 后选区恢复更稳定
4. coordinator 不再到处手工纠偏选区

### ✅ Phase 2 完成清单

- [x] `EditorSelectionSet` — 内核选区 canonical state，支持 primary/secondary 选区、多光标模式判断、增删选区操作
- [x] `EditorSelectionMapper` — TextView ↔ 内核选区双向桥接（`toCanonical`、`applyToView`、`shouldAcceptCanonicalUpdate`）
- [x] `canonicalSelectionSet` 已在 EditorState 中作为内核选区状态持有
- [x] `applyCanonicalSelectionSet(_:)` 方法已实现，coordinator 通过此方法更新内核选区
- [x] 多光标 replacement 已重构为 transaction-aware（Phase 1 已完成）
- [x] 多光标 delete 已重构为 transaction-aware（Phase 1 已完成）
- [x] `EditorSelectionSetTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] `EditorSelectionMapperTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] `MultiCursorTransactionBuilderTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] `EditorCursorState` — 已作为兼容模块名落成，对当前 canonical `EditorSelectionSet` 提供明确别名，避免再引入第二套重复状态模型
- [x] swizzle 依赖已退化为薄适配层 — `Cmd+D / Cmd+U / Cmd+Shift+L / Esc` 已改走统一 command id；`insertText` / `deleteBackward` / `insertNewline` / `insertTab` / `insertBacktab` 的输入决策也已下沉到 `EditorState`，`MultiCursorInput` 现主要只剩原生事件拦截与选区回写适配层
- [x] completion / format / rename 后的选区恢复已编写专项自动测试用例（`EditorSelectionStabilityTests`；待 test target / test plan 接入后运行验证），且单光标 completion 已通过 `EditorState.applyCompletionEdit` 接入事务链

---

## Phase 3: Session / Tabs Core

### 目标

把当前"单文件编辑器"升级为"有 editor session 概念的编辑器"。

### 任务

1. 建立 `EditorSession / EditorTab / EditorSessionStore / EditorNavigationHistory`
2. 让“打开文件”升级为“打开或激活 session”
3. 引入 tab strip 和 session-local 状态恢复
4. 让 cursor、scroll、find、panel 等状态按 session 独立保存

### 验收

1. 同时打开多个文件时，每个文件的编辑上下文独立存在
2. 切换 tab 不会丢光标和查找状态
3. 编辑器入口不再等价于单文件视图

### ✅ Phase 3 完成清单

- [x] `EditorSession` — 每个打开文件的独立编辑状态（fileURL、multiCursorState、panelState、isDirty、findReplaceState、scrollState、viewState）
- [x] `EditorTab` — tab 展示单元（sessionID、fileURL、title、isDirty、isPinned）
- [x] `EditorSessionStore` — session/tab 管理（openOrActivate、activate、close、closeOthers、goBack、goForward）
- [x] `EditorFindReplaceState` — 查找状态（findText、replaceText、options、resultCount、selectedMatchIndex）
- [x] `EditorNavigationHistory` — 导航历史（recordVisit、goBack、goForward、remove）
- [x] `EditorRootView` 已引入 `@StateObject sessionStore`，文件选中走 `openOrActivate` session
- [x] `EditorTabStripView` 已实现 — 支持导航前进/后退、tab 选择/关闭、pin/unpin、close others、open editors 下拉菜单
- [x] `EditorSession` 保存 cursor/scroll/find/panel 状态，切换 tab 后恢复
- [x] `EditorSessionTests`（1144 行）、`EditorSessionStoreTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] 面板状态已以 `panelState / session.panelState` 为主真相；`EditorState` 上的 hover / references / problems 等 published 字段已退为兼容镜像，内部高频读取优先走 `panelState`
- [x] 外部文件刷新 / 冲突处理后的 session 感知已编写专项测试用例（`EditorExternalFileConflictTests` 覆盖 reload / keep editor version 后的 dirty 与 session 同步；待 test target / test plan 接入后运行验证）

---

## Phase 4: Workbench Groups

### 目标

开始具备 VS Code 式工作台能力。

### 任务

1. 建立 `EditorGroup / EditorWorkbenchState / EditorGroupHostStore`
2. 支持 split、unsplit、跨 group 移动 session
3. 让 workbench 命令感知 active group 和 active session
4. 为多 EditorState 实例化提供稳定容器

### 验收

1. 支持多编辑分栏而不是单编辑区
2. command 能感知当前 workbench 上下文

### ✅ Phase 4 完成清单

- [x] `EditorGroup` — 分栏组模型，管理 sessions/tabs/activeSessionID，支持 `split(_:)`、`unsplit()`、`moveSessionToOtherGroup`
- [x] `EditorWorkbenchState` — 工作台顶层状态管理器，管理 rootGroup 树 + activeGroupID
- [x] `EditorGroupHostStore` — Group host 状态管理
- [x] Split editor — `EditorGroup.split(.horizontal/.vertical)` 创建子 group，支持水平/垂直分割
- [x] Unsplit — `EditorWorkbenchState.unsplitActiveGroup()` 已支持从 active leaf 回溯到最近 split ancestor 执行合并，并补充 `testUnsplitActiveLeafCollapsesNearestSplitAncestor` 回归用例
- [x] Session 移动 — `moveSessionToOtherGroup(sessionID:targetGroupID:)`
- [x] Active group tracking — `EditorWorkbenchState.activeGroupID` + `focusNextGroup()` / `focusPreviousGroup()`
- [x] 全局 session 查找 — `groupContainingSession(sessionID:)`
- [x] 叶子 group 枚举 — `leafGroups()` 递归获取
- [x] `EditorRootView` 已接入 workbench — `@StateObject workbench`，`splitEditor()`、`unsplitEditor()` 方法，split 后 HSplitView/VSplitView 布局
- [x] Split 后在新分栏中复制当前活跃 session（VS Code 风格）
- [x] Workbench 命令已注册 — split-right、split-down、close-split、focus-next/previous-group、move-to-next/previous-group
- [x] 多 EditorState 实例 — split 后每个 leaf group 持有独立的 `EditorState`，可独立加载文件、编辑、保存
- [x] split 后的非活跃 group 完整编辑 — `EditorGroupHostView` 移除 `.allowsHitTesting(false)`，统一使用 hosted state 架构

---

## Phase 5: Command / Keybinding

### 目标

编辑器行为从 UI 触发转向 command 驱动。

### 任务

1. 建立 `CommandRegistry / CommandRouter / CoreCommandRegistrations`
2. 统一 toolbar、menu、context menu、shortcut、command palette 的行为入口
3. 建立命令搜索、分类、排序和 enablement context
4. 打通用户可配置快捷键的完整链路

### 验收

1. 行为入口统一，toolbar / menu / context menu / shortcut / command palette 全部走同一 command id
2. 键位系统开始可维护
3. UI 不再各自持有业务逻辑

### ✅ Phase 5 完成清单

- [x] `CommandRegistry` — 中央命令注册中心，支持 register/execute/availableCommands(context-based enablement)
- [x] `CommandRouter` — 新旧命令体系双向桥接（`registerSuggestions`、`suggestionsFromRegistry`、`execute`）
- [x] `CoreCommandRegistrations` — 所有计划命令已注册（共 35 个命令，覆盖全部 9 个分类）
- [x] `EditorCommandPresentationModel` — 命令搜索/分类/排序模型
- [x] `EditorCommandCategory` — 命令分类枚举（format/navigation/workbench/multiCursor/find/lsp/save/edit/other）
- [x] `EditorCommandSection` — 命令分区模型
- [x] `EditorCommandPaletteView` — 命令面板 UI，支持搜索、分类过滤、快捷键显示
- [x] `CommandContext` — 上下文感知的命令启用状态（hasSelection、languageId、isEditorActive、isMultiCursor）
- [x] `EditorCommandBindings` — 快捷键绑定映射
- [x] `EditorCommandPaletteTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] 键位可配置化 — 设置页、录制器、冲突检查、恢复默认与全链路生效已接通
- [x] toolbar / context menu 的高频编辑动作已统一走 command id；配置型 UI（字体/缩进/保存选项）明确不纳入本阶段命令化验收范围
- [x] 快捷键设置 UI — 用户查看/搜索/修改命令快捷键的设置界面
- [x] 快捷键录制器 — 捕获用户按键输入并转成快捷键绑定的 UI 组件
- [x] 快捷键冲突检测与提示 — 同一键位绑定多个命令时提供冲突提示与处理策略
- [x] 快捷键恢复默认 — 支持单条或全局恢复默认绑定
- [x] 用户自定义快捷键持久化后的统一反映 — 菜单 / command palette / toolbar / context menu 全部实时反映用户绑定

---

## Phase 6: Language Pipelines

### 目标

让语言智能在真实编码压力下依然稳定。

### 任务

1. 建立统一的 request generation、cancellation、lifecycle 管线
2. 把 hover、completion、references、rename、semantic tokens、inlay hints 等语言能力接到统一请求模型
3. 增强 stale response protection 与 viewport / cursor 敏感刷新

### 验收

1. 快速输入时不会被旧结果污染
2. 语言能力更加平滑
3. plugin/contributor 增多后仍可扩展

### ✅ Phase 6 完成清单

- [x] `RequestGeneration` — 请求代际跟踪器（`next()`、`isCurrent(_:)`、`invalidate()`、`reset()`）
- [x] `CancellationContext` — 异步请求取消令牌（`cancel()`、`isCancelled`）
- [x] `LSPRequestLifecycle` — 统一请求生命周期包装器（`run(operation:apply:)`、`invalidate()`、`reset()`）
- [x] InlayHintProvider — 已使用 `LSPRequestLifecycle`
- [x] DocumentHighlightProvider — 已使用 `LSPRequestLifecycle`
- [x] CodeActionProvider — 已使用 `LSPRequestLifecycle`
- [x] SignatureHelpProvider — 已使用 `LSPRequestLifecycle`
- [x] WorkspaceSymbolProvider — 已使用 `LSPRequestLifecycle`
- [x] SelectionRangeProvider — 已使用 `LSPRequestLifecycle`
- [x] DocumentLinkProvider — 已使用 `LSPRequestLifecycle`
- [x] DocumentColorProvider — 已使用 `LSPRequestLifecycle`
- [x] CallHierarchyProvider — 已使用 `LSPRequestLifecycle`（prepare + incoming + outgoing 三条独立管线）
- [x] FoldingRangeProvider — 已使用 `LSPRequestLifecycle`
- [x] HoverCoordinator — 已使用 `RequestGeneration`（`hoverRequestGeneration`）
- [x] LSPCompletionDelegate — 已使用 `RequestGeneration`
- [x] JumpToDefinitionDelegate — 已使用 `RequestGeneration`
- [x] EditorState.showReferencesFromCurrentCursor() — 已使用 `referencesRequestGeneration`
- [x] LSPCoordinator — 已使用 `RequestGeneration`（`fileSessionGeneration` + `requestGeneration`）
- [x] `RequestGenerationTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] `LSPDebouncerTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] SemanticTokenHighlightProvider — 实现在 `LSPCoordinator.swift` 内部，已接入 `RequestGeneration` stale rejection，并纳入 `Phase 8` 的 viewport / 长行 runtime gating
- [x] 文档版本感知 — `EditorSnapshot.version` 现已显式贯穿 `EditorState -> LSPCoordinator -> LSPService -> LanguageServer`，LSP 文档版本不再独立自增
- [x] viewport/cursor 敏感刷新 — `LSPCoordinator` 现已统一使用 document/cursor/range request context 做 stale rejection，cursor/range 敏感请求不再各自手写 `sessionGen + uri` 校验

---

## Phase 7: Find / Replace

### 目标

补上最重要的日常编码能力之一。

### 任务

1. 建立 `EditorFindReplaceState` + Options + Controller
2. 支持：regex、case-sensitive、whole-word、in-selection、replace one、replace all、preserve case
3. Transaction-based replace current / replace all
4. 与 selection / multi-cursor 联动
5. per-session 保存查找状态

### 验收

1. 查找替换成为内核能力，不只是 UI 功能
2. 切 tab 和 split 后依旧一致

### ✅ Phase 7 完成清单

- [x] `EditorFindReplaceState` — 查找状态模型（findText、replaceText、options、resultCount、selectedMatchIndex、selectedMatchRange）
- [x] `EditorFindReplaceOptions` — 查找选项（regex、caseSensitive、wholeWord、inSelection）
- [x] `EditorFindReplaceController` — 查找匹配引擎（正则匹配、next/previous 导航、selectedMatchIndex 计算逻辑）
- [x] `EditorFindMatch` — 匹配结果模型
- [x] `EditorFindReplaceTransactionBuilder` — 查找替换 transaction 构建器
- [x] Transaction-based replace current — 通过 `applyEditorTransaction(_:reason: "find_replace_current")` 落地
- [x] Transaction-based replace all — 通过 `applyEditorTransaction(_:reason: "find_replace_all")` 落地
- [x] per-session 保存查找状态 — `EditorSession.findReplaceState` 为每个 session 独立持有
- [x] Find/Replace 命令已注册 — find、find-next、find-previous、replace-current、replace-all
- [x] `EditorFindReplaceControllerTests`、`EditorFindReplaceTransactionBuilderTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] preserve case 替换选项 — `EditorFindReplaceTransactionBuilder` 已实现，并已编写 `EditorFindReplaceTransactionBuilderTests` 用例（待 test target / test plan 接入后运行验证）
- [x] 与 multi-cursor selection 联动的 in-selection 查找已补专项验证用例（`EditorFindReplaceControllerTests` 覆盖多选区与 primary selection fallback；待 test target / test plan 接入后运行验证）

---

## Phase 8: Performance / Large File

### 目标

缩小与 VS Code 的压力表现差距。

### 任务

1. 建立 `LargeFileMode / LongLineDetector / ViewportRenderController`
2. 让 runtime gating 覆盖高成本高亮、overlay 与语言特性
3. 把渲染和请求调度尽量绑定到 viewport，而不是全量文档
4. 为大文件和超长行提供稳定降级策略

### 验收

1. 大文件场景可用
2. 渲染成本更多跟 viewport 绑定，而不是全量文档

### ✅ Phase 8 完成清单

- [x] `LargeFileMode` — 文件大小分级（normal / medium / large / mega），带阈值常量
- [x] `LongLineDetector` — 长行检测器，检测超长行（>10,000 字符）
- [x] `ViewportRenderController` — Viewport 渲染控制器（visibleStartLine/EndLine、bufferSize、shouldDebounceUpdate）
- [x] 运行时模式接线 — `EditorState.loadFile` 中根据文件大小维护 `largeFileMode`
- [x] 功能自动降级 — `LargeFileMode` 提供 `isSemanticTokensDisabled`、`isInlayHintsDisabled`、`isFoldingDisabled`、`isMinimapDisabled`、`isReadOnly` 等属性
- [x] 语法高亮上限 — `maxSyntaxHighlightLines` 按 mode 分级（normal→∞、medium→50K、large→10K、mega→1K）
- [x] 长行保护 — `isLongLineProtectionEnabled` 在 large/mega 模式启用
- [x] `ViewportRenderController` 已在 `EditorState` 中实例化
- [x] `LargeFileModeTests` 已编写对应测试文件（336 行，含 `ViewportRenderControllerTests`；待 test target / test plan 接入后运行验证）
- [x] `LSPViewportScheduler` — 滚动节流管线（inlay hints/diagnostics/code actions 独立 debounce，500ms/300ms/400ms）
- [x] Inlay viewport 调度 — `applyViewportObservation` 通过 `LSPViewportScheduler` 触发可见区域请求
- [x] Document highlight runtime gating — viewport / 长行保护会抑制请求并清理旧高亮
- [x] Hover runtime gating — viewport / 长行保护会抑制 hover 请求并清理旧浮层
- [x] Signature help runtime gating — viewport / 长行保护会抑制请求并清理旧签名面板
- [x] Code action runtime gating — viewport / 长行保护会抑制请求并清理旧灯泡动作
- [x] 截断安全 — 大文件默认 `256KB` 截断预览，支持显式 `Load Full File` 按需全量加载
- [x] Viewport 转场清理已统一收口到 `EditorState.handleViewportRuntimeTransition()`，不再由 `SourceEditorView` 分散清理 `document highlight / signature help / code action`
- [x] Render range 过滤 helper 已统一收口到 `EditorState`（`isRenderedLine / isRenderedOffset / intersectsRenderedRange / renderedFindMatches / renderedInlayHints`），`SourceEditorView` 不再自行维护这些过滤规则
- [x] Overlay 展示条件已继续收口到 `EditorState`（`renderedBracketMatch / shouldPresentSignatureHelpOverlay / shouldPresentCodeActionOverlay`），`SourceEditorView` 进一步退化为纯渲染消费层
- [x] `hover` 与 `inlay hints strip` 的展示条件也已收口到 `EditorState`（`shouldPresentHoverOverlay / currentRenderedInlayHints / shouldPresentInlayHintsStrip`），`SourceEditorView` 基本不再维护独立的 runtime 展示规则
- [x] `find matches` 与 `hover` 的最终渲染输入也已改为直接消费 `EditorState` 结果（`currentRenderedFindMatches / currentHoverOverlayText`），进一步减少 `SourceEditorView` 的状态拼装
- [x] `find match` 的可见高亮矩形计算也已收口到 `EditorState`（`renderedFindMatchHighlights`），`SourceEditorView` 不再自行处理 `visibleRect + layoutManager` 的几何裁剪
- [x] `bracket match` 的最终 overlay rect 计算与 `hover` 的 popover offset 计算也已收口到 `EditorState`（`renderedBracketOverlayRects / hoverOverlayOffset`），进一步减少 `SourceEditorView` 内部几何逻辑
- [x] `document highlight / signature help / code action` 的 runtime availability 转场清理也已收口到 `EditorState`（`handleDocumentHighlightRuntimeAvailabilityChange / handleSignatureHelpRuntimeAvailabilityChange / handleCodeActionRuntimeAvailabilityChange`）
- [x] `tree-sitter / semantic token / document highlight` 的 provider 启用规则也已统一由 `EditorState` 提供（`shouldUseTreeSitterHighlightProvider / shouldUseSemanticTokenHighlightProvider / shouldUseDocumentHighlightProvider`），`SourceEditorView` 不再直接拼装这些 runtime 条件
- [x] `signature help / code action` 的最终 overlay 数据与动作执行入口也已收口到 `EditorState`（`currentSignatureHelpOverlayItem / currentCodeActionOverlayActions / performCodeActionOverlayAction`），`SourceEditorView` 进一步退化为纯消费层
- [x] `hover` 的当前 rect 与 viewport/runtime 转场取消条件也已统一由 `EditorState` 提供（`currentHoverOverlayRect / shouldCancelHoverForViewportTransition / shouldCancelHoverForRuntimeAvailabilityChange`），`SourceEditorView` 不再直接读取 `panelState` 做这些判断
- [x] `find match overlay` 已受 `viewportRenderLineRange` 约束
- [x] `bracket match overlay` 已受 `viewportRenderLineRange` 约束
- [x] `signature help overlay` 已受 `viewportRenderLineRange` 约束
- [x] `code action overlay` 已受 `viewportRenderLineRange` 约束
- [x] `inlay hints strip` 已受 `viewportRenderLineRange` 约束
- [x] 语义高亮 / inlay hints / document highlight / hover / code action 等高成本 runtime consumer 已接入 Phase 8 gating
- [x] 明确 `CodeEditSourceEditor` 内部文本渲染不可直接裁剪为外部依赖边界，并从核心计划验收项中剥离
- [x] 决定 `CodeEditSourceEditor` 边界后的后续策略：接受现状继续在 Lumi 自有层优化，或评估 fork 以接入真实 viewport render control

---

## Phase 9: Polish

### 目标

把"可用"提升到"熟悉、顺手、像 VS Code"。

### 任务

1. 建立保存前参与者与保存管线
2. 补齐 format on save、organize imports、fix all、保存冲突处理
3. 建立括号、缩进、行编辑这组高频编辑体验引擎
4. 打磨 auto-closing、auto-surround、smart enter、line edit、bracket match 这组日常体验

### 验收

1. 高频编辑动作连贯
2. 用户逐渐感受不到"这是一套自定义编辑器行为"

### ✅ Phase 9 完成清单

- [x] `EditorSaveParticipantController` — 保存前自动执行 trim trailing whitespace + insert final newline
- [x] `EditorSavePipelineController` — 保存管线控制器（textParticipants → formatOnSave → deferredActions）
- [x] format on save — 可配置，通过 `EditorSavePipelineOptions.formatOnSave` 控制
- [x] organize imports on save — 可配置，通过 `EditorSavePipelineOptions.organizeImportsOnSave` 控制
- [x] fix all on save — 可配置，通过 `EditorSavePipelineOptions.fixAllOnSave` 控制
- [x] 保存行为持久化配置 — `EditorConfigStore` 持久化 formatOnSave/organizeImportsOnSave/fixAllOnSave
- [x] `BracketAndIndent` — 括号匹配（`BracketMatcher.findMatchingBracket`）+ 自动闭合（`shouldAutoClose`）+ 自动环绕（`shouldAutoSurround` + `autoClosingEdit`）+ 智能缩进（`SmartIndentHandler.handleEnter` / `handleTab` / `handleBacktab`）
- [x] `LineEditingController` — 行编辑命令引擎（deleteLine、copyLineUp/Down、moveLineUp/Down、insertLineAbove/Below、sortLines、transpose、toggleLineComment）
- [x] Auto-closing pairs — `BracketPair` + `AutoClosingPair` 定义，支持语言特定配置（`BracketPairsConfig.defaultForLanguage`）
- [x] Auto-surround — `BracketMatcher.autoClosingEdit` 处理选中文本环绕
- [x] Smart Enter — `SmartIndentHandler.handleEnter` 智能缩进换行（含括号间额外缩进）
- [x] Tab indent / Backtab outdent — `SmartIndentHandler.handleTab` / `handleBacktab`
- [x] Line editing commands — 全部 11 个行编辑命令通过 `performLineEdit(_:)` 接入 EditorState
- [x] Bracket match overlay — 括号匹配高亮 UI 渲染完整接入（`applyPrimaryCursorObservation`、`applyCanonicalSelectionSet`、`notifyContentChanged` 均触发 `updateBracketMatch()`）
- [x] `BracketAndIndentTests`（280 行）、`LineEditingControllerTests`（247 行）、`EditorSaveParticipantControllerTests`、`EditorSavePipelineControllerTests` 已编写对应测试文件（待 test target / test plan 接入后运行验证）
- [x] 外部文件修改冲突处理 — 轮询检测外部修改，未保存改动时进入 conflict state，支持 `Reload from Disk` / `Keep Editor Version`，并已编写 `EditorExternalFileConflictTests` 用例（待 test target / test plan 接入后运行验证）
- [x] BracketAndIndent 与实际 TextView 输入的集成 — `MultiCursorInputInstaller` 已通过 `swizzleInsertText / insertNewline / insertTab / insertBacktab` 接到真实 `TextView` 输入链，单光标、多选区、多光标路径都已进入事务化编辑

---

## Phase 10: Language Highlight Extensibility

### 目标

把语言高亮能力从当前内建 provider 链推进到真正可扩展的插件注入模型，为 Markdown 等非 tree-sitter 友好语言提供扩展入口。

### 任务

1. 在 `EditorFeaturePlugin` 体系中新增 highlight provider 注入点
2. 让 registry 能按语言查询 highlight provider
3. 让编辑器高亮链消费插件注入的 provider
4. 落地 Markdown 语法高亮插件
5. 确保该能力遵守 Phase 8 的 viewport / 大文件 / 增量更新约束

### 清单

- [x] 新增 `EditorHighlightProviderContributor`
- [x] `EditorExtensionRegistry` 支持按语言查询 highlight provider
- [x] `SourceEditorView` / 状态层接入插件高亮 provider 链

---

## Phase 11: Final Validation

### 目标

把“代码可构建”升级成“计划可验证”，为后续继续向 VS Code 靠齐建立稳定回归基础。

### 清单

- [x] `AgentEditorPlugin` 相关测试 target / test plan 接入 `xcodebuild test`
- [x] 可独立运行关键测试：undo/redo、selection stability、external conflict、large file mode、command presentation
- [x] split editor / session restore / find-replace 关键路径 smoke tests 可运行

---

## Phase 12: Kernel Decomposition

### 目标

把已经存在但仍集中在 `EditorState` 内部的职责继续拆开，让“内核已存在”升级为“内核边界清晰、易维护、易扩展”。

### 任务

1. 按职责把 `EditorState` 继续拆成更小的状态/控制器对象
2. 明确哪些状态属于 document / session / workbench / panel / runtime gating
3. 减少跨模块回调和镜像字段
4. 让新增能力不再默认落进 `EditorState.swift`

### 优先拆分对象

| 模块 | 当前来源 | 目标职责 |
|------|------|------|
| `EditorDocumentController` | `EditorState` + 文件加载逻辑 | 打开/关闭/加载/重载/编码/外部冲突 |
| `EditorPanelController` | `panelState` 镜像字段 | hover / references / problems / signature help / code action |
| `EditorRuntimeModeController` | large file / viewport gating | runtime availability / transition cleanup |
| `EditorCommandController` | 命令刷新与执行入口 | command context、registry refresh、command dispatch |
| `EditorSaveController` | save pipeline glue | save participants / deferred actions / external write flow |

### 验收

1. `EditorState.swift` 明显降重，不再承担默认新增能力入口
2. 新增能力可以先选模块，再决定是否需要触达 `EditorState`
3. 状态源头更清晰，镜像字段减少

### 清单

- [x] 为 `EditorState` 补职责分区文档（字段/方法按 document、session、workbench、panel、runtime、command 分类）
- [x] 抽离 `EditorDocumentController`
- [x] 抽离 `EditorPanelController`
- [x] 抽离 `EditorRuntimeModeController`
- [x] 抽离 `EditorCommandController`
- [x] 抽离 `EditorSaveController`
- [x] `EditorState.swift` 行数下降到可接受范围（目标：先压到 `< 2500`）

---

## Phase 13: Bridge Boundaries

### 目标

把“桥接还在代码里，但边界不清晰”的状态升级成真正的 adapter/bridge/input router 分层。

### 任务

1. 建立显式 `SourceEditorAdapter`
2. 建立显式 `TextViewBridge`
3. 建立显式 `EditorInputRouter`
4. 让 `SourceEditorView` 只消费渲染输入，不再混入行为拼装
5. 让 `EditorCoordinator` 退出“全能胶水层”角色

### 目标边界

| 模块 | 责任 |
|------|------|
| `SourceEditorAdapter` | 把 `EditorState` / `EditorSnapshot` / highlight providers / overlays 映射到 `CodeEditSourceEditor` |
| `TextViewBridge` | 把原生 TextView 事件转成事务/命令/选择变化 |
| `EditorInputRouter` | 管理键盘输入、命令分发、输入法/多光标兼容策略 |
| `OverlayLayoutSystem` | 统一 overlay 几何与视口坐标转换 |

### 验收

1. `SourceEditorView.swift` 进一步退化为薄渲染消费层
2. `EditorCoordinator.swift` 不再承担业务副作用中心
3. 输入链和渲染链职责边界可单独解释、单独测试

### 清单

- [x] 新增 `SourceEditorAdapter`
- [x] 新增 `TextViewBridge`
- [x] 新增 `EditorInputRouter`
- [x] 迁移 `SourceEditorView` 中剩余行为拼装逻辑到 adapter / bridge
- [x] 迁移 `EditorCoordinator` 中剩余事务外副作用到明确归属模块
- [x] 为 bridge 层补最小可运行测试或验证用例

---

## Phase 14: Platform Hardening

### 目标

把“架构方向正确”推进到“长期可演进的平台”，建立最基本的回归、基线和边界决策机制。

### 任务

1. 固化性能基线
2. 固化关键路径回归入口
3. 建立独立的体验验证手册
4. 形成是否 fork `CodeEditSourceEditor` 的决策门槛

### 验收

1. 有固定的性能与回归入口，不靠人工印象判断
2. 验证细节已沉淀到独立手册，而不是散落在 roadmap
3. 是否 fork `CodeEditSourceEditor` 有客观门槛，不再靠感觉讨论

### 清单

- [x] 增加性能基线记录（至少覆盖 open / edit / command / LSP 四类）
- [x] 整理关键回归命令清单并写回本文件
- [x] 增加多 session / 多 split / 大文件压力验证脚本或手册
- [x] 为 `CodeEditSourceEditor` fork 决策建立触发条件与评估表

具体验证命令、压力场景和记录模板，统一见 [EDITOR_STRESS_PLAYBOOK.md](/Users/colorfy/Code/CofficLab/Lumi/docs/plugins/AgentEditorPlugin/EDITOR_STRESS_PLAYBOOK.md:1)。

---

## Phase 15: Workbench UX Completion

### 目标

把现有 workbench 从“可用”提升到“接近 VS Code 的连续工作流”。

### 任务

1. 补齐编辑器顶部与导航辅助 UI
2. 补齐侧边面板与底部面板联动
3. 统一编辑器状态反馈与上下文信息
4. 补齐预览态、固定态、历史恢复等工作流细节

### 验收

1. 用户能在不记命令名的前提下自然完成“打开、定位、切换、恢复、关闭、跳转”
2. 面板状态切换、焦点切换、split/tab 切换不会丢失上下文
3. 常见工作流在 UI 层有可见反馈，不依赖日志或隐式行为

### 清单

- [x] breadcrumb 导航（文件路径 / 符号路径 / 快速跳转）
- [x] outline 视图接入当前 session / active editor
- [x] minimap 策略与大文件 gating 后的可见行为统一
- [x] open editors 面板增强（dirty / pinned / active / group 归属更清晰）
- [x] references / problems / call hierarchy / workspace symbols 底部面板统一化
- [x] editor title 区支持 preview / pinned / dirty / language / readonly 状态展示
- [x] 最近关闭 editor 恢复（reopen closed editor）
- [x] tab / split 拖拽移动与跨 group 重排
- [x] 跳转历史 UI 反馈（返回 / 前进的可见提示）
- [x] workbench 相关 smoke tests 与人工验证场景补齐（`EDITOR_STRESS_PLAYBOOK.md` 新增 Workbench / Panel 测试组与 workbench smoke 专项，覆盖 split / reopen / bottom panel / open editors / back-forward 提示）

---

## Phase 16: Editor Surface & Interaction Polish

### 目标

把编辑表面的视觉反馈和高频交互打磨到更接近 VS Code。

### 任务

1. 打磨光标、选区、匹配、hover、诊断、code action 等表面反馈
2. 补齐更完整的 gutter / decoration / inline UI
3. 强化查找替换、多光标、括号与缩进的可见交互反馈

### 验收

1. 高频编辑行为有稳定且即时的视觉反馈
2. gutter / overlay / inline UI 不再像独立功能拼接，而是统一体验
3. 大文件与 viewport gating 下，反馈会降级但不突兀

### 清单

- [x] gutter decoration contract（diagnostic / git-like / symbol / custom marker）
- [x] 当前行、高亮匹配、括号高亮、selection highlight 视觉统一
- [x] hover 卡片视觉与定位策略统一
- [x] code action lightbulb / quick fix 入口进一步贴近 VS Code 交互
- [x] inline message / inline value / inline diff 预留 UI contract
- [x] find match / current match / replace preview 视觉增强
- [x] multi-cursor 可见性增强（primary / secondary cursor differentiation）
- [x] folding affordance、fold region summary、展开收起动画优化
- [x] editor context menu 统一走 command / context contribution 链
- [x] interaction polish 的 screenshot baseline 或 UI 检查清单

---

## Phase 17: Extension Surface & Contribution Points

### 目标

把现有 contributor 体系从“够用”提升到“可扩展、可组合、可被长期维护”的 editor 扩展接口。

### 任务

1. 明确 editor extension API 边界
2. 补齐缺少的 contribution points
3. 让 UI 与插件贡献点真正接上
4. 提供最小样例插件，验证 contract 不是纸面设计

### 验收

1. 插件可以稳定贡献 command、highlight、code action、hover、panel、decoration 等能力
2. editor 不需要为每个新插件写特判接线
3. 至少有 2-3 个样例插件走同一套 contract 成功接入

### 清单

- [x] 定义 `EditorDecorationContributor`
- [x] 定义 `EditorHoverContentContributor`
- [x] 定义 `EditorContextMenuContributor`
- [x] 定义 `EditorPanelContributor`（problems / references / custom tool panel）
- [x] 定义 `EditorStatusItemContributor`（状态栏 / toolbar / title actions）
- [x] 定义 `EditorQuickOpenContributor`（符号 / 文件 / 命令统一入口）
- [x] 扩展 `EditorExtensionRegistry` 支持上述 contribution points
- [x] 为贡献点增加优先级、去重、冲突处理与 enablement context
- [x] 提供至少一个 decoration 样例插件
- [x] 提供至少一个 hover / panel 样例插件
- [x] 提供一组 extension contract tests

---

## Phase 18: Settings, Discoverability, and VS Code Parity Gaps

### 目标

把“有能力”变成“用户找得到、配得动、用得顺”，并补齐仍明显落后于 VS Code 的体验缺口。

### 任务

1. 统一 editor 设置入口
2. 提升 discoverability
3. 补齐最影响体感的 parity gap
4. 建立 UI/扩展层的最小回归基线

### 验收

1. 用户不需要读文档，也能找到主要 editor 能力与设置入口
2. 新扩展接入后，其命令、菜单、状态项、设置能自动被发现
3. 核心 UI/扩展体验有固定回归手册，不靠人工记忆

### 清单

- [x] editor 专属设置页（字体、tab size、wrap、minimap、folding、line numbers、render whitespace）
- [x] settings search 与 command palette / quick open 联动
- [x] command palette 支持最近命令、常用命令、分类记忆
- [x] 欢迎或空状态页补 editor 功能 discoverability
- [x] 保存冲突、外部修改、格式化失败、LSP 不可用等状态提示文案统一
- [x] 语言特定设置覆盖策略（global / workspace / language override）
- [x] 插件贡献设置项的统一注册与展示
- [x] “用例驱动”的 UI 回归手册（打开文件、查找、rename、split、quick fix、restore）
- [x] UI / 扩展层 smoke tests 命令清单写回文档
- [x] 梳理与 VS Code 仍有明显差距的前 10 项体验缺口，并按优先级排序

UI / 扩展层的具体验证命令、压力场景和记录模板，统一见 [EDITOR_STRESS_PLAYBOOK.md](/Users/colorfy/Code/CofficLab/Lumi/docs/plugins/AgentEditorPlugin/EDITOR_STRESS_PLAYBOOK.md:1)。

最低执行要求：

1. 大文件打开与长行保护
2. 多 session 恢复
3. 2-way / 3-way split 切换与 unsplit
4. 多光标高频编辑
5. LSP 快速切换下的 stale rejection

## Phase 19: Remaining VS Code Parity Gaps

### 目标

把“已经能用”的 editor 进一步推进到“默认工作流不露怯”，优先补齐仍然最影响真实日用体验的差距。

### 任务

1. 按真实工作流而不是按模块罗列剩余缺口
2. 给每项缺口分配优先级，避免后续实现顺序失真
3. 只保留会直接影响 editor 主工作流的差距，不把更大 workbench 范围的问题混进来

### 验收

1. 团队能清楚知道“下一步为什么做这几项，而不是别的”
2. 每个缺口都能映射到具体的用户动作和可观察症状
3. 后续 phase 能直接从这份优先级表里摘任务，不需要重新盘点

### 清单

- [ ] P0. `Quick Open` 仍未补齐 VS Code 的 `file / symbol / line / command` 一体化语法与排序策略
  当前更像“command palette + 若干 section 拼接”，缺少 `@`、`#`、`:`、最近文件权重、同名文件 disambiguation 这类高频肌肉记忆入口。
- [ ] P0. `Peek` 体验缺失，definition / references 仍以跳转或底部 panel 为主
  VS Code 常用的 peek definition / peek references 能减少上下文切换；当前只能在跳转和面板之间选，编辑流会被打断。
- [ ] P0. `Rename` 仍缺少更完整的 in-place flow
  现在请求链和事务是通的，但还缺少更接近 VS Code 的 inline rename 输入框、批量影响预期反馈、失败回退提示和多文件 rename 的可视确认。
- [ ] P0. `Code Action / Quick Fix` 仍未覆盖更完整的 keyboard-first 体验
  lightbulb 和 panel 已统一，但还缺少更强的键盘直达路径、自动聚焦策略、preferred action 语义，以及与 diagnostics / cursor 移动联动的更稳切换。
- [ ] P1. `Search in Files / Search Editor` 能力缺失
  当前只补齐了当前 editor 内 find/replace，没有 VS Code 那种跨文件搜索、结果树、search editor、批量替换确认流。
- [ ] P1. `Folding` 仍缺少持久化、层级命令与更完整的摘要策略
  折叠 affordance 和 summary 已有，但还没有稳定的 fold state restore、按层级折叠/展开、按 selection 或 symbol 范围折叠。
- [ ] P1. `Sticky Scroll / 更强 breadcrumb-symbol 联动` 缺失
  breadcrumb 已有，但 VS Code 式的 sticky scroll 和当前 symbol 跟踪仍缺位，长文件中定位上下文的成本偏高。
- [ ] P1. `Gutter / diff / source control decoration` 只完成了 contract，未接入真实工作流
  现在只是把 lane、优先级和 custom marker contract 搭起来了，真实的 git diff add/modify/delete 标记、点击跳转、hover 摘要还没形成闭环。
- [ ] P2. `Snippet / tabstop / placeholder navigation` 不完整
  completion、多光标和输入事务已经稳定很多，但还缺少 VS Code 常见的 snippet placeholder 跳转、linked editing、tabstop 退出语义。
- [ ] P2. `Context key / when-clause` 体系仍偏轻量
  贡献点 enablement 已有，但离 VS Code 那种统一的 context key、menu location、when-clause 组合规则还有距离，复杂扩展接入时表达力仍不足。
