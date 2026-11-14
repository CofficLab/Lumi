# KitMessageList

消息列表插件（Brief / Standard / Detailed / ZCode / ChatGPT / StandardNoHeader）共享的设施。

## Package

- Products: `KitMessageList`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 结构

- **Capabilities/**：把 Provider 收窄为消息列表所需的最小能力协议，以及对应适配器
- **Models/**：`MessageListServices` 服务容器、`LumiTurnActivity`、`Message` 展示层扩展
- **Services/**：首屏定位门、分页服务、尾部刷新门、turn 活动构建、底部判定
- **Observers/ ViewModels/**：开发者模式状态观察与共享状态
- **Views/**：底部状态盒、列表行样式、macOS live-resize 冻结视图
- **VerbosityObservationBox**：按详细度注册 `ChatSectionItem`（`order` 由插件入口传入）

## 边界

只放**行为一致**的代码。各档明确保留在本地的部分：

- Brief / ChatGPT 的分页服务（回收与 tail 合并语义不同）
- 各档的行构建器、滚动栈与滚动锚点（实现代次不同）
- Brief 的开发者模式观察器（直接写入自己的会话 VM）
- 空态插件（`PluginMessageListEmpty`）不依赖本包

## 依赖与集成

```swift
dependencies: [
    .package(path: "../KitMessageList"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "KitMessageList", package: "KitMessageList"),
    ]),
]
```

## Testing

```sh
swift build --package-path Packages/KitMessageList
```

共享类型的测试随各插件包一起运行（`swift test --package-path Packages/PluginMessageListStandard`）。
