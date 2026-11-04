# PluginConversationInput

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginConversationInput`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

聊天输入框与它上方的附件预览区。

### 拖放

**两个落点，一套规则**：

| 落点 | 实现 | 说明 |
|------|------|------|
| 输入框 | AppKit `NSTextView.performDragOperation` | 从 `NSPasteboard` 读 `NSURL` / `NSString` |
| 附件预览区 | SwiftUI `.onDrop` | 从 `NSItemProvider` 读数据表示，只接受 `.fileURL` |

两处走的是**两套拖放 API**，但分流规则必须一致，因此规则收敛在
`ConversationInputViewModel.attach(droppedURL:)` 一处：

| 拖入内容 | 落点 |
|---------|------|
| 目录 | 路径插入输入框文本 |
| 图片 | 图片附件池 |
| 其他文件 | 文件附件池 |

`DroppedItemResolver` 负责把 `NSItemProvider` 还原成本地文件 URL，
处理两种常见表示：`public.file-url`（Finder 拖文件）与纯文本
（编辑器里选中的路径，含 `NSKeyedArchiver` 归档过的形式）。

- Note: `NSItemProvider` 不是 `Sendable`，不能捕获进 `Task`；解析因此走
  回调式 API，在主线程交付结果。

- Note: 预览区的 `.onDrop` 只能声明 `.fileURL`。SwiftUI 会按声明的类型给
  `NSItemProvider` 降级并丢弃其余表示——声明含 `.image` 时，拖入 PNG 会降级成
  `public.png`，`public.file-url` 随之丢失，拖放随即静默失败。纯文本路径请
  拖到输入框，那条路直接读 `NSPasteboard`，不受降级影响。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginConversationInput"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationInput"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

