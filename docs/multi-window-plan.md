# Multi Window Plan

目标：让 Lumi 支持类似 VS Code 的多主窗口体验。用户可以新建空窗口、把项目打开到新窗口、把会话打开到新窗口；每个窗口拥有独立的窗口级状态，同时共享插件、设置、模型供应商、数据库和底层服务。

## 背景

当前应用已经具备一部分多窗口基础，但主窗口仍被 Scene 限制为单实例：

- `LumiApp/Core/Bootstrap/App.swift`
  - 当前主窗口使用 `Window("Lumi", id: MainWindowID.main)`。
  - `Window` 语义更适合单例窗口，会阻止创建第二个同 ID 主窗口。
- `LumiApp/Core/Views/Layout/ContentView.swift`
  - 每个 `ContentView` 内部已经通过 `@StateObject private var windowState` 创建独立 `WindowState`。
  - 当前通过 `WindowManager.shared.registerWindow(windowState)` 注册窗口。
- `LumiApp/Core/Views/Layout/ContentLayout.swift`
  - 已经支持 `conversationId` 和 `projectPath` 作为初始窗口上下文。
- `LumiApp/Core/Services/WindowManager.swift`
  - 已经提供窗口注册、关闭、激活、广播、NSWindow 关联等能力。
- `LumiApp/Core/Bootstrap/RootContainer.swift`
  - 目前大量 ViewModel 和服务是全局单例注入，适合共享服务，但不适合承载“当前窗口正在看的项目/会话/编辑器 tab”。

因此第一阶段不需要重写窗口管理系统，而是把主 Scene 改成可重复创建的 `WindowGroup`，并明确哪些状态属于窗口，哪些状态属于全局。

## 设计原则

- 主窗口使用 `WindowGroup`，设置窗口继续使用单例 `Window`。
- 每个主窗口拥有独立的 `WindowState`。
- 打开项目/会话到新窗口时，通过 window route 传递初始上下文。
- 全局服务继续由 `RootContainer.shared` 管理，避免一次性大改。
- 当前项目、当前会话、打开的编辑器 tab、面板布局等“用户当前视图状态”逐步迁移到窗口级状态。
- 多窗口改造必须分阶段推进，每个阶段都能编译和运行。
- 先支持同一进程内多窗口，不引入多进程架构。

## 窗口模型

新增轻量 route 模型，建议放在 `LumiApp/Core/Entities/LumiWindowRoute.swift`：

```swift
import Foundation

struct LumiWindowRoute: Codable, Hashable, Identifiable {
    var id: UUID
    var conversationId: UUID?
    var projectPath: String?

    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.projectPath = projectPath
    }
}
```

route 的职责只是在创建窗口时传递初始上下文，不承担窗口运行期状态。窗口创建后，运行期状态仍由 `WindowState` 持有。

## Scene 改造

将 `App.swift` 中的主窗口从 `Window` 改为 `WindowGroup`。

当前结构：

```swift
Window("Lumi", id: MainWindowID.main) {
    ContentLayout()
        .inRootView()
}
```

建议改为：

```swift
WindowGroup("Lumi", id: MainWindowID.main, for: LumiWindowRoute.self) { route in
    ContentLayout(
        conversationId: route.wrappedValue?.conversationId,
        projectPath: route.wrappedValue?.projectPath
    )
    .inRootView()
}
```

设置窗口保持当前单例结构：

```swift
Window("设置", id: SettingsWindowID.settings) {
    SettingView()
        .inRootView()
}
```

如果需要兼容不带 value 的默认启动窗口，应确认系统启动时 `route.wrappedValue == nil` 能正常创建空窗口。

## 命令入口

新增窗口命令，建议放在 `LumiApp/Core/Commands/WindowCommand.swift`：

```swift
import SwiftUI

struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(
                    id: MainWindowID.main,
                    value: LumiWindowRoute()
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
```

然后在 `App.swift` 的 `.commands` 中注册：

```swift
WindowCommand()
```

后续可增加：

- `在新窗口打开项目`
- `在新窗口打开会话`
- `关闭窗口`
- `关闭其他窗口`
- `切换到下一个窗口`

## 打开项目到新窗口

当用户从项目列表、最近项目、命令面板或文件选择器打开项目时，提供两种行为：

- 当前窗口打开：更新当前窗口的 `WindowState.projectPath`。
- 新窗口打开：通过 `openWindow` 创建新窗口。

建议新窗口入口统一调用：

```swift
openWindow(
    id: MainWindowID.main,
    value: LumiWindowRoute(projectPath: path)
)
```

不要让业务代码直接创建 `NSWindow`。SwiftUI Scene 负责窗口生命周期，`WindowManager` 只负责跟踪和协调。

## 打开会话到新窗口

会话列表、聊天记录、上下文菜单可提供“在新窗口打开”：

```swift
openWindow(
    id: MainWindowID.main,
    value: LumiWindowRoute(conversationId: conversationId)
)
```

窗口初始化时，`ContentLayout` 将 `conversationId` 传入 `ContentView`，`ContentView` 创建 `WindowState(conversationId: conversationId, projectPath: projectPath)`。

需要注意：如果 `ConversationVM.selectedConversationId` 仍是全局状态，新窗口打开会话可能会影响其他窗口。短期可以先接受该限制，长期需要把当前选中会话迁移到窗口级状态。

## 状态边界

### 全局状态

这些状态适合继续由 `RootContainer.shared` 或共享服务管理：

- 主题和外观设置。
- 插件注册与启用状态。
- LLM provider 注册表。
- API key 和供应商配置。
- SwiftData `ModelContainer`。
- 聊天历史数据库服务。
- 工具执行服务。
- 全局消息渲染器。
- 应用更新、日志、菜单栏控制器。

### 窗口级状态

这些状态应属于每个主窗口：

- 当前项目路径。
- 当前选中会话。
- 当前激活插件面板。
- rail / sidebar 展开状态。
- 编辑器打开文件列表。
- 编辑器当前 active tab。
- 编辑器分栏布局。
- 文件树展开状态。
- 当前搜索条件。
- 当前终端 tab 或终端工作目录。
- 当前窗口 title。

第一阶段可以只保证 `WindowState` 独立。后续逐步把全局 VM 中的“当前选择”字段迁移到窗口级模型。

## WindowManager 调整

当前 `WindowManager` 能注册和激活窗口，但有两个点需要修复。

### 避免重复注销

`closeWindow(_:)` 当前主动调用 `window.close()` 后又调用 `unregisterWindow(windowId)`，而 `windowWillClose(_:)` 也会注销。多窗口后建议只让 `windowWillClose` 负责最终注销：

```swift
func closeWindow(_ windowId: UUID) {
    guard let window = windowIdMap.first(where: { $0.value == windowId })?.key else {
        return
    }
    window.close()
}
```

### 提供按 ID 查找 NSWindow

新增方法：

```swift
func window(for windowId: UUID) -> NSWindow? {
    windowIdMap.first(where: { $0.value == windowId })?.key
}
```

`ContentView` 更新标题时应该只更新当前窗口，而不是扫描 `NSApplication.shared.windows` 后误改其他窗口。

## 标题同步

当前 `ContentView.setupWindowTitleObserver()` 中的查找逻辑不可靠：

```swift
if let window = NSApplication.shared.windows.first(where: { _ in
    WindowManager.shared.getWindowState(windowId) != nil
}) {
    window.title = newTitle
}
```

这个 predicate 与具体 `NSWindow` 无关，只要 `WindowState` 存在就会命中第一个窗口。多窗口后会导致标题串窗。

建议改成：

```swift
if let window = WindowManager.shared.window(for: windowId) {
    window.title = newTitle
}
```

另外 `ContentView.onAppear()` 里用 `keyWindow ?? windows.last` 关联窗口也有误关联风险。更稳妥的方式是通过一个 `NSViewRepresentable` 获取当前 SwiftUI view 所在的 window，再调用 `associateWindow`。

## 当前窗口识别

建议新增一个轻量 `WindowAccessor`：

```swift
import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
```

在 `ContentView` 中使用：

```swift
.background {
    WindowAccessor { window in
        WindowManager.shared.associateWindow(window, with: windowState.id)
        window.title = windowState.title
    }
}
```

这样可以避免 `NSApplication.shared.keyWindow` 在多窗口场景下指向其他窗口。

## 生命周期和恢复

第一阶段只实现运行期多窗口，不强制实现窗口恢复。

后续可选能力：

- 应用退出时保存所有主窗口 route。
- 下次启动恢复项目窗口和会话窗口。
- 保存每个窗口的位置、尺寸和上次 active 状态。
- 对同一项目重复打开时，提供“聚焦已有窗口”或“仍然新建窗口”的设置。

建议窗口恢复单独做，不要和第一阶段混在一起，否则影响范围会显著扩大。

## 插件适配

多窗口后插件需要避免依赖全局“当前窗口”隐式状态。建议逐步要求插件从环境读取窗口状态：

```swift
@Environment(\.windowState) private var windowState
```

插件如果需要当前项目或当前会话，优先使用 `windowState?.projectPath` 和 `windowState?.selectedConversationId`。

短期兼容策略：

- 旧插件继续使用全局 VM。
- 新增的多窗口入口只保证窗口能创建和显示。
- 对编辑器、终端、项目文件树等强窗口相关插件逐个迁移。

优先迁移：

- EditorPanelPlugin
- EditorRailFileTreePlugin
- TerminalPlugin
- AgentChatPlugin
- AgentNewChatPlugin
- Project 相关入口

## 分阶段实施

### Phase 1: 打开多个主窗口

- [ ] 新增 `LumiWindowRoute`。
- [ ] 将主 Scene 从 `Window` 改成 `WindowGroup(..., for: LumiWindowRoute.self)`。
- [ ] 新增 `WindowCommand`。
- [ ] 在 `.commands` 注册 `WindowCommand()`。
- [ ] 验证 `Command+Shift+N` 能创建多个主窗口。
- [ ] 确认设置窗口仍然单例。

### Phase 2: 修复窗口跟踪

- [ ] 新增 `WindowAccessor`。
- [ ] `ContentView` 使用 `WindowAccessor` 获取当前 `NSWindow`。
- [ ] `WindowManager` 新增 `window(for:)`。
- [ ] 修复标题同步只更新当前窗口。
- [ ] 修复 `closeWindow(_:)` 避免重复注销。
- [ ] 验证关闭任意窗口后 `WindowManager.windowStates` 数量正确。

### Phase 3: 项目和会话新窗口入口

- [ ] 在项目入口增加“在新窗口打开”。
- [ ] 在最近项目入口增加“在新窗口打开”。
- [ ] 在会话列表增加“在新窗口打开”。
- [ ] 使用 `openWindow(id:value:)` 统一创建窗口。
- [ ] 验证窗口标题能根据项目或会话变化。

### Phase 4: 窗口级状态迁移

- [ ] 梳理 `ConversationVM.selectedConversationId` 的读写点。
- [ ] 将当前选中会话迁移到 `WindowState.selectedConversationId` 或窗口级 conversation VM。
- [ ] 梳理 `ProjectVM` 中当前项目状态。
- [ ] 将当前项目迁移到 `WindowState.projectPath` 或窗口级 project context。
- [ ] 梳理 `EditorVM` 中打开 tab 和 active editor 状态。
- [ ] 为每个窗口维护独立编辑器状态。
- [ ] 插件优先从 `@Environment(\.windowState)` 获取窗口上下文。

### Phase 5: VS Code 风格行为

- [ ] 支持拖拽文件夹到 Dock/App 图标后打开新窗口或当前窗口。
- [ ] 支持从命令行参数打开项目窗口。
- [ ] 支持窗口恢复。
- [ ] 支持“打开同一项目时聚焦已有窗口”的设置。
- [ ] 支持窗口间广播全局事件，但避免覆盖窗口级状态。

## 验证清单

- [ ] 启动应用后默认打开一个主窗口。
- [ ] `Command+Shift+N` 创建第二个主窗口。
- [ ] 两个主窗口拥有不同的 `WindowState.id`。
- [ ] 切换窗口时 `WindowManager.activeWindowId` 正确变化。
- [ ] 关闭一个窗口不会误注销另一个窗口。
- [ ] 修改一个窗口标题不会影响另一个窗口。
- [ ] 打开设置始终复用同一个设置窗口。
- [ ] 新窗口可以通过 route 接收 `projectPath`。
- [ ] 新窗口可以通过 route 接收 `conversationId`。
- [ ] 多窗口下插件工具栏、ActivityBar、PanelContentView 正常渲染。

## 风险和限制

- 全局 `ConversationVM`、`ProjectVM`、`EditorVM` 仍可能导致多个窗口互相影响。
- `NSApplication.shared.keyWindow` 在多窗口中不可靠，必须避免用于绑定当前 SwiftUI window。
- 插件如果缓存了全局当前项目，需要逐个迁移。
- 多窗口恢复涉及状态持久化和启动顺序，建议单独设计。
- 如果未来要接近 VS Code 的多进程隔离，需要另起架构设计；本方案只覆盖单进程多窗口。

## 推荐落地顺序

先完成 Phase 1 和 Phase 2，让应用具备稳定的多主窗口能力。之后选择一个垂直场景打通，例如“项目列表在新窗口打开项目”，再迁移编辑器相关窗口级状态。这样能尽早暴露真实多窗口问题，同时避免一次性重构所有全局 ViewModel。
