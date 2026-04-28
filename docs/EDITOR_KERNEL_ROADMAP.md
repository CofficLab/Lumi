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

**已完成：**
- [x] 明确"谁是文本真相来源" — `EditorBuffer` 已成为 canonical text holder，`EditorDocumentController` 持有 buffer 并管理 NSTextStorage 桥接
- [x] 定义编辑行为向 transaction 模型收敛 — `EditorTransaction` 已统一表达 replace/insert/delete/apply text edits/replace selections
- [x] 列出现存内核问题清单 — 路线图文档"当前代码里的核心问题"章节已完成
- [x] `Kernel/` 目录已建立，核心文本模型已落地

**未完成：**
- [ ] 性能基线指标（打开文件耗时、打字延迟、completion/hover/rename 延迟、大文件表现）尚无量化数据
- [ ] 缺少性能回归自动化检测机制

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

**已完成：**
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
- [x] `EditorBufferTests` 测试已覆盖

**未完成：**
- [ ] `EditorUndoManager` — 目标架构 Layer 1 中规划，尚未独立实现，undo/redo 仍依赖原生 NSUndoManager
- [ ] NSTextStorage 与 buffer 双写的同步风险尚未完全消除（`syncBufferFromTextStorageIfNeeded()` 作为补偿手段存在）
- [ ] selection 映射在 format/rename 后的光标稳定性尚未有专项测试

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

**已完成：**
- [x] `EditorSelectionSet` — 内核选区 canonical state，支持 primary/secondary 选区、多光标模式判断、增删选区操作
- [x] `EditorSelectionMapper` — TextView ↔ 内核选区双向桥接（`toCanonical`、`applyToView`、`shouldAcceptCanonicalUpdate`）
- [x] `canonicalSelectionSet` 已在 EditorState 中作为内核选区状态持有
- [x] `applyCanonicalSelectionSet(_:)` 方法已实现，coordinator 通过此方法更新内核选区
- [x] 多光标 replacement 已重构为 transaction-aware（Phase 1 已完成）
- [x] 多光标 delete 已重构为 transaction-aware（Phase 1 已完成）
- [x] `EditorSelectionSetTests` 测试已覆盖
- [x] `EditorSelectionMapperTests` 测试已覆盖
- [x] `MultiCursorTransactionBuilderTests` 测试已覆盖

**未完成：**
- [ ] `EditorCursorState` — 路线图原计划独立模块，实际功能已分散融入 `EditorSelectionSet`，可考虑后续整理
- [ ] swizzle 依赖尚未完全退化 — `MultiCursorCommandsEditorPlugin` 仍依赖 `swizzleInsertText` / `swizzleDeleteBackward` 作为输入路由
- [ ] completion / format / rename 后的选区恢复尚无专项自动测试

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

**已完成：**
- [x] `EditorSession` — 每个打开文件的独立编辑状态（fileURL、multiCursorState、panelState、isDirty、findReplaceState、scrollState、viewState）
- [x] `EditorTab` — tab 展示单元（sessionID、fileURL、title、isDirty、isPinned）
- [x] `EditorSessionStore` — session/tab 管理（openOrActivate、activate、close、closeOthers、goBack、goForward）
- [x] `EditorFindReplaceState` — 查找状态（findText、replaceText、options、resultCount、selectedMatchIndex）
- [x] `EditorNavigationHistory` — 导航历史（recordVisit、goBack、goForward、remove）
- [x] `EditorRootView` 已引入 `@StateObject sessionStore`，文件选中走 `openOrActivate` session
- [x] `EditorTabStripView` 已实现 — 支持导航前进/后退、tab 选择/关闭、pin/unpin、close others、open editors 下拉菜单
- [x] `EditorSession` 保存 cursor/scroll/find/panel 状态，切换 tab 后恢复
- [x] `EditorSessionTests`（1144 行）、`EditorSessionStoreTests` 已覆盖

**未完成：**
- [ ] 一些面板状态可能仍是全局的（如 hover 内容、reference 结果），session-local vs global 划分可能不完全
- [ ] 自动保存、外部文件刷新的 session 感知有待验证

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

**已完成：**
- [x] `EditorGroup` — 分栏组模型，管理 sessions/tabs/activeSessionID，支持 `split(_:)`、`unsplit()`、`moveSessionToOtherGroup`
- [x] `EditorWorkbenchState` — 工作台顶层状态管理器，管理 rootGroup 树 + activeGroupID
- [x] `EditorGroupHostStore` — Group host 状态管理
- [x] Split editor — `EditorGroup.split(.horizontal/.vertical)` 创建子 group，支持水平/垂直分割
- [x] Unsplit — `EditorGroup.unsplit()` 合并子 group
- [x] Session 移动 — `moveSessionToOtherGroup(sessionID:targetGroupID:)`
- [x] Active group tracking — `EditorWorkbenchState.activeGroupID` + `focusNextGroup()` / `focusPreviousGroup()`
- [x] 全局 session 查找 — `groupContainingSession(sessionID:)`
- [x] 叶子 group 枚举 — `leafGroups()` 递归获取
- [x] `EditorRootView` 已接入 workbench — `@StateObject workbench`，`splitEditor()`、`unsplitEditor()` 方法，split 后 HSplitView/VSplitView 布局
- [x] Split 后在新分栏中复制当前活跃 session（VS Code 风格）
- [x] Workbench 命令已注册 — split-right、split-down、close-split、focus-next/previous-group、move-to-next/previous-group

**未完成：**
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

**已完成：**
- [x] `CommandRegistry` — 中央命令注册中心，支持 register/execute/availableCommands(context-based enablement)
- [x] `CommandRouter` — 新旧命令体系双向桥接（`registerSuggestions`、`suggestionsFromRegistry`、`execute`）
- [x] `CoreCommandRegistrations` — 所有计划命令已注册（共 35 个命令，覆盖全部 9 个分类）
- [x] `EditorCommandPresentationModel` — 命令搜索/分类/排序模型
- [x] `EditorCommandCategory` — 命令分类枚举（format/navigation/workbench/multiCursor/find/lsp/save/edit/other）
- [x] `EditorCommandSection` — 命令分区模型
- [x] `EditorCommandPaletteView` — 命令面板 UI，支持搜索、分类过滤、快捷键显示
- [x] `CommandContext` — 上下文感知的命令启用状态（hasSelection、languageId、isEditorActive、isMultiCursor）
- [x] `EditorCommandBindings` — 快捷键绑定映射
- [x] `EditorCommandPaletteTests` 测试已覆盖

**未完成：**
- [ ] 键位可配置化 — 用户自定义快捷键映射（在"后续方向"中）
- [ ] toolbar / context menu 是否已完全走 command id 需逐一验证

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

**已完成：**
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
- [x] `RequestGenerationTests` 测试已覆盖
- [x] `LSPDebouncerTests` 测试已覆盖

**未完成：**
- [ ] SemanticTokenHighlightProvider — 未找到独立的 Provider 文件（可能内嵌在其他模块中），需确认是否已迁移
- [ ] 文档版本感知 — LSP 管线尚未与 `EditorBuffer.version` 对齐，目前使用 `RequestGeneration` 而非 buffer version
- [ ] viewport/cursor 敏感刷新 — 部分管线已通过 debouncer 实现，但尚未系统化

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

**已完成：**
- [x] `EditorFindReplaceState` — 查找状态模型（findText、replaceText、options、resultCount、selectedMatchIndex、selectedMatchRange）
- [x] `EditorFindReplaceOptions` — 查找选项（regex、caseSensitive、wholeWord、inSelection）
- [x] `EditorFindReplaceController` — 查找匹配引擎（正则匹配、next/previous 导航、selectedMatchIndex 计算逻辑）
- [x] `EditorFindMatch` — 匹配结果模型
- [x] `EditorFindReplaceTransactionBuilder` — 查找替换 transaction 构建器
- [x] Transaction-based replace current — 通过 `applyEditorTransaction(_:reason: "find_replace_current")` 落地
- [x] Transaction-based replace all — 通过 `applyEditorTransaction(_:reason: "find_replace_all")` 落地
- [x] per-session 保存查找状态 — `EditorSession.findReplaceState` 为每个 session 独立持有
- [x] Find/Replace 命令已注册 — find、find-next、find-previous、replace-current、replace-all
- [x] `EditorFindReplaceControllerTests`、`EditorFindReplaceTransactionBuilderTests` 测试已覆盖

**未完成：**
- [ ] preserve case 替换选项
- [ ] 与 multi-cursor selection 联动的 in-selection 查找需进一步验证

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

**已完成：**
- [x] `LargeFileMode` — 文件大小分级（normal / medium / large / mega），带阈值常量
- [x] `LongLineDetector` — 长行检测器，检测超长行（>10,000 字符）
- [x] `ViewportRenderController` — Viewport 渲染控制器（visibleStartLine/EndLine、bufferSize、shouldDebounceUpdate）
- [x] 运行时模式接线 — `EditorState.loadFile` 中根据文件大小维护 `largeFileMode`
- [x] 功能自动降级 — `LargeFileMode` 提供 `isSemanticTokensDisabled`、`isInlayHintsDisabled`、`isFoldingDisabled`、`isMinimapDisabled`、`isReadOnly` 等属性
- [x] 语法高亮上限 — `maxSyntaxHighlightLines` 按 mode 分级（normal→∞、medium→50K、large→10K、mega→1K）
- [x] 长行保护 — `isLongLineProtectionEnabled` 在 large/mega 模式启用
- [x] `ViewportRenderController` 已在 `EditorState` 中实例化
- [x] `LargeFileModeTests` 测试已覆盖（191 行）

**未完成：**
- [ ] Inlay viewport 调度 — viewport 变化驱动 inlay hint 请求调度尚未实现
- [ ] 截断安全 — 大文件截断预览尚未实现
- [ ] ViewportRenderController 与实际渲染的绑定尚未完全实现（控制器存在但可能未驱动实际渲染）

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

**已完成：**
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
- [x] `BracketAndIndentTests`（280 行）、`LineEditingControllerTests`（247 行）、`EditorSaveParticipantControllerTests`、`EditorSavePipelineControllerTests` 测试已覆盖

**未完成：**
- [ ] Bracket match overlay — 括号匹配高亮的 UI 层渲染（内核计算已有，UI 层需验证）
- [ ] 外部文件修改冲突处理
- [ ] BracketAndIndent 与实际 TextView 输入的集成（目前为内核模型，需确认接入程度）

---

## 优先级建议

如果目标是最快拉近和 VS Code 的核心体验差距，建议执行顺序：

1. **Phase 1**: Buffer / Transaction Core
2. **Phase 2**: Selection / Cursor Core
3. **Phase 3**: Sessions / Tabs
4. **Phase 5**: Commands / Keybindings
5. **Phase 6**: Language Pipelines
6. **Phase 7**: Find / Replace
7. **Phase 4**: Workbench Groups
8. **Phase 8**: Performance / Large Files
9. **Phase 9**: Polish

> Phase 4 很重要，但不建议早于 buffer 和 selection 稳定化，否则容易在不稳的底层上叠工作台复杂度。

## 推荐的提交顺序

1. 新增 `Kernel/` 目录 + EditorBuffer/Snapshot/Transaction（不接 UI）
2. EditorState 接入 buffer + applyEditorTransaction + format 走 transaction
3. rename 走 transaction + code action text edits 走 transaction
4. Canonical selection model + coordinator 收口选区同步
5. 多光标 replacement / delete 迁移到 transaction
6. 新增 `EditorSession` + EditorRootView 切 session store + 基础 tab strip

## 测试建议

内核升级过程中，建议优先补这些测试：

1. `EditorBuffer` 应用单次编辑
2. `EditorBuffer` 应用多个 ranges 编辑
3. transaction 后 selection 映射
4. format 后光标恢复
5. rename 后多文件变更应用
6. 多光标 replace/delete
7. session 切换后恢复 cursor/scroll

测试优先级：

1. transaction correctness
2. selection stability
3. multi-cursor behavior
4. session restoration

## 成功标准

这个计划成功的标志不是"功能数量接近 VS Code"，而是：

1. 文本真相不再主要由原生 TextView 持有
2. 编辑行为以事务为中心
3. tab / split / navigation 成为正式模型
4. 异步语言能力版本安全
5. 大文件和高频编辑场景下依然可用
6. 重度 VS Code 用户进入后不会频繁撞到结构性粗糙感

## 后续方向

1. **多 EditorState 实例** — split editor 需要支持多实例才能让 split 真正可用
2. **Viewport 精细化** — `ViewportRenderController` 驱动更细粒度的按需渲染和 LSP viewport 刷新
3. **Cursor motion 语义打磨** — VS Code 级别的 word navigation、line boundary、smart home
4. **键位可配置化** — 用户自定义快捷键映射

## 最终结论

我们真正要做的，不是：

> "让当前编辑器看起来更像 VS Code"

而是：

> "把当前编辑器升级成一个 Swift 原生、但在设计哲学上与 VS Code 对齐的编辑器内核"

只要这一点成立，后续的 UI、交互和高级能力都会更容易自然长出来。
