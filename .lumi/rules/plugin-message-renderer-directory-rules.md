# 插件消息渲染器目录规范

> 本规范定义 Lumi 项目中**插件提供的消息渲染器**代码的归属目录、命名与注册方式。
> 目的：让「这个插件画了一条什么消息」在一处可查，避免渲染器散落在 `Views/`、
> `Views/Components/`、插件入口文件里而无人找得到。

---

## 核心原则

**插件贡献的渲染器实现，一律放在插件包的 `Renderers/` 目录。**

`Renderers/` 与 `Views/`、`Models/`、`Services/` 平级，是渲染器的**唯一归属目录**。

---

## 1. 什么算「渲染器代码」

Lumi 有两套并行的渲染器机制，**两者都受本规范约束**：

| 机制 | 协议 | 粒度 | 注册入口 |
|------|------|------|----------|
| 消息级渲染器 | `MessageRendererItem` | 接管**整条消息** | `MessageRenderingProviding.register(_:)` |
| 工具调用行渲染器 | `ToolCallRowRenderer` | 替换 assistant 消息内的**单个 ToolCall 行** | `ToolCallRenderingProviding.register(_:)` |

判定标准（**窄口径**）：类型满足下列任一条，即为渲染器，**必须**放进 `Renderers/`：

1. 构造或工厂方法返回 `MessageRendererItem`；
2. 声明遵循 `ToolCallRowRenderer` 协议；
3. 类型名以 `Renderer` 结尾**且**其职责是把消息/工具调用变成视图。

### 不算渲染器（留在原处）

| 类型 | 归属 | 原因 |
|------|------|------|
| 卡片**视图**本身（`FinderCardView`、`DeviceStatusCardView`） | `Views/` | 它是视图，不是渲染器；被渲染器引用 |
| 渲染器的**载荷模型**（`FinderTimeline`、`DeviceStatusTimeline`） | `Models/` | 它是数据，不是渲染器 |
| 渲染器用到的**服务**（`FinderOpener`、`DiskSpeedTester`） | `Services/` | 它是业务逻辑 |
| 菜单栏图表渲染器（`CPUMenuBarChartRenderer`） | `Support/` | 它渲染的是**菜单栏图表**，不是消息 |

> 第 4 行是个真实存在的歧义点：`Renderer` 后缀不等于消息渲染器。
> 判定看**渲染对象**——渲染消息/工具调用行的才是消息渲染器。

---

## 2. 目录位置

| 包结构 | 位置 |
|--------|------|
| 有包裹目录（`Sources/<PackageName>/`，Lumi 多数插件包） | `Sources/<PackageName>/Renderers/` |
| 无包裹目录（`path: "."` + `sources: ["Sources"]`） | `Sources/Renderers/` |

目录与 `Views/`、`Models/`、`Services/`、`ViewModels/` 平级。

```
Packages/PluginFinder/
└── Sources/PluginFinder/
    ├── FinderPlugin.swift          # 插件入口：只负责注册 / 注销
    ├── Models/
    │   └── FinderTimeline.swift    # 载荷模型 —— 不是渲染器
    ├── Renderers/                  # ← 渲染器归属目录
    │   └── FinderCardRenderer.swift
    └── Views/
        └── FinderCardView.swift    # 卡片视图 —— 不是渲染器
```

---

## 3. 命名规范

| 角色 | 命名 | 示例 |
|------|------|------|
| 消息级渲染器 | `<Domain>Renderer` | `FinderCardRenderer`、`HTMLCanvasRenderer` |
| 工具调用行渲染器 | `<Domain>RowRenderer` | `LLMProviderRowRenderer`、`ToolApprovalRowRenderer` |
| 文件名 | 与主类型名一致 | `FinderCardRenderer.swift` |

**一个类型一个文件**，文件名 = 类型名。

### 3.1 `Renderers/` 下的二级分组

渲染器数量多时可在 `Renderers/` 下按域再分一级子目录，**但渲染器类型本身
必须直接位于名为 `Renderers` 的目录或其子目录中**：

```
Packages/PluginMessageRenderer/
└── Sources/PluginMessageRenderer/
    └── Renderers/
        ├── Core/                          # ← 二级分组
        │   ├── CoreTurnCompletedRenderer.swift
        │   ├── CoreStatusMessageRenderer.swift
        │   └── ...
        └── ToolApprovalRowRenderer.swift
```

命名用 `Core<Domain>Renderer`，与目录名 `Core/` 对应，避免两个分组里出现同名类型。

> `PluginMessageRenderer` 包的 `Renderers/` 下同时有**视图**（`AssistantMessageView` 等）
> 与**渲染器条目**（`Renderers/Core/` 下）。核心渲染器插件的注册逻辑在入口，
> 但渲染器类型仍须落在 `Renderers/` 内。见第 6 节「核心渲染器插件」。

---

## 4. 注册方式

渲染器类型**只负责描述「我渲染什么、画成什么样」**，不负责何时注册。
注册与注销一律在**插件入口**的 `onBoot` / `onShutdown` 中完成：

```swift
// Plugins/PluginFinder/FinderPlugin.swift
private func registerContributions(kernel: KernelCoreContainer) {
    guard let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) else {
        Self.logger.error("\(Self.t)Failed to resolve MessageRenderingProviding")
        return
    }
    rendering.register(FinderCardRenderer.item(order: order))
}

private func unregisterContributions(kernel: KernelCoreContainer) {
    kernel.resolveProvider((any MessageRenderingProviding).self)?
        .unregister(id: FinderTimeline.rendererID)
}
```

**禁止**在插件入口文件里**内联构造** `MessageRendererItem`：

```swift
// ❌ 入口文件里直接写渲染器构造逻辑
manager.register(MessageRendererItem(
    id: "core-status-message",
    order: base + 310,
    canRender: { ... },
    render: { ... }
))
```

理由：入口文件是**装配层**，一旦开始长渲染逻辑就会失控（`PluginMessageRenderer`
历史上就长到了 441 行、13 个内联渲染器）。正确做法是把每个渲染器抽成
`Renderers/` 下的命名类型，入口只做 `register(SomeRenderer.item(...))`。

---

## 5. 渲染器与视图的边界

| 关注点 | 归属 |
|--------|------|
| 「这条消息归我渲染吗」 | 渲染器（`canRender`） |
| 「画成什么样」 | 渲染器（`render`）或它引用的 `Views/` 视图 |
| 载荷编解码 | `Models/`（`*Timeline`） |
| 渲染优先级 | 渲染器工厂方法的 `order` 参数，由入口按 `info.order` 派生 |

渲染器**不得**承担业务逻辑（如打开 Finder、发起网络请求），
应通过 `Services/` 或能力协议调用。

---

## 6. 核心渲染器插件（豁免）

`PluginMessageRenderer` 是**核心渲染器插件**，它注册的是一组**基础消息类型**
（用户 / 助手 / 系统 / 错误 / 状态 / 工具消息）的兜底渲染器。

豁免内容：

- 入口文件 `MessageRendererPlugin.swift` **只负责注册**，不内联构造
  `MessageRendererItem`；每个核心渲染器抽成 `Renderers/Core/` 下的命名类型。
- 渲染器对应的**视图**已在 `Renderers/` 下（`AssistantMessageView` 等），
  属于既有事实，本规范不再迁移。

---

## 7. 守卫测试

`Packages/FactoryLumi/Tests/FactoryLumiTests/MessageRendererDirectoryConformanceTests.swift`
是本规范的守卫测试：扫描 `Packages/**/Sources/**`，断言所有渲染器类型所在文件
的**祖先目录链中必须存在名为 `Renderers` 的目录**（允许 `Renderers/Core/` 这类
二级分组）。

改动渲染器相关文件后必须让它保持绿色。

---

## 8. 检查清单

新增或改造插件渲染器时，确认：

- [ ] 渲染器类型在 `Renderers/` 目录下，文件名 = 类型名
- [ ] 卡片视图仍在 `Views/`，载荷模型仍在 `Models/`
- [ ] 插件入口只调用 `register` / `unregister`，不内联构造 `MessageRendererItem`
- [ ] `order` 派生自 `info.order`（见 [插件 UI 项 order 规范](./plugin-order-rules.md)）
- [ ] 渲染器不直接访问全局单例，依赖经能力协议注入（见 [插件 Capabilities 能力边界规范](./plugin-capabilities.md)）
- [ ] 渲染器不依赖其它插件（见 [内核与插件边界规范](./core-plugin-boundary-rules.md)）

---

## 相关规范

- [插件目录结构规范](./plugin-directory-rules.md) — `LumiApp/Plugins/` 内部结构
- [插件包目录结构规范](./plugin-package-structure.md) — `Packages/` 下 SPM 包分层
- [插件 UI 项 order 规范](./plugin-order-rules.md) — 渲染器 `order` 的派生方式
- [插件 Capabilities 能力边界规范](./plugin-capabilities.md) — 渲染器的依赖注入方式
- [内核与插件边界规范](./core-plugin-boundary-rules.md) — 插件之间不得互相依赖
