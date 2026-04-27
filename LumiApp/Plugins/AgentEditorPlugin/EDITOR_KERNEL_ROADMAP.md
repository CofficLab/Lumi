# Editor Kernel Roadmap

## 目标

目标不是简单做一个“带很多功能的原生编辑器”，而是用 Swift 把 VS Code 的核心编辑体验尽量复刻出来，并且把重心放在编辑器内核升级上。

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

“以原生文本视图为中心，再逐步挂更多能力”

而不是：

“以编辑器模型为中心，视图、语言服务、工作台状态都围绕它组织”

如果目标是向 VS Code 看齐，核心不是继续平铺功能，而是调整内核抽象。

## 对齐 VS Code 的设计原则

### 1. Model First

核心状态不能继续主要围绕“当前展示的文件”和“当前 TextView”组织。

要逐步切换成以下模型：

1. `EditorDocument`
2. `EditorBuffer`
3. `WorkingCopy`
4. `EditorSession`
5. `EditorGroup`
6. `EditorWorkbenchState`

它们的职责建议如下：

1. `EditorDocument`
   表示文档身份，比如 URL、语言、编码、元信息。

2. `EditorBuffer`
   表示真正的文本内容与版本号，是编辑真相来源。

3. `WorkingCopy`
   表示 dirty 状态、保存状态、外部修改冲突、恢复状态。

4. `EditorSession`
   表示某个已打开编辑器实例的状态，比如光标、选区、滚动、折叠、查找状态。

5. `EditorGroup`
   表示一个分栏中的 tab 集合和当前活跃 session。

6. `EditorWorkbenchState`
   表示整个编辑工作台的布局、活跃 group、导航历史、预览 tab 等。

### 2. Transaction First

所有编辑行为都应该走统一事务管线，而不是分散在：

1. TextView 输入回调
2. coordinator 同步逻辑
3. 多光标 helper
4. LSP 编辑应用逻辑

理想链路应该是：

`EditorTransaction -> apply to buffer -> update selections -> push undo stack -> notify language pipelines -> refresh visible UI`

这条链路应该覆盖：

1. 普通输入
2. 粘贴
3. 删除
4. 多光标批量编辑
5. format document
6. rename symbol
7. code action 修改
8. replace all

### 3. Session and Workbench First

VS Code 的核心体验不只是“编辑一个文件”，而是：

1. 多 tab
2. 预览 tab / 固定 tab
3. split editor
4. editor groups
5. navigation history
6. reopen closed editor
7. dirty tabs

所以当前以单个选中文件驱动的方式，需要逐步让位给 session/workbench 驱动。

### 4. Async Language Pipelines

语言能力不应该只是“能请求到结果”，而是要稳定。

每个异步语言功能都要有：

1. 文档版本感知
2. 请求代际
3. stale response 丢弃
4. cancellation
5. viewport/cursor 敏感刷新

覆盖范围包括：

1. completion
2. hover
3. diagnostics
4. code actions
5. semantic tokens
6. inlay hints
7. references
8. rename

### 5. Performance Is Part of the Kernel

性能不是后期补丁，而是内核设计的一部分。

需要尽早纳入内核设计的点：

1. 大文件模式
2. 长行保护
3. 增量高亮
4. viewport 限界更新
5. overlay 更新限流
6. 主线程最小化压力

## 目标架构

### Layer 1: Text Core

新增核心文本层：

1. `EditorBuffer`
2. `EditorSnapshot`
3. `EditorRange`
4. `EditorSelection`
5. `EditorTransaction`
6. `EditorUndoManager`

职责：

1. 存储 canonical text
2. 应用编辑事务
3. 管理版本号
4. 输出不可变快照
5. 驱动 undo/redo

注意：
`NSTextStorage` 和 `CodeEditSourceEditor` 应逐步退化为“适配器层”，而不再是最终真相来源。

### Layer 2: Session Core

新增会话层：

1. `EditorSession`
2. `EditorTab`
3. `EditorFindReplaceState`
4. `EditorDecorationState`
5. `EditorNavigationHistory`

职责：

1. 保存每个打开文件的独立编辑状态
2. 在切 tab 后恢复上下文
3. 承载查找、高亮、折叠、scroll、selection 等局部状态

### Layer 3: Workbench Core

新增工作台层：

1. `EditorGroup`
2. `EditorWorkbenchState`
3. `EditorCommandContext`

职责：

1. 管理 tab groups
2. 管理 split editor
3. 管理 active editor / active group
4. 管理命令启用状态

### Layer 4: Language Core

新增语言特性协调层：

1. `CompletionPipeline`
2. `HoverPipeline`
3. `DiagnosticsPipeline`
4. `CodeActionPipeline`
5. `SemanticTokensPipeline`
6. `InlayHintPipeline`

职责：

1. 与 buffer snapshot 对齐
2. 管理 cancellation
3. 拒绝过期结果
4. 做局部刷新

### Layer 5: Native Rendering Bridge

保留并重构原生桥接层：

1. `SourceEditorAdapter`
2. `TextViewBridge`
3. `OverlayLayoutSystem`
4. `EditorInputRouter`

职责：

1. 把核心模型映射到 `CodeEditSourceEditor`
2. 把原生事件转换为编辑事务
3. 统一 overlay 定位与刷新

## 分阶段计划

## Phase 0: 立规则与测基线

目标：
在大改之前先把规则定清楚。

任务：

1. 明确“谁是文本真相来源”
2. 定义今后的编辑行为必须向 transaction 模型收敛
3. 列出现存内核问题清单
4. 增加性能基线指标

建议关注的指标：

1. 打开文件耗时
2. 打字延迟
3. completion 延迟
4. hover 延迟
5. rename 延迟
6. 大文件打开表现

验收：

1. 后续改造有统一约束
2. 可以量化回归

## Phase 1: 引入 Buffer 与 Transaction Core

目标：
在不立刻推翻 UI 的前提下，建立新的核心文本模型。

任务：

1. 新增 `EditorBuffer`
2. 新增 `EditorTransaction`
3. 新增 `EditorSnapshot`
4. 给现有 `NSTextStorage` 加一个 buffer adapter
5. 让 format / rename / code action / multi-cursor 优先走 transaction

验收：

1. 文本修改路径开始统一
2. 事务成为编辑行为入口
3. undo/redo 未来有统一挂载点

## Phase 2: 重建 Selection 与 Cursor 语义

目标：
把最影响“手感”的部分先稳定下来。

任务：

1. 建立 canonical `EditorSelection`
2. 把 primary / secondary cursor 语义收敛到 session
3. 减少 view 和 state 之间反复双向纠偏
4. 重构多光标实现，尽量从 swizzle 驱动迁移到事务驱动
5. 单独验证输入法和 composition 行为

验收：

1. 多光标不再结构性脆弱
2. 选区不会频繁丢失或回滚
3. 输入、补全、跳转、撤销对光标状态的影响一致

## Phase 3: 引入 Editor Session 与 Tabs

目标：
不再让当前编辑器围绕单文件工作。

任务：

1. 新增 `EditorSession`
2. 新增 `EditorTab`
3. 保存每个 session 的：
   光标、滚动、折叠、查找、dirty 状态
4. 区分 preview tab 和 pinned tab
5. 让 `EditorRootView` 从 `selectedFileURL` 驱动转向 session 驱动

验收：

1. tab 切换不会丢上下文
2. 同一文件可拥有稳定的编辑状态载体
3. dirty 状态成为 tab/session 级别概念

## Phase 4: 引入 Editor Groups 与 Workbench State

目标：
开始具备 VS Code 式工作台能力。

任务：

1. 新增 `EditorGroup`
2. 新增 `EditorWorkbenchState`
3. 支持 split editor
4. 支持 group-local tabs
5. 支持 editor navigation history
6. 支持 command context keys

验收：

1. 支持多编辑分栏而不是单编辑区
2. command 能感知当前 workbench 上下文

## Phase 5: 统一 Command 与 Keybinding 系统

目标：
编辑器行为从 UI 触发转向 command 驱动。

任务：

1. 建立 central command registry
2. 建立 context-based enablement
3. 让 toolbar / menu / context menu / shortcut / command palette 全部走同一 command id
4. 统一这些命令：

1. find
2. replace
3. rename
4. format
5. go to definition
6. add next occurrence
7. add cursor above / below
8. toggle comment
9. duplicate line
10. move line

验收：

1. 行为入口统一
2. 键位系统开始可维护
3. UI 不再各自持有业务逻辑

## Phase 6: 加固 Language Pipelines

目标：
让语言智能在真实编码压力下依然稳定。

任务：

1. completion / hover / diagnostics / code actions 引入 request generation
2. 引入 stale result 丢弃
3. 引入 cancellation
4. 对 viewport / current cursor 做敏感更新
5. 把 transport concerns 和 presentation concerns 分离

验收：

1. 快速输入时不会被旧结果污染
2. 语言能力更加平滑
3. plugin/contributor 增多后仍可扩展

## Phase 7: 重做 Find / Replace Core

目标：
补上最重要的日常编码能力之一。

任务：

1. 建立 `EditorFindReplaceState`
2. 支持：
   regex、case-sensitive、whole-word、in-selection、replace one、replace all、preserve case
3. 与 selection / multi-cursor 联动
4. per-session 保存查找状态

验收：

1. 查找替换成为内核能力，不只是 UI 功能
2. 切 tab 和 split 后依旧一致

## Phase 8: Performance 与 Large File 工程化

目标：
缩小与 VS Code 的压力表现差距。

任务：

1. 评估 `NSTextStorage` 是否能继续充当长期文本底层
2. 如有必要，引入更可扩展的文本存储抽象
3. 增加 large-file mode，而不仅是只读/截断
4. 增加 long-line safeguards
5. 把高亮、overlay、hint、semantic token 更新限制在 viewport
6. 给主线程和内存热点做持续埋点

验收：

1. 大文件场景可用
2. 渲染成本更多跟 viewport 绑定，而不是全量文档

## Phase 9: 编辑体验打磨

目标：
把“可用”提升到“熟悉、顺手、像 VS Code”。

任务：

1. 打磨 cursor motion 语义
2. 打磨 bracket pair 与缩进行为
3. 增加 line editing commands
4. 增加 auto closing / surrounding pairs
5. 增加 save participants：
   format on save、code action on save、trim trailing whitespace、insert final newline
6. 完善外部文件修改冲突处理

验收：

1. 高频编辑动作连贯
2. 用户逐渐感受不到“这是一套自定义编辑器行为”

## 优先级建议

如果目标是最快拉近和 VS Code 的核心体验差距，建议优先顺序如下：

1. Phase 1: Buffer / Transaction Core
2. Phase 2: Selection / Cursor Core
3. Phase 3: Sessions / Tabs
4. Phase 5: Commands / Keybindings
5. Phase 6: Language Pipelines
6. Phase 7: Find / Replace
7. Phase 4: Workbench Groups
8. Phase 8: Performance / Large Files
9. Phase 9: Polish

说明：
`Phase 4` 很重要，但不建议早于 buffer 和 selection 稳定化，否则容易在不稳的底层上叠工作台复杂度。

## 与当前代码的直接映射

第一波改造建议优先落在这些地方：

1. `Store/EditorState.swift`
   现在职责过重，后续应拆为 document/session/workbench 多层。

2. `Views/EditorRootView.swift`
   现在明显偏单文件驱动，后续要改成 session/workbench 驱动。

3. `Views/SourceEditorView.swift`
   应逐步从“中心”退化成“渲染适配器”。

4. `Editor/EditorCoordinator.swift`
   应从同步胶水层，逐步变成 transaction routing 层。

5. `Plugins-Editor/MultiCursorCommandsEditorPlugin/*`
   现有行为过度依赖原生事件截获，适合作为 transaction 化改造重点。

6. `Plugins-Editor/LSPServiceEditorPlugin/*`
   适合作为 request generation / stale rejection / cancellation 的第一批升级点。

## 成功标准

这个计划成功的标志不是“功能数量接近 VS Code”，而是：

1. 文本真相不再主要由原生 TextView 持有
2. 编辑行为以事务为中心
3. tab / split / navigation 成为正式模型
4. 异步语言能力版本安全
5. 大文件和高频编辑场景下依然可用
6. 重度 VS Code 用户进入后不会频繁撞到结构性粗糙感

## 最终结论

我们真正要做的，不是：

“让当前编辑器看起来更像 VS Code”

而是：

“把当前编辑器升级成一个 Swift 原生、但在设计哲学上与 VS Code 对齐的编辑器内核”

只要这一点成立，后续的 UI、交互和高级能力都会更容易自然长出来。
