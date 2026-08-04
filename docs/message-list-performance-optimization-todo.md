# MessageList 历史消息性能优化 TODO

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 改善 Lumi 在浏览历史消息时的滚动流畅度，同时保持流式聊天、分页、工具调用和 Markdown 展示功能不回退。

**Architecture:** 先建立静态历史消息的性能基线，再将消息列表与流式尾部更新解耦。历史消息使用虚拟化列表和预计算的轻量渲染模型；Markdown、代码高亮、Mermaid 和工具详情采用缓存或按需渲染。每项优化独立验证，避免一次性大改导致性能问题难以定位。

**Tech Stack:** SwiftUI、macOS AppKit、Swift Concurrency、Swift Package Manager、Instruments。

---

## 问题现状

当前对话列表使用 `LazyVStack`，每行只有标题、模型和时间；消息列表使用普通 `VStack`，会让当前消息窗口中的所有行同时参与布局。

消息行还可能包含：

- Markdown block 和 inline 解析；
- `fixedSize`、文本选择和复杂的 intrinsic height 计算；
- 代码语法高亮和横向滚动容器；
- Mermaid 图片渲染；
- 工具调用分组、工具结果和多个交互控件；
- `GeometryReader`/`PreferenceKey` 底部位置检测。

因此，即使没有正在聊天，历史消息滚动仍可能触发大量主线程布局和文本渲染工作。

## 关键代码位置

- `Plugins/MessageListPlugin/Sources/Views/MessageListView.swift`
- `Plugins/MessageListPlugin/Sources/ViewModels/MessageListViewModel.swift`
- `Plugins/MessageListPlugin/Sources/Services/MessageListPaginationService.swift`
- `Plugins/ConversationListPlugin/Sources/Views/ListView.swift`
- `Plugins/MessageRendererPlugin/Sources/Views/MessageRowView.swift`
- `Plugins/MessageRendererPlugin/Sources/Renderers/AssistantMessageView.swift`
- `Packages/MarkdownKit/Views/MarkdownBlockRenderer.swift`
- `Packages/MarkdownKit/Views/HighlightedCodeView.swift`
- `Packages/MarkdownKit/Mermaid/MermaidDiagramView.swift`

## 验收指标

每项优化完成后，至少记录以下指标：

- 历史消息滚动时主线程帧率/卡顿情况；
- Time Profiler 中主线程热点函数；
- 首次打开对话的首屏耗时；
- 消息列表初始内存和滚动后的峰值内存；
- 代码块、表格、Mermaid、工具调用的展示正确性。

建议使用同一份压力数据进行对比：40 条首屏消息、300 条历史消息、长 Markdown、代码块、工具调用和至少一张 Mermaid 图。

---

## P0：建立性能基线和可重复测试数据

**目的：** 在改代码前确认卡顿主要来自列表布局、Markdown、文本选择还是复杂内容异步渲染。

**Files:**

- Inspect: `Plugins/MessageListPlugin/Sources/Views/MessageListView.swift`
- Inspect: `Packages/MarkdownKit/Views/MarkdownBlockRenderer.swift`
- Inspect: `Plugins/MessageRendererPlugin/Sources/Renderers/AssistantMessageView.swift`
- Optional Create: `docs/message-list-performance-baseline.md`

**Tasks:**

1. 使用 Instruments Time Profiler 记录静态历史消息滚动。
2. 分别测试纯文本消息、Markdown 消息、代码块消息、工具调用消息和 Mermaid 消息。
3. 记录首屏加载时间、滚动期间主线程热点和内存峰值。
4. 为每种场景记录“优化前”结果。

**验证：** 能够明确指出前两名主线程热点，并能用同一数据在优化后复测。

---

## P1：静态历史消息启用虚拟化列表

**目的：** 不让所有历史消息同时创建和布局。

**Files:**

- Modify: `Plugins/MessageListPlugin/Sources/Views/MessageListView.swift`
- Modify: `Plugins/MessageListPlugin/Sources/ViewModels/MessageListViewModel.swift`（如需区分静态/流式状态）
- Test: `Plugins/MessageListPlugin/Tests/MessageListPluginTests/`

**方案：**

1. 历史消息使用 `LazyVStack`。
2. 流式消息不要让整个 `displayRows` 每个 token 都重建；将流式尾部行拆成独立视图。
3. 静态历史和流式输出使用不同的更新路径：历史行保持稳定，只有尾部流式行高频更新。
4. 保留 `ForEach` 的稳定消息 ID，避免不必要的 `.id(message.id)` 重置视图身份。

**注意：** 不能只把 `VStack` 机械替换成 `LazyVStack` 后结束，需要验证向上分页、滚动锚点和流式输出是否正常。

**验收：**

- 静态历史滚动明显比当前版本流畅；
- 首屏只创建可视区域附近的消息行；
- 向上加载历史后锚点位置不跳动；
- 流式输出不会出现布局活锁、自动滚动失效或消息串台。

---

## P1：消除 Markdown 的重复解析和主线程解析

**目的：** 避免在 SwiftUI View 初始化和 body 计算期间重复解析 Markdown。

**Files:**

- Modify: `Packages/MarkdownKit/Views/MarkdownBlockRenderer.swift`
- Modify: `Packages/MarkdownKit/Views/MarkdownInlineParser.swift`
- Modify: `Packages/MarkdownKit/Parsers/MarkdownParser.swift`（如需增加 Sendable 预计算接口）
- Test: `Packages/MarkdownKit/Tests/MarkdownKitTests/`

**当前问题：** `MarkdownBlockRenderer.init` 同步执行 `MarkdownParser.parse`，随后 `.task(id:)` 又访问异步缓存；每个 inline 文本也可能在 body 重算时重复解析。

**方案：**

1. 将 Markdown block 解析从 View 初始化中移出。
2. 按 `contentHash + parserVersion` 缓存解析结果。
3. 在消息加载后使用后台任务预计算 Markdown render model。
4. 对 inline Markdown 结果增加缓存，避免重复执行 `AttributedString` 解析。
5. 让 View 只负责展示已经准备好的 render model。

**验收：**

- 同一消息不会在打开和滚动过程中重复解析；
- Markdown、表格、列表、引用、代码块渲染结果不变；
- 主线程 Time Profiler 中 `MarkdownParser.parse` 和 inline parser 占比显著下降。

---

## P1：复杂内容按需渲染

**目的：** 避免打开历史时同时启动大量代码高亮、Mermaid 和工具结果任务。

**Files:**

- Modify: `Packages/MarkdownKit/Views/HighlightedCodeView.swift`
- Modify: `Packages/MarkdownKit/Mermaid/MermaidDiagramView.swift`
- Modify: `Plugins/MessageRendererPlugin/Sources/Views/CollapsibleToolStepGroup.swift`
- Modify: `Plugins/MessageRendererPlugin/Sources/Views/AssistantToolCallViews.swift`

**方案：**

1. 代码高亮只对接近可视区域的代码块执行。
2. Mermaid 默认显示轻量占位卡片，用户点击后渲染图像。
3. 长代码块默认折叠，只显示摘要和行数。
4. 工具结果保持懒加载，历史消息默认不自动展开工具详情。
5. 限制并发高亮和图表渲染任务数量。
6. 缓存 key 使用稳定的消息/块 ID 加内容 hash，并限制缓存大小。

**验收：**

- 打开历史时不会同时启动所有复杂内容任务；
- 代码块和 Mermaid 仍可按需正常显示；
- 工具折叠/展开状态和结果加载不回退。

---

## P2：降低单条消息的布局成本

**目的：** 减少每条消息的 SwiftUI layout tree 和原生文本选择成本。

**Files:**

- Modify: `Plugins/MessageRendererPlugin/Sources/Renderers/AssistantMessageView.swift`
- Modify: `Plugins/MessageRendererPlugin/Sources/Renderers/UserMessageView.swift`
- Modify: `Plugins/MessageRendererPlugin/Sources/Views/MessageViewChrome.swift`
- Modify: `Plugins/MessageRendererPlugin/Sources/Components/CollapsiblePlainText.swift`

**方案：**

1. 评估并移除不必要的 `.fixedSize(horizontal: false, vertical: true)`。
2. 历史模式减少默认启用 `.textSelection(.enabled)` 的消息数量。
3. 将复制操作保留在复制按钮或详情视图中，避免每个文本节点都创建选择能力。
4. 简化历史模式的消息头部，减少常驻按钮、popover 和 metadata 视图。
5. 对消息行使用基于 `LumiChatMessage: Equatable` 的稳定包装，避免内容未变时重复刷新。

**验收：**

- 普通文本历史消息的布局耗时下降；
- 复制、重新发送、查看消息信息等交互仍可用；
- 长消息换行和高度计算正确。

---

## P2：减少滚动期间的 SwiftUI 状态传播

**目的：** 避免静态滚动时不必要的 Geometry 和环境状态更新。

**Files:**

- Modify: `Plugins/MessageListPlugin/Sources/Views/MessageListView.swift`
- Modify: `Plugins/MessageListPlugin/Sources/Services/MessageListScrollCoordinator.swift`

**方案：**

1. 仅在存在流式输出时启用“是否位于底部”的持续检测。
2. 静态历史浏览时不执行自动滚底逻辑。
3. 评估使用 AppKit `NSScrollView` delegate 替代 `GeometryReader + PreferenceKey`。
4. 将滚动状态与消息行的渲染状态隔离，避免滚动状态传播到整棵消息树。

**验收：** 静态历史滚动时 Geometry/Preference 相关函数不再成为明显热点，分页和自动滚动行为正常。

---

## P3：内存窗口和历史分页优化

**目的：** 在长对话下控制布局对象、消息对象和渲染缓存的总量。

**Files:**

- Modify: `Plugins/MessageListPlugin/Sources/Services/MessageListPaginationService.swift`
- Modify: `Plugins/MessageListPlugin/Sources/ViewModels/MessageListViewModel.swift`

**方案：**

1. 根据静态/流式模式分别设置消息窗口大小。
2. 回收消息时同步清理对应的预计算 render model 和复杂内容缓存。
3. 确保过期分页任务不会长期持有大消息数组。
4. 记录当前内存窗口数量、消息总字符数、代码块数量和 Mermaid 数量，便于诊断。

**验收：** 长对话反复上下滚动时，内存不会持续单调增长；历史分页数据仍然正确。

---

## 推荐实施顺序

```text
P0 性能基线
  ↓
P1 静态 LazyVStack / 流式尾部拆分
  ↓
P1 Markdown 预解析和缓存
  ↓
P1 代码块、Mermaid、工具结果按需渲染
  ↓
P2 降低单条消息布局成本
  ↓
P2 优化 Geometry/Preference 滚动状态
  ↓
P3 长对话内存窗口和缓存回收
```

## 每次优化的工作方式

每完成一个 TODO，按以下顺序执行：

1. 先记录当前行为和性能基线；
2. 只修改一个明确的性能因素；
3. 运行相关单元测试；
4. 使用同一份压力数据复测；
5. 检查静态历史、向上分页、流式输出和复杂内容；
6. 在本文档标记完成，并记录实际收益和副作用。

## 当前状态

- [ ] P0 建立性能基线
- [x] P1 静态历史消息启用虚拟化列表（历史使用 `LazyVStack`，流式尾部独立渲染）
- [x] P1 流式尾部与历史列表解耦（独立尾部视图、会话隔离、约 16ms 帧级合并）
- [x] P1 消除 Markdown 重复解析（block 解析使用有上限同步缓存，inline 解析使用有上限异步缓存；保留首帧高度稳定）
- [ ] P1 复杂内容按需渲染
- [ ] P2 降低单条消息布局成本
- [ ] P2 减少滚动期间的 SwiftUI 状态传播
- [ ] P3 内存窗口和历史分页优化
