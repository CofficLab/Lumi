# Editor Kernel Execution Plan

## 目的

这份文档是 [EDITOR_KERNEL_ROADMAP.md](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/EDITOR_KERNEL_ROADMAP.md) 的执行版。

Roadmap 解决的是“往哪里走”。
Execution Plan 解决的是“第一步、第二步、第三步具体怎么改当前代码”。

目标仍然不变：

1. 升级当前编辑器内核
2. 让设计哲学逐步向 VS Code 对齐
3. 避免一边加功能一边继续加深现有架构耦合

## 执行原则

在真正开始改代码前，先固定三条规则：

1. 不再继续把 `EditorState.swift` 当作长期唯一中心
2. 所有新增编辑能力优先走 transaction 模型
3. 视图层只负责展示和桥接，不负责持有核心编辑真相

## 当前代码里的核心问题

基于现有实现，当前最需要解决的不是“缺功能”，而是这几个结构性问题：

1. `EditorState.swift` 过重
   它同时承担文件状态、UI 状态、LSP 状态、面板状态、编辑状态和命令入口，已经接近 monolith。

2. `EditorRootView.swift` 仍是单文件驱动
   当前编辑器入口基本跟随 `selectedFileURL` 切换，不是 session/workbench 驱动。

3. `SourceEditorView.swift` 仍然过于接近“编辑器中心”
   它应该逐步退化为渲染层，而不是继续成为行为聚合中心。

4. `EditorCoordinator.swift` 主要在做同步胶水
   它现在既处理选区、脏状态、LSP 增量同步，也在承担编辑行为副作用。

5. 多光标实现偏事件劫持
   `MultiCursorCommandsEditorPlugin` 当前高度依赖原生输入拦截，这对后续 IME、撤销、统一事务模型都不友好。

6. LSP 管线缺少更严格的 request lifecycle
   目前已有良好基础，但还不够接近 VS Code 那种 request generation、stale response protection、cancellation 驱动的风格。

## 总体拆分策略

建议不要一次性重写，而是按“抽内核、保 UI、逐步迁移”的方式推进。

第一波重构只做三件事：

1. 把文本真相从视图侧拉出来
2. 把编辑行为统一到事务管线
3. 把单文件状态升级为 session 状态

这三件事做完，后面的 tab、split、command、find/replace 才会真正好做。

## Phase 1: Buffer / Transaction Core

### 目标

建立新的文本核心层，但不立刻替换现有 UI。

### 新增模块建议

建议在 `AgentEditorPlugin` 下新增一个新的 `Kernel/` 目录，放 Phase 1 的核心对象：

1. `Kernel/EditorBuffer.swift`
2. `Kernel/EditorSnapshot.swift`
3. `Kernel/EditorRange.swift`
4. `Kernel/EditorSelection.swift`
5. `Kernel/EditorTransaction.swift`
6. `Kernel/EditorEditResult.swift`

### 第一阶段核心职责

#### `EditorBuffer`

负责：

1. 持有 canonical text
2. 持有 version
3. 提供快照
4. 应用事务
5. 产出 selection 映射结果

建议最小 API：

1. `init(text: String)`
2. `var text: String`
3. `var version: Int`
4. `func snapshot() -> EditorSnapshot`
5. `func apply(_ transaction: EditorTransaction) -> EditorEditResult`

#### `EditorTransaction`

负责统一表达编辑动作。

第一版先覆盖这几类：

1. replace ranges
2. insert text
3. delete ranges
4. apply text edits from LSP
5. replace selections

#### `EditorSelection`

第一版只需要解决：

1. location/length
2. primary cursor
3. 多选区稳定表达

### 现有文件改造映射

#### [EditorState.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Store/EditorState.swift)

第一阶段不要大拆 UI 状态，但要开始减重。

先做这些调整：

1. 新增 `buffer: EditorBuffer?`
2. 保留 `content: NSTextStorage?` 作为桥接输出，不再作为最终真相
3. 新增统一入口：
   `applyEditorTransaction(_:)`
4. 让以下能力改走 transaction：
   format、rename、code action、本地批量编辑、多光标 replacement

建议新增几个中间方法：

1. `loadBuffer(from text: String)`
2. `syncTextStorageFromBuffer()`
3. `applyEditorTransaction(_ transaction: EditorTransaction, reason: String)`
4. `applyTextEdits(_ edits: [TextEdit], source: String)`

#### [SourceEditorView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/SourceEditorView.swift)

第一阶段不改 UI 结构，但要明确角色转变：

1. 它只消费 `NSTextStorage` 和 session state
2. 不直接拥有核心编辑语义
3. 它的 coordinator 输出事件，最终由 `EditorState.applyEditorTransaction` 统一处理

#### [EditorCoordinator.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Editor/EditorCoordinator.swift)

重点不是删功能，而是收口：

1. `didReplaceContentsIn` 不再直接散落触发多个副作用
2. 统一改成：
   收集变更 -> 生成 transaction or delta event -> 交给 state
3. 把“内容变化”和“选区变化”的处理职责拆开

### 第一阶段迁移顺序

1. 先实现 `EditorBuffer`
2. 再加 `applyEditorTransaction`
3. 再把 `formatDocumentWithLSP()` 改走 transaction
4. 再把 `renameSymbolWithLSP()` 改走 transaction
5. 再把本地多选区 replacement 改走 transaction

### 第一阶段风险

1. `NSTextStorage` 和 buffer 双写期间可能产生同步错误
2. selection 映射若不清晰，会让 format/rename 后光标位置不稳定
3. LSP full replace 和本地 transaction 并存期间，版本管理需要谨慎

### 第一阶段验收

满足以下条件才算完成：

1. format 不再直接操纵 text storage 为主
2. rename 不再直接按旧路径分散落地
3. 至少三类编辑行为走同一个 transaction 入口
4. `EditorBuffer` 成为明确存在的文本核心对象

## Phase 2: Selection / Cursor Core

### 目标

解决最影响编码手感的稳定性问题。

### 新增模块建议

继续在 `Kernel/` 目录新增：

1. `Kernel/EditorSelectionSet.swift`
2. `Kernel/EditorCursorState.swift`
3. `Kernel/EditorSelectionMapper.swift`

### 第二阶段重点

把“原生 TextView 的选区”与“内核选区”彻底区分开。

理想关系是：

1. 内核选区是 canonical state
2. 原生选区是渲染/交互镜像

当前代码里最值得优先处理的点：

#### [EditorCoordinator.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Editor/EditorCoordinator.swift)

要减少这些问题：

1. view 先改选区，state 再追
2. state 回写后又覆盖 view
3. 多光标状态与 cursorPositions 之间来回同步

建议目标：

1. 把 view selection 变化先变成 `EditorSelectionSet`
2. state 只接收结构化选区变化
3. 只有当 canonical selection 变化时，才反推回 TextView

#### `MultiCursorCommandsEditorPlugin`

这是第二阶段的重点模块。

建议处理顺序：

1. 保留现有功能，避免回归
2. 增加 transaction-aware 的多光标编辑入口
3. 把 `replaceSelection`、`deleteBackward` 等编辑行为逐步迁移到统一 transaction
4. 降低对 `swizzleInsertText` / `swizzleDeleteBackward` 的结构性依赖

不要求一次删掉 swizzle，但要让 swizzle 逐渐退化为输入路由，而不是编辑引擎本身。

### 第二阶段迁移顺序

1. 在 state 中新增 canonical selection model
2. 增加 TextView <-> SelectionSet 的单向桥接层
3. 重构多光标 replacement
4. 重构多光标 delete
5. 校验 completion、rename、format 后的选区恢复

### 第二阶段风险

1. 键盘输入路径非常敏感，容易出现退格/输入法/撤销回归
2. 多光标行为和 CodeEdit 内部 selectionManager 的交互要小心
3. cursorPosition 与 NSRange 双体系并存时，必须明确谁是源，谁是映射

### 第二阶段验收

1. 多光标下不再出现结构性丢光标问题
2. 普通输入和多光标输入共享统一编辑入口
3. format/rename/completion 后选区恢复更稳定
4. coordinator 不再到处手工纠偏选区

## Phase 3: Session / Tabs Core

### 目标

把当前“单文件编辑器”升级为“有 editor session 概念的编辑器”。

### 新增模块建议

建议新增 `Workbench/` 目录：

1. `Workbench/EditorSession.swift`
2. `Workbench/EditorTab.swift`
3. `Workbench/EditorSessionStore.swift`
4. `Workbench/EditorFindReplaceState.swift`
5. `Workbench/EditorNavigationHistory.swift`

### 第三阶段最重要的思想变化

不要再让：

1. 选中文件
2. 当前视图
3. 当前文本内容

这三件事几乎等价。

要变成：

1. 文件是 document identity
2. session 是打开中的编辑上下文
3. tab 是工作台展示单元
4. active session 才是当前交互目标

### 现有文件改造映射

#### [EditorRootView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/EditorRootView.swift)

这是第三阶段主战场。

建议分两步做：

第一步：

1. 引入 `EditorSessionStore`
2. `selectedFileURL` 不再直接等于“当前编辑器内容”
3. 选中文件时变成“打开或激活对应 session”

第二步：

1. 增加 tab strip
2. 当前中间编辑区域消费 active session
3. 状态栏、toolbar、breadcrumb 都改读 active session

#### [EditorPanelView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/EditorPanelView.swift)

第三阶段可以先不做 split editor，但要提前留出 workbench 容器形态。

建议：

1. 保留左树 + 中间编辑区域布局
2. 中间区域的根节点从单 editor 切到 session container
3. 给未来的 group/split 预留插槽

#### [EditorToolbarView.swift](/Users/colorfy/Code/CofficLab/Lumi/LumiApp/Plugins/AgentEditorPlugin/Views/EditorToolbarView.swift)

后续要逐步从“直接操控 state”转向“针对 active session 执行命令”。

### 第三阶段迁移顺序

1. 新增 `EditorSession`
2. 新增 `EditorSessionStore`
3. 在 `EditorRootView` 中接入 session store
4. 单文件切换改成 open-or-activate session
5. 引入 tab strip
6. 保存每个 session 的 cursor/scroll/find 状态

### 第三阶段风险

1. 现有状态默认假设只有一个 active file
2. 一些面板状态可能当前是全局的，迁移后需要区分 global 和 session-local
3. 自动保存、外部文件刷新、LSP 打开文档的生命周期都要重新看

### 第三阶段验收

1. 同时打开多个文件时，每个文件的编辑上下文独立存在
2. 切换 tab 不会丢光标和查找状态
3. 编辑器入口不再等价于单文件视图

## 推荐的第一批实际提交

为了降低风险，建议第一批代码提交按下面顺序切：

### Commit 1

1. 新增 `Kernel/` 目录
2. 增加 `EditorBuffer`、`EditorSnapshot`、`EditorTransaction`
3. 不接 UI，只加测试和最小 API

### Commit 2

1. `EditorState` 接入 `buffer`
2. 新增 `applyEditorTransaction`
3. format 改走 transaction

### Commit 3

1. rename 改走 transaction
2. code action text edits 改走 transaction

### Commit 4

1. 建立 canonical selection model
2. coordinator 开始收口选区同步职责

### Commit 5

1. 多光标 replacement / delete 迁移到 transaction
2. 回归测试多光标基础行为

### Commit 6

1. 新增 `EditorSession`
2. `EditorRootView` 切 session store
3. 引入基础 tab strip

## 测试建议

内核升级过程中，建议优先补这些测试：

1. `EditorBuffer` 应用单次编辑
2. `EditorBuffer` 应用多个 ranges 编辑
3. transaction 后 selection 映射
4. format 后光标恢复
5. rename 后多文件变更应用
6. 多光标 replace/delete
7. session 切换后恢复 cursor/scroll

如果时间有限，测试优先级顺序建议是：

1. transaction correctness
2. selection stability
3. multi-cursor behavior
4. session restoration

## 这份计划的落地标准

当下面这些变化开始出现，就说明我们真的在向 VS Code 风格内核迁移，而不是只是在继续加功能：

1. `EditorState` 不再不断膨胀
2. `NSTextStorage` 不再是唯一文本真相来源
3. 编辑行为有统一 transaction 入口
4. 选区状态不再依赖大量手工同步
5. 编辑器开始拥有 session 概念

## 下一步建议

如果继续推进，最合理的下一步不是再写更多规划文档，而是直接开始 Phase 1 的结构落地：

1. 创建 `Kernel/EditorBuffer.swift`
2. 创建 `Kernel/EditorTransaction.swift`
3. 在 `EditorState.swift` 中接入最小 buffer
4. 先把 format 流程迁移过去

这会是第一块真正可验证、可迭代、并且能把架构往正确方向推的代码。
