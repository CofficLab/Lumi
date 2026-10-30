# PluginConversationList

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationList`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

<!-- TODO: 描述本包提供的功能 -->

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationList"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationList"]),
]
```

## Testing

From this package directory:

```sh
swift test
```


## 能力边界

ViewModel 与 Agent 工具对外的依赖分两类：

**ViewModel → `ConversationListContext`（插件自有聚合类型）**
工具栏、Rail、Popover 的 ViewModel 全部只面向 `ConversationListContext` 编程，由它统一扇出
项目 / 回合 / 会话状态 / 聊天区可见性，并提供自己的 `Event` 与 `ObserverHandle`。
这是插件内部的聚合层，不涉及内核 Provider。

**Tool → `ConversationListQueryCapability`（收窄内核 Provider）**
`GetRecentConversationsTool` 原本直接持有 `ConversationManaging` 与 `ProjectProviding`，
现改为只依赖三个查询操作：

- `fetchRecentConversations(limit:)`
- `conversationCount(projectPath:)`
- `currentProjectPath`

Adapter 在插件入口构造并注入，Tool 不再 import `ProviderProject`。
