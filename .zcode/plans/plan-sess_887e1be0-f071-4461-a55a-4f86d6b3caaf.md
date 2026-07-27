## 架构方案：WorkspaceStateProviding（工作区可见性能力集）

### 1. 背景与现状

| 现状 | 路径 |
|---|---|
| `ActivityBar` 点击 → 写 `LayoutStateInfo.activeSectionID` | `Packages/LumiFactory/.../ActivityBar.swift` |
| `AppLayoutView` 读取 `activeSectionID` 决定渲染 | `Packages/LumiFactory/.../AppLayoutView.swift` |
| `LayoutStateInfo` 只有 `activeSectionID / activeSectionTitle / chatSectionVisible` | `LumiKernel/Types/LayoutStateInfo.swift` |
| `LayoutProviding` 只有 `updateLayout` 闭包修改器 | `LumiKernel/Providers/LayoutProviding.swift` |
| 三个能力耦合在 `ViewContainerItem`：`chatSection / showsRail / showsPanelChrome` | `LumiKernel/Types/ViewContainer.swift` |
| `ChatPanelPlugin` 仅注册 icon-only 容器（`makeView == nil`），声明 `showsRail: true` | `Plugins/ChatPanelPlugin/...` |

**痛点**：`AppLayoutView` 直接消费 `ViewContainerItem` 的静态标志，无法被插件运行时控制；plugin 与 view 紧耦合。

### 2. 设计原则

> Kernel 提供**能力**（capabilities），**插件**通过命令式方法声明自己想要的状态；View 层只问 Kernel，**不知道**是哪个插件注册了什么。

### 3. 新增 `WorkspaceStateProviding`

**文件**：`Packages/LumiKernel/Sources/LumiKernel/Providers/WorkspaceStateProviding.swift`

```swift
@MainActor
public protocol WorkspaceStateProviding: ObservableObject {
    // MARK: - 读取（View 层只读）
    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var isContentVisible: Bool { get }
    var isActivityBarVisible: Bool { get }
    var activeContainerID: String? { get }

    // MARK: - 命令式入口（插件可调用）
    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setContentVisible(_ visible: Bool)
    func setActivityBarVisible(_ visible: Bool)
    func activateContainer(id: String)

    // MARK: - 批量重置（插件切换时调用）
    func applyVisibility(
        rail: Bool? = nil,
        chat: Bool? = nil,
        content: Bool? = nil,
        activityBar: Bool? = nil
    )
}
```

**配套**：
- `LumiKernel.workspaceState` 访问器
- `registerWorkspaceStateService(_:)` 注册方法
- `startup()` 验证 `workspaceState` 不为 nil

### 4. 默认实现 `DefaultWorkspaceStateProviding`

**文件**：`Plugins/WorkspaceStatePlugin/Sources/WorkspaceStatePlugin/DefaultWorkspaceStateProviding.swift`

- 内部 `@Published` 4 个 Bool + `activeContainerID`
- 命令方法同步更新 + `objectWillChange.send()`
- 默认值：`isChatVisible=true`，其他 `true`（保留现状）
- 由 `WorkspaceStatePlugin` 实例化并注册到 kernel

### 5. 插件 → Kernel 控制流程

**PluginManagerPlugin 的扩展点**：

```swift
// LumiPlugin 协议新增
public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
    .init(rail: nil, chat: nil, content: nil, activityBar: nil)
}

public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
```

```swift
// WorkspaceVisibility
public struct WorkspaceVisibility {
    public var rail: Bool?
    public var chat: Bool?
    public var content: Bool?
    public var activityBar: Bool?
}
```

`PluginManagerProvider` 在插件 `register` 后调用：
```swift
let visibility = plugin.workspaceVisibility(kernel: kernel)
kernel.workspaceState?.applyVisibility(
    rail: visibility.rail,
    chat: visibility.chat,
    content: visibility.content,
    activityBar: visibility.activityBar
)
```

**容器激活流程改造**：
1. 用户点击 ActivityBar 图标 → `WorkspaceStateProviding.activateContainer(id:)`
2. `DefaultWorkspaceStateProviding` 更新 `activeContainerID` → 触发 `objectWillChange`
3. 通知所有插件：`plugin.onContainerActivated(kernel:, containerID:)`
4. 每个插件响应回调 → 调用 `kernel.workspaceState.setXxxVisible(...)` 调整自己关心的能力

**示例：`ChatPanelPlugin`** 激活时的声明：

```swift
public func onContainerActivated(kernel: LumiKernel, containerID: String) {
    guard containerID == id else { return }
    kernel.workspaceState?.applyVisibility(
        rail: true,          // chat 激活时显示 rail
        chat: true,          // 永远显示 chat
        content: false,      // 不需要 main content 区域
        activityBar: true
    )
}
```

### 6. View 层只读

**`AppLayoutView` 改造**（简化）：

```swift
let workspace = kernel.workspaceState

// 渲染完全由 workspace 决定
HStack(spacing: 0) {
    if workspace.isActivityBarVisible {
        ActivityBar(kernel: kernel, containers: containers)
        AppDivider(.vertical)
    }

    if workspace.isContentVisible, let makeView = selected.makeView {
        makeView()
    }

    if workspace.isRailVisible {
        SimpleRailView(tabs: railTabs)
    }

    if workspace.isChatVisible {
        chatView
    }
}
```

`ActivityBar` 不再写 `LayoutState.activeSectionID`，改写 `workspaceState.activateContainer(id:)`。

### 7. 落地清单

| 步骤 | 文件 | 内容 |
|---|---|---|
| 1 | `Providers/WorkspaceStateProviding.swift` | 新建协议 |
| 2 | `LumiKernel/LumiKernel.swift` | `workspaceState` 访问器 + `registerWorkspaceStateService` + startup 验证 |
| 3 | `Plugins/WorkspaceStatePlugin/` | 新建插件，包含 `DefaultWorkspaceStateProviding` |
| 4 | `Contracts/LumiPlugin.swift` | 新增 `workspaceVisibility(kernel:)` + `onContainerActivated(kernel:containerID:)` 扩展点 |
| 5 | `PluginManagementPlugin/Managers/PluginManagerProvider.swift` | 注册时调用 `workspaceVisibility`；激活容器时分发 `onContainerActivated` |
| 6 | `LumiFactory/PluginService.swift` | 注册 `WorkspaceStatePlugin`（`order = 1`，最早） |
| 7 | `LumiFactory/Views/Layout/AppLayoutView.swift` | 改为读 `workspaceState`，简化逻辑 |
| 8 | `LumiFactory/Views/Layout/ActivityBar.swift` | 点击改写 `workspaceState.activateContainer(id:)` |
| 9 | `Plugins/ChatPanelPlugin/ChatPanelPlugin.swift` | 用 `onContainerActivated` 声明自己激活时的能力 |
| 10 | 其他需要能力的插件 | 同样模式 |

### 8. 边界处理

- **`workspaceState == nil`**：启动期，加载完成前；View 层用 `kernel.workspaceState ?? defaultWorkspaceState()` 兜底。
- **多个插件同时设置**：后者覆盖前者；需要顺序保证（`WorkspaceStatePlugin` 在 `order=1` 注册，`PluginManagerPlugin` 在 `order=5`，所有插件默认 `order>=10`）。
- **持久化**：4 个可见性 + 激活容器 ID → `LayoutState`（已有类似结构），可由 `LayoutPersistenceCoordinator` 扩展。

### 9. 不在本次范围

- 移除 `LayoutStateInfo.chatSectionVisible`（保留过渡）
- 重写 `LayoutPlugin` 持久化（可单独迭代）
- 改 `ChatSectionProviding` 与容器作用域（保留独立 PR）