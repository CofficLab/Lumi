# Editor Kernel Roadmap & Execution Plan

## 目标

不是简单做一个"带很多功能的原生编辑器"，而是用 Swift 把 VS Code 的核心编辑体验尽量复刻出来，并且把重心放在编辑器内核升级上。

这意味着我们优先关注：

1. 文本缓冲与文档模型
2. 编辑事务与撤销重做
3. 光标、选区、多光标语义
4. 标签页、分栏、编辑器会话
5. 语言服务管线
6. 性能、大文件、长行与可恢复性

不优先关注：

1. 扩展市场
2. 远程开发
3. 调试器生态
4. VS Code 扩展兼容层

## 核心判断

当前 `AgentEditorPlugin` 已经具备不错的基础：

1. 有 `CodeEditSourceEditor` 作为编辑表面
2. 有 LSP 相关能力
3. 有 editor feature plugin / contributor 结构
4. 有多光标、rename、format、references、hover、completion 等雏形

但目前更接近：

> "以原生文本视图为中心，再逐步挂更多能力"

而不是：

> "以编辑器模型为中心，视图、语言服务、工作台状态都围绕它组织"

如果目标是向 VS Code 看齐，核心不是继续平铺功能，而是调整内核抽象。

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

### 5. Performance Is Part of the Kernel

性能不是后期补丁，而是内核设计的一部分：

1. 大文件模式
2. 长行保护
3. 增量高亮
4. viewport 限界更新
5. overlay 更新限流
6. 主线程最小化压力

## 目标架构

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

## 当前代码里的核心问题

基于现有实现，当前最需要解决的不是"缺功能"，而是这几个结构性问题：

1. **`EditorState.swift` 过重** — 同时承担文件状态、UI 状态、LSP 状态、面板状态、编辑状态和命令入口，已经接近 monolith。
2. **`EditorRootView.swift` 仍是单文件驱动** — 编辑器入口基本跟随 `selectedFileURL` 切换，不是 session/workbench 驱动。
3. **`SourceEditorView.swift` 仍然过于接近"编辑器中心"** — 应该逐步退化为渲染层，而不是继续成为行为聚合中心。
4. **`EditorCoordinator.swift` 主要在做同步胶水** — 既处理选区、脏状态、LSP 增量同步，也在承担编辑行为副作用。
5. **多光标实现偏事件劫持** — `MultiCursorCommandsEditorPlugin` 高度依赖原生输入拦截，对后续 IME、撤销、统一事务模型不友好。
6. **LSP 管线缺少更严格的 request lifecycle** — 目前已有良好基础，但还不够接近 VS Code 那种 request generation、stale response protection、cancellation 驱动的风格。

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

### 新增模块

在 `AgentEditorPlugin` 下新增 `Kernel/` 目录：

1. `Kernel/EditorBuffer.swift`
2. `Kernel/EditorSnapshot.swift`
3. `Kernel/EditorRange.swift`
4. `Kernel/EditorSelection.swift`
5. `Kernel/EditorTransaction.swift`
6. `Kernel/EditorEditResult.swift`

### 核心职责

#### EditorBuffer

负责：持有 canonical text、持有 version、提供快照、应用事务、产出 selection 映射结果。

建议最小 API：

```swift
init(text: String)
var text: String
var version: Int
func snapshot() -> EditorSnapshot
func apply(_ transaction: EditorTransaction) -> EditorEditResult
```

#### EditorTransaction

负责统一表达编辑动作。第一版覆盖：

1. replace ranges
2. insert text
3. delete ranges
4. apply text edits from LSP
5. replace selections

#### EditorSelection

第一版只需要解决：

1. location/length
2. primary cursor
3. 多选区稳定表达

### 现有文件改造映射

#### EditorState.swift

第一阶段不要大拆 UI 状态，但要开始减重：

1. 新增 `buffer: EditorBuffer?`
2. 保留 `content: NSTextStorage?` 作为桥接输出，不再作为最终真相
3. 新增统一入口 `applyEditorTransaction(_:)`
4. 让 format、rename、code action、本地批量编辑、多光标 replacement 改走 transaction

建议新增几个中间方法：

```swift
loadBuffer(from text: String)
syncTextStorageFromBuffer()
applyEditorTransaction(_ transaction: EditorTransaction, reason: String)
applyTextEdits(_ edits: [TextEdit], source: String)
```

#### SourceEditorView.swift

第一阶段不改 UI 结构，但要明确角色转变：

1. 只消费 `NSTextStorage` 和 session state
2. 不直接拥有核心编辑语义
3. coordinator 输出事件最终由 `EditorState.applyEditorTransaction` 统一处理

#### EditorCoordinator.swift

重点不是删功能，而是收口：

1. `didReplaceContentsIn` 不再直接散落触发多个副作用
2. 统一改成：收集变更 → 生成 transaction or delta event → 交给 state
3. 把"内容变化"和"选区变化"的处理职责拆开

### 迁移顺序

1. 先实现 `EditorBuffer`
2. 再加 `applyEditorTransaction`
3. 再把 `formatDocumentWithLSP()` 改走 transaction
4. 再把 `renameSymbolWithLSP()` 改走 transaction
5. 再把本地多选区 replacement 改走 transaction

### 风险

1. `NSTextStorage` 和 buffer 双写期间可能产生同步错误
2. selection 映射若不清晰，会让 format/rename 后光标位置不稳定
3. LSP full replace 和本地 transaction 并存期间，版本管理需要谨慎

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

### 新增模块

继续在 `Kernel/` 目录新增：

1. `Kernel/EditorSelectionSet.swift`
2. `Kernel/EditorCursorState.swift`
3. `Kernel/EditorSelectionMapper.swift`

### 核心思想

把"原生 TextView 的选区"与"内核选区"彻底区分开：

1. 内核选区是 canonical state
2. 原生选区是渲染/交互镜像

### 现有文件改造映射

#### EditorCoordinator.swift

要减少这些问题：

1. view 先改选区，state 再追
2. state 回写后又覆盖 view
3. 多光标状态与 cursorPositions 之间来回同步

建议目标：

1. 把 view selection 变化先变成 `EditorSelectionSet`
2. state 只接收结构化选区变化
3. 只有当 canonical selection 变化时，才反推回 TextView

#### MultiCursorCommandsEditorPlugin

建议处理顺序：

1. 保留现有功能，避免回归
2. 增加 transaction-aware 的多光标编辑入口
3. 把 `replaceSelection`、`deleteBackward` 等编辑行为逐步迁移到统一 transaction
4. 降低对 `swizzleInsertText` / `swizzleDeleteBackward` 的结构性依赖

不要求一次删掉 swizzle，但要让 swizzle 逐渐退化为输入路由，而不是编辑引擎本身。

### 迁移顺序

1. 在 state 中新增 canonical selection model
2. 增加 TextView ↔ SelectionSet 的单向桥接层
3. 重构多光标 replacement
4. 重构多光标 delete
5. 校验 completion、rename、format 后的选区恢复

### 风险

1. 键盘输入路径非常敏感，容易出现退格/输入法/撤销回归
2. 多光标行为和 CodeEdit 内部 selectionManager 的交互要小心
3. cursorPosition 与 NSRange 双体系并存时，必须明确谁是源，谁是映射

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

### 新增模块

新增 `Workbench/` 目录：

1. `Workbench/EditorSession.swift`
2. `Workbench/EditorTab.swift`
3. `Workbench/EditorSessionStore.swift`
4. `Workbench/EditorFindReplaceState.swift`
5. `Workbench/EditorNavigationHistory.swift`

### 最重要的思想变化

不要再让"选中文件"、"当前视图"、"当前文本内容"这三件事几乎等价。

要变成：

| 概念 | 含义 |
|------|------|
| 文件 | document identity |
| session | 打开中的编辑上下文 |
| tab | 工作台展示单元 |
| active session | 当前交互目标 |

### 现有文件改造映射

#### EditorRootView.swift

这是第三阶段主战场。建议分两步做：

第一步：

1. 引入 `EditorSessionStore`
2. `selectedFileURL` 不再直接等于"当前编辑器内容"
3. 选中文件时变成"打开或激活对应 session"

第二步：

1. 增加 tab strip
2. 当前中间编辑区域消费 active session
3. 状态栏、toolbar、breadcrumb 都改读 active session

#### EditorPanelView.swift

第三阶段可以先不做 split editor，但要提前留出 workbench 容器形态：

1. 保留左树 + 中间编辑区域布局
2. 中间区域的根节点从单 editor 切到 session container
3. 给未来的 group/split 预留插槽

#### EditorToolbarView.swift

后续要逐步从"直接操控 state"转向"针对 active session 执行命令"。

### 迁移顺序

1. 新增 `EditorSession`
2. 新增 `EditorSessionStore`
3. 在 `EditorRootView` 中接入 session store
4. 单文件切换改成 open-or-activate session
5. 引入 tab strip
6. 保存每个 session 的 cursor/scroll/find 状态

### 风险

1. 现有状态默认假设只有一个 active file
2. 一些面板状态可能当前是全局的，迁移后需要区分 global 和 session-local
3. 自动保存、外部文件刷新、LSP 打开文档的生命周期都要重新看

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

### 新增模块

1. `Workbench/EditorGroup.swift` — 编辑器分栏组
2. `Workbench/EditorWorkbenchState.swift` — 工作台顶层状态
3. `Workbench/EditorGroupHostStore.swift` — Group host 状态管理

### 核心能力

| 能力 | 说明 |
|------|------|
| Group 管理 | `EditorGroup` 管理独立 session 列表和活跃 session |
| Split editor | `EditorGroup.split(_ direction)` 水平/垂直分割 |
| Unsplit | `EditorGroup.unsplit()` 合并子 group |
| Session 移动 | `moveSessionToOtherGroup(sessionID:targetGroupID:)` |
| Active group tracking | `EditorWorkbenchState.activeGroupID` |
| 全局 session 查找 | `groupContainingSession(sessionID:)` |
| 叶子 group 枚举 | `leafGroups()` 递归获取所有编辑器容器 |

### 风险

- split 后的非活跃 group 显示占位，需要多 EditorState 实例支持

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

### 新增模块

1. `Kernel/CommandRegistry.swift` — 中央命令注册中心
2. `Kernel/CommandRouter.swift` — 新旧命令体系双向桥接
3. `Kernel/CoreCommandRegistrations.swift` — 核心命令注册
4. `Kernel/EditorCommandPresentationModel.swift` — 命令搜索/分类/排序
5. `Kernel/EditorCommandCategory.swift` — 命令分类枚举
6. `Kernel/EditorCommandSection.swift` — 命令分区模型

### 计划注册的命令

| 分类 | 命令 ID | 快捷键 |
|------|---------|--------|
| format | `builtin.format-document` | ⌘⇧⌥F |
| navigation | `builtin.open-editors-panel` | ⌘⇧E |
| navigation | `builtin.find-references` | ⌘⌥R |
| navigation | `builtin.rename-symbol` | ⌘⇧R |
| navigation | `builtin.workspace-symbols` | ⌘⇧O |
| navigation | `builtin.call-hierarchy` | ⌘⌥H |
| workbench | `builtin.command-palette` | ⌘⇧P |
| workbench | `builtin.split-right` | ⌘\\ |
| workbench | `builtin.split-down` | ⌘⇧\\ |
| workbench | `builtin.close-split` | ⌘⌥\\ |
| workbench | `builtin.focus-next-group` | ⌘⌥] |
| workbench | `builtin.focus-previous-group` | ⌘⌥[ |
| workbench | `builtin.move-to-next-group` | ⌘⌥⇧] |
| workbench | `builtin.move-to-previous-group` | ⌘⌥⇧[ |
| multi-cursor | `builtin.add-next-occurrence` | — |
| multi-cursor | `builtin.select-all-occurrences` | — |
| multi-cursor | `builtin.clear-additional-cursors` | — |
| find | `builtin.find` | ⌘F |
| find | `builtin.find-next` | ⌘G |
| find | `builtin.find-previous` | ⌘⇧G |
| find | `builtin.replace-current` | — |
| find | `builtin.replace-all` | — |
| lsp | `builtin.trigger-completion` | — |
| lsp | `builtin.trigger-parameter-hints` | — |
| save | `builtin.save` | — |
| edit | `builtin.delete-line` | ⌘⇧K |
| edit | `builtin.copy-line-down` | ⌥⇧↓ |
| edit | `builtin.copy-line-up` | ⌥⇧↑ |
| edit | `builtin.move-line-down` | ⌥↓ |
| edit | `builtin.move-line-up` | ⌥↑ |
| edit | `builtin.insert-line-below` | ⌘↩ |
| edit | `builtin.insert-line-above` | ⌘⇧↩ |
| edit | `builtin.sort-lines-ascending` | — |
| edit | `builtin.sort-lines-descending` | — |
| edit | `builtin.toggle-line-comment` | ⌘/ |
| edit | `builtin.transpose` | ⌃T |

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

验收结果（2026-04-29）：

1. `EditorCommand` 菜单层已改为直接读取 `EditorKeybindingStore` 的生效快捷键，不再只显示默认绑定。
2. `EditorState` 在生成 command suggestions / sections 与执行命令前，会同步刷新 `CoreCommandRegistrations`，保证 command palette、toolbar、context menu 读取到最新 shortcut。
3. `EditorCommandShortcut` 已补 `KeyEquivalent` / `EventModifiers` 映射，覆盖常见特殊键（Return / Tab / 方向键 / Space / Escape / Delete）。
4. 回归测试已通过：
   `DISABLE_SWIFTLINT=1 xcodebuild test -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:LumiTests/EditorCommandPaletteTests`
   日志结论：`EditorCommandPaletteTests passed`、`Executed 13 tests, with 0 failures`。
5. 设置页已新增独立“快捷键”入口，支持按命令名 / 命令 ID / 分类 / 快捷键搜索，支持录制新绑定，并能展示当前是“默认”还是“自定义”。
6. 快捷键冲突检测已覆盖默认绑定和自定义绑定；冲突时会阻止保存，并明确提示冲突命令。
7. 设置页已支持单条“恢复默认”和全局“恢复全部默认”。
8. 新增 `EditorShortcutCatalogTests`，验证自定义覆盖默认、按快捷键文本搜索、以及默认绑定冲突识别：
   `DISABLE_SWIFTLINT=1 xcodebuild test -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:LumiTests/EditorShortcutCatalogTests`
   日志结论：`EditorShortcutCatalogTests passed`、`3 tests in 1 suite passed`。
9. toolbar / context menu 中真正属于“编辑动作执行链”的入口已经全部并入 `command id -> CommandRegistry -> CommandRouter/CoreCommandRegistrations`；字体、缩进、保存策略等配置型 UI 保持独立设置入口，不作为本阶段命令系统的缺口继续追赶。

---

## Phase 6: Language Pipelines

### 目标

让语言智能在真实编码压力下依然稳定。

### 新增模块

- `Kernel/LSPRequestPipeline.swift` — 请求代际跟踪 + 取消上下文 + 请求生命周期包装器

### 核心能力

| 能力 | 说明 |
|------|------|
| Stale response protection | `RequestGeneration.isCurrent(_)` |
| Request generation ID | `RequestGeneration.next()` |
| Cancellation support | `CancellationContext` |
| Unified lifecycle | `LSPRequestLifecycle.run(operation:apply:)` |

### 计划迁移的 consumer

InlayHintProvider、DocumentHighlightProvider、CodeActionProvider、SignatureHelpProvider、WorkspaceSymbolProvider、SelectionRangeProvider、DocumentLinkProvider、DocumentColorProvider、CallHierarchyProvider、FoldingRangeProvider、SemanticTokenHighlightProvider、HoverCoordinator、LSPCompletionDelegate、JumpToDefinitionDelegate、EditorState.showReferencesFromCurrentCursor()

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

### 新增模块

- `Kernel/LargeFileMode.swift` — 大文件模式分类、长行检测器、Viewport 渲染控制器

### 计划能力

| 能力 | 说明 |
|------|------|
| 文件大小分级 | normal (<1MB) / medium (1-10MB) / large (10-50MB) / mega (>50MB) |
| 运行时模式接线 | `EditorState.loadFile` 维护 `largeFileMode` |
| 功能自动降级 | semantic tokens / inlay hints / folding / minimap 做 runtime gating |
| Viewport 渲染控制 | `ViewportRenderController` 驱动按需渲染 |
| 语法高亮上限 | `maxSyntaxHighlightLines` 按 viewport gating |
| Inlay viewport 调度 | viewport 变化驱动 inlay hint 请求调度 |
| 长行保护 | `LongLineDetector` 检测超长行并降级 |
| 截断安全 | 大文件截断预览 |

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

边界结论（2026-04-29）：

1. `CodeEditSourceEditor` 对 Lumi 暴露的可控面主要是 `language`、`configuration`、`highlightProviders`、`state` 与 `TextViewCoordinator`；真正的高亮器生命周期、provider diff、`NSTextStorage` delegate 接线和文本渲染刷新都在其包内部管理。
2. 这意味着“由 Lumi 外层直接把 `CodeEditSourceEditor` 的内部文本渲染裁剪成真正的 viewport render control”不属于当前依赖边界内可稳定完成的工作，应从 Phase 8 的核心验收项里剥离。
3. 当前正式策略定为：不 fork `CodeEditSourceEditor`，继续在 Lumi 自有层优化。
4. 已落地并验证有效的 Lumi 侧策略包括：`EditorState` 统一管理 viewport / 长行 / 大文件 gating，`SourceEditorView` 仅在运行时允许时挂载 tree-sitter / semantic token / document highlight / plugin highlight providers，overlay 与高成本 consumer 也统一受 Phase 8 runtime gating 约束。
5. 只有当后续需求明确指向“必须深入控制 `CodeEditSourceEditor` 内部高亮/布局刷新策略”且 Lumi 外层优化已证明不足时，才重新打开 fork 评估；在此之前，fork 不作为当前路线的默认分支。

---

## Phase 9: Polish

### 目标

把"可用"提升到"熟悉、顺手、像 VS Code"。

### Save Participants

- `Kernel/EditorSaveParticipantController.swift`
- `Kernel/EditorSavePipelineController.swift`
- 保存前自动执行：trim trailing whitespace、insert final newline
- `format on save` / `organize imports on save` / `fix all on save` 可配置
- 保存行为持久化配置
- 外部文件修改冲突处理

### 编辑体验引擎

- `Kernel/BracketAndIndent.swift` — 括号匹配 + 自动闭合 + 自动环绕 + 智能缩进
- `Kernel/LineEditingController.swift` — 行编辑命令引擎

### 计划接入的编辑体验

| 能力 | 说明 |
|------|------|
| Auto-closing pairs | 输入开括号自动补全闭括号 |
| Auto-surround | 选中文本后输入括号自动环绕 |
| Smart Enter | 智能缩进换行 |
| Tab indent / Backtab outdent | 智能缩进/反缩进 |
| Bracket match overlay | 括号匹配高亮 |
| Line editing commands | delete/copy/move/insert/sort/comment/transpose 行 |

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

## 最终结论

我们真正要做的，不是：

> "让当前编辑器看起来更像 VS Code"

而是：

> "把当前编辑器升级成一个 Swift 原生、但在设计哲学上与 VS Code 对齐的编辑器内核"

只要这一点成立，后续的 UI、交互和高级能力都会更容易自然长出来。
