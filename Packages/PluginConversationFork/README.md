# PluginConversationFork

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationFork`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

Chat 分区 Action Bar 上的「续接到新对话」入口：把当前对话浓缩成一段摘要，
落到一个新对话并自动续写。

- **引导式确认**：点击按钮只弹出引导弹窗，先把将被带走的上下文（对话标题、
  消息条数、提问轮数、模型、最后一条提问）摊开给用户看，确认后才真正分叉；
  误触不会凭空多出一个对话。
- **摘要**：优先用当前对话的模型生成历史摘要，失败时回退为本地精简摘要，
  保证不会卡死。
- **透传**：新对话继承源对话的标题、项目路径与模型。
- **锁定源对话**：弹窗锁定打开时的对话 ID，用户确认时看到的与实际分叉的
  始终是同一份上下文。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationFork"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationFork"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

