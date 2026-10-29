# PluginMessageRenderer

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginMessageRenderer`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

核心消息渲染器：把一条 `Message` 渲染成对应的 SwiftUI 视图。

- 12 个内置渲染器（用户 / 助手 / 系统 / 错误 / 状态 / 工具消息、
  turn-completed、上下文压缩、重试、Goal 续跑、工具步骤组、兜底 Markdown）
- 工具调用行：默认卡片行 + 自定义渲染器扩展点（`ToolCallRowRenderer`）
- **多工具调用折叠为一行摘要**，点击后在 popover 中逐条展开

### 工具调用折叠（仅 V2）

一条助手消息里含**多个连续工具调用**时，**V2（standard）** 把它们合并成一行摘要
（「执行了 N 个步骤 · 耗时」），点击展开按钮后在 popover 里逐条展示。

判定逻辑集中在 `Helpers/ToolCallGroupCollapsePolicy.swift`（纯函数，有单测）：

| 情况 | 行为 |
| --- | --- |
| 单个工具调用 | **不折叠**，逐条铺开（折叠给单个调用平白加一层间接） |
| 多个工具调用（V2） | 折叠成一行摘要 |
| 组内有**等待用户**的调用 | **强制不折叠** |

「等待用户」的判定与授权卡片渲染器同源：`authorizationState == .pendingAuthorization`
或 `result?.awaitingUserResponse == true`。这类调用会渲染成需要用户点击的
交互卡片（授权 / ask_user / 系统权限），藏进 popover 会让回合永远等下去——
因此宁可多占一行，也不能让它看不见。

> **只有 V2 折叠**：V1（brief）与 V3（detailed）都保持逐条铺开。
>
> - **V1**：`ToolCallRowsView` 的 `verbosity == .brief` 分支走
>   `CollapsibleToolStepGroup`，仍逐条铺开。
> - **V3**：detailed 的定位就是「展示更多细节」，折叠与该定位相悖。
>
> 折叠判定必须用**原始**回复级别（`AssistantMessageView` 的 `originalVerbosity`），
> 不能用 `contentVerbosity`——后者把 brief 升格成 standard，用它判断会把 V1
> 连坐成 V2 一并折叠。

### 无障碍标识符

| 标识符 | 位置 |
| --- | --- |
| `lumi.tool-call-group.summary` | 折叠态摘要行 |
| `lumi.tool-call-group.expand` | 展开按钮 |
| `lumi.tool-call-group.popover` | 展开后的 popover 容器 |

> 摘要行与 popover 容器都显式 `accessibilityElement(children: .contain)`：
> 否则 SwiftUI 会把 identifier 传播给每个后代，按 identifier 查询会一次命中
> 多个元素，UI 测试无法用它判断「折叠了几组」。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginMessageRenderer"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginMessageRenderer"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

