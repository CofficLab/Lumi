# PluginConversationNew

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationNew`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

「开新对话」的统一入口，提供两条互补路径：

| 触发方 | 入口 | 行为 |
| --- | --- | --- |
| 用户 | 工具栏「新建会话」按钮 | 取消当前选中态，对话面板回到空态 |
| LLM | `create_new_conversation` 工具 | 创建对话 + 建议卡片，用户点击后自动开始 |

### LLM 建议换个话题

当 LLM 在当前话题进行中发现了一件**与当前话题实质不同**的新任务时，可以调用
`create_new_conversation` 工具，在消息列表里生成一张建议卡片。用户点击卡片上的
「在新对话中开始」按钮后，应用会切到新对话、自动发送首条消息并自动开始回合。

这样做的目的有两个：

1. **语义隔离**：新任务不再把无关历史带进上下文，后续检索与裁剪更准确；
2. **注意力隔离**：用户不必在一个越聊越长的对话里切换心智模型。

### 设计约束：回合内只「备料」，不在回合内切换

工具在回合执行中被调用时**只做记账**——创建对话、写标题、把首条消息内容返回给
LLM，**绝不修改 `selectedConversationID`**。真正的切换与发送发生在回合结束之后、
由用户点击卡片按钮触发。

这样设计的原因：

- `createConversation` 对顶层对话会直接 `selectedConversationID = id` 并自动选中。
  若在回合内直接调用，用户正在输入的内容会被甩进一个空对话；因此工具必须在同一次
  调用内把选中态恢复回原对话。
- `ToolExecutionContext` 明确要求工具不依赖 UI 选中态（见
  `conversationProjectPath()` 的注释），回合内切换选中态属于架构上应避免的行为。
- 回合内触发 `sender.sendMessage` 会嵌套启动新回合，`currentTasks` /
  `pendingTurnStarts` / `isRunning` 的状态机需要额外处理，风险高。改为由 UI 点击
  触发后，回合边界清晰，零嵌套风险。

### 为什么用顶层对话而不是子对话

`createConversation` 支持 `parentConversationID`，但子对话不会进入侧边栏列表
（`fetchConversationPage(includingChildConversations: false)` 会过滤掉），用户点击后
也找不到它。因此这里显式传 `parentConversationID: nil` 创建**顶层**对话，代价是要
自己恢复被抢占的选中态。

### 上下文传递

工具接受一个 `task` 参数（LLM 用完整句子描述新话题要做什么），它同时用作：

- 新对话的标题（缺省时取首句推导，上限 48 字符）；
- 卡片上展示的任务描述；
- 用户点击后自动发送的首条消息。

不自动生成摘要：摘要是有损操作，且此处 LLM 已经在写 `task`，让 LLM 自己把该带的
上下文写进 `task` 比二次摘要更准确、成本更低。若任务确实依赖当前对话的结论，
LLM 应把必要结论直接写进 `task`。

### 结构化载荷

工具返回内容由两部分组成（与 `PluginGit` 的 `git_log` 同一模式）：

1. 人类可读的 Markdown 正文，供 LLM 直接理解；
2. 末尾 ```json 代码块，内容为 `{ conversationID, title, starter }`，供
   `NewConversationRowRenderer` 解码为卡片。

渲染器解析失败会静默回退到默认工具文本视图，不丢信息。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationNew"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationNew"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
