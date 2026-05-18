# TODO

整合自多个 todo/planning 文档，按主题分类。

标记说明：`👤 需要用户参与` 表示该任务需要人类操作物理设备、做主观体验判断或最终产品验收，AI 无法独立完成。

---

## 1. UI Jank 调查

> 目标：识别并验证可能导致 UI 卡顿、掉帧或交互迟滞的代码路径。

### 待完成

- [ ] 👤 需要用户参与：使用 Instruments Time Profiler 在以下场景运行应用：
  - [ ] 启用所有默认插件启动应用。
  - [ ] 打开主工作区并切换活动栏面板。
  - [ ] 滚动包含 Markdown 和代码块的长对话。
  - [ ] 发送消息并观察流式/工具状态更新。
  - [ ] 在 DeviceInfo/Network 插件激活时打开菜单栏弹出窗口。
- [ ] 👤 需要用户参与：记录 Main Thread Checker 和 SwiftUI body 更新热点。
- [ ] 👤 需要用户参与：Instruments trace 总结（主线程热点排名）。
- [ ] 全量 `Lumi` scheme 构建被截图功能变更阻塞（`ScreenshotOverlay.swift` 使用不可用的 `CGDisplayCreateImage`）。

### 已完成摘要（2026-05-14）

Priority 1-7 全部修复完成：主线程数据库查询优化、后台采样迁移、插件视图缓存、滚动去重、Markdown/代码高亮缓存、根覆盖层后台化、文件系统扫描取消保护。详见 git log。

---

## 2. 编辑器滚动卡顿修复

> 目标：通过消除每次滚动的状态抖动、去重视口发布、延迟持久化来减少编辑器滚动卡顿。

### Phase 0: 基线和检测

- [ ] 添加临时 signposts 到编辑器滚动路径。
- [ ] 👤 需要用户参与：使用 Instruments Time Profiler 在不同文件大小和配置下分析。
- [ ] 👤 需要用户参与：记录基线指标（主线程时间、snapshot 调用频率、viewport 发布频率等）。

### Phase 1: 移除重复滚动状态路径

- [ ] 确定滚动持久化的单一所有者（`ScrollCoordinator`）。
- [ ] 停止每次 `boundsDidChange` 时发布 `scrollPositionDidUpdateNotification`。
- [ ] 更新 `SourceEditor.Coordinator.textControllerScrollDidChange` 不再写入每个滚动点。
- [ ] 验证会话恢复仍然正常。

### Phase 2: 节流会话滚动持久化

- [ ] 拆分 `publishViewportObservation` 为轻量视口观察 + 防抖持久化。
- [ ] 添加滚动稳定防抖（120-200ms）。
- [ ] 避免 `applyInteractionUpdate` 用于实时滚动。
- [ ] 定义滚动原点相等性容差（建议 <0.5px 忽略）。

### Phase 3: 去重视口行发布

- [ ] 在 `ScrollCoordinator` 缓存上次视口观察。
- [ ] 仅当行范围或总行数变化时调用 `applyViewportObservation`。
- [ ] 添加视口去重测试。

### Phase 4: 从滚动中移除折叠工作

- [ ] 停止在滚动更新期间调用 `currentFoldingState()`。
- [ ] 仅在折叠变更、文档变更、文件切换时捕获折叠状态。
- [ ] 按文档内容版本缓存 `LineOffsetTable`。
- [ ] 验证折叠行在手动滚动、文件切换、应用重启后仍能恢复。

### Phase 5: 减少高亮可见范围抖动

- [ ] 给 `VisibleRangeProvider.visibleTextChanged` 添加去重。
- [ ] 隐藏或禁用 minimap 时不联合 minimap 可见范围。
- [ ] 考虑节流连续滚动期间的高亮刷新。

### Phase 6: 减少 LSP 视口观察器开销

- [ ] 替换每次通知创建 `Task { @MainActor in }` 为直接主队列观察者回调。
- [ ] 添加视口变更显著性检查。
- [ ] 确保 large file mode / 非焦点时不调度语义 token 刷新。

### Phase 7: Minimap 和 Gutter 后续

- [ ] 测量 gutter 绘制开销。
- [ ] 测量 minimap 跟随开销。
- [ ] 必要时优化（缓存 CTLine、限制失效区域、禁用快速滚动同步等）。

### Phase 8: 验证

- [ ] 运行 `EditorKernel`、`EditorService`、`LumiCodeEditSourceEditor` 单元测试。
- [ ] 👤 需要用户参与：针对不同文件大小进行应用验证（手动滚动测试流畅度）。
- [ ] 👤 需要用户参与：重新运行 Instruments 对比基线。
- [ ] 移除临时 signposts。

### 成功标准

- [ ] 连续滚动不再每帧触发 `activeSession.applySnapshot`。
- [ ] `LineOffsetTable` 不因滚动事件重建。
- [ ] `viewportRenderLineRange` 仅在渲染行范围变化时发布。
- [ ] 快速滚动时语义 token 视口刷新调度有界。
- [ ] 👤 需要用户参与：Gutter/minimap 更新视觉正确。
- [ ] 👤 需要用户参与：滚动位置恢复仍正常工作。
- [ ] 👤 需要用户参与：普通和中等文件上快速滚动流畅。

---

## 3. App UI 平滑度

> 目标：让 Lumi 在输入、聊天流式、面板切换、主题/布局刷新等高频 UI 路径中更流畅。

### Priority 0: 基线和测量

- [ ] 👤 需要用户参与：Instruments 测量各场景。
- [ ] 添加/复用 `UIPerformanceSignpost`。
- [ ] 👤 需要用户参与：记录基线指标。

### Priority 1: 输入斜杠命令建议

- [ ] 检查 `InputAreaView.swift` 和 `CommandSuggestionVM.swift`。
- [ ] 添加可取消的建议 task。
- [ ] 添加 150-250ms 防抖。
- [ ] 跟踪最新输入 token 丢弃过期结果。
- [ ] 值未变时不发布。
- [ ] 关闭高频路径的 verbose 日志。

### Priority 2: 流式 Markdown 渲染

- [ ] 检查 `MarkdownBlockRenderer.swift` 和 `HighlightedCodeView.swift`。
- [ ] 添加流式特定渲染模式（不完整尾部作为纯文本，稳定块才解析）。
- [ ] 考虑块级缓存键而非全消息键。
- [ ] 代码围栏未闭合时跳过高亮。

### Priority 3: 聊天列表派生状态

- [ ] 检查 `MessageListView.swift`。
- [ ] 将显示行构造移入 `ChatTimelineViewModel` 或派生状态缓存。
- [ ] 隔离活跃流式行，避免每个 token 重建整个可见行列表。
- [ ] 避免为工具调用状态未变的行重新计算 `toolOutputs(for:)`。

### Priority 4: 插件 UI 贡献失效

- [ ] 检查 `PluginVM.swift` 和 `ContentView.swift`。
- [ ] 按表面拆分插件贡献状态（Toolbar、StatusBar、Panel/Rail/Sidebar、MenuBar）。
- [ ] 添加精确版本键。
- [ ] 避免清除不相关的表面缓存。

### Priority 5: 视觉效果和主题背景

- [ ] 检查主题 `makeGlobalBackground` 实现（大量模糊径向形状）。
- [ ] 添加减少效果路径或性能模式。
- [ ] 考虑按窗口尺寸桶栅格化静态主题背景。
- [ ] 连续调整大小时保持背景静态，稳定后刷新。
- [ ] 👤 需要用户参与：验证主题外观仍可接受，窗口调整大小和主题切换视觉平滑。

### Priority 6: 高频日志

- [ ] 审计 `verbose: Bool = true` 在 UI 和输入路径中的使用。
- [ ] 关闭 `CommandSuggestionVM`、`InputAreaView`、`MessageListView`、`PluginVM` 的 verbose 日志。
- [ ] 将昂贵日志参数构造放在 `if Self.verbose` 后面。

### Priority 7: 输入区域布局动画

- [ ] 检查 `InputAreaView.macEditorView`。
- [ ] 仅对有意义的跨行高度变化应用动画。
- [ ] 快速输入时禁用高度动画，稳定后重新启用。
- [ ] 👤 需要用户参与：验证多行输入手感流畅，焦点不丢失，附件条和命令建议位置稳定。

### 成功标准

- [ ] 快速输入不卡顿。
- [ ] 长 Markdown 流式更新流畅。
- [ ] 聊天自动跟随不抖动。
- [ ] 面板切换缓存预热后即时响应。
- [ ] 👤 需要用户参与：窗口调整大小和主题切换无明显掉帧。
- [ ] 👤 需要用户参与：Instruments 显示输入、聊天流式和插件贡献重建路径的主线程工作减少。

---

## 4. 截图功能加固

> 目标：提升多屏幕、错误反馈和截图准备阶段的健壮性。

### QA 清单

- [ ] 👤 需要用户参与：单屏 Retina 截图
- [ ] 👤 需要用户参与：外接屏截图
- [ ] 👤 需要用户参与：左右排列多屏截图
- [ ] 👤 需要用户参与：上下排列多屏截图
- [ ] 👤 需要用户参与：跨屏拖拽截图
- [ ] 👤 需要用户参与：过小选区自动取消
- [ ] 👤 需要用户参与：ESC 取消
- [ ] 👤 需要用户参与：未授权屏幕录制权限
- [ ] 👤 需要用户参与：截图后附件预览出现并可发送

---

## 5. 文件树图标主题

> 目标：让 Lumi 主题插件通过单一 `LumiThemeContribution` 配置文件树图标。

### 待完成

- [ ] 添加精确文件名查找单元测试。
- [ ] 添加扩展名查找单元测试。
- [ ] 添加文件夹开/关图标查找单元测试。
- [ ] 添加证明回退行为与当前 `EditorFileTreeService` 映射一致的测试。
- [ ] 添加 `ThemeVM` 测试证明活跃主题暴露其文件图标贡献者。
- [ ] 添加文件树视图级别冒烟测试（如可行）。
- [ ] 在所有调用点迁移后移除或弃用直接文件图标映射。

### 已完成摘要（2026-05-15）

API 设计、内置解析器、文件树集成、16 个主题插件接入、构建验证全部完成。`EditorFileTreeService.getFileIcon` 保留为兼容 shim。

---

## 6. Onboarding 插件选择界面

> 目标：在首次引导最后一步之前新增「选择要启用的插件」页面。
> 涉及文件：`LumiApp/Plugins/AgentOnboardingPlugin/Views/OnboardingRootOverlay.swift`

### 详细步骤

- [ ] 新增 OnboardingPage（icon: `puzzlepiece.extension.fill`，标题: "选择你的插件"）。
- [ ] 新增 `@State private var selectedPluginIDs: Set<String>` 视图状态，初始化时从 `PluginVM` 读取可配置插件默认启用状态。
- [ ] 自定义页面内容：遍历可配置插件显示勾选列表。
- [ ] 修改 `pageContent` 用 `page.id`（建议给 `OnboardingPage` 增加 `id: String` 字段）判断是否为插件选择页。
- [ ] 修改底部操作栏：「开始使用」按钮点击时先调用 `applyPluginSelection()` 写入用户选择。
- [ ] 页面尺寸适配：插件选择页使用 `ScrollView` 或增大 sheet 高度。
- [ ] 国际化：新增本地化字符串到 `AgentOnboardingPlugin.xcstrings`。
- [ ] 👤 需要用户参与：验证首次引导流程的视觉和交互体验（删除 onboarding state plist 重启 App 触发）。

### 注意事项

1. `PluginVM` 是 `@MainActor`，`OnboardingSheetView` 也在 MainActor，无需额外调度。
2. Onboarding 仅首次运行展示，选择结果由 `PluginSettingsVM` 持久化。
3. `AgentOnboardingPlugin` 的 `isConfigurable = false`，不会出现在可选列表。
4. 引导结束后禁用的插件 UI 扩展点应立即消失。
5. 如果所有插件都不可配置，跳过插件选择页。

---

## 7. 编辑器文件树 Git 状态标记

> 目标：在文件树中实现类似 Xcode 的 Source Control 状态标记。

### Phase 1: 模型和 Provider

- [ ] 新增 `EditorFileTreeGitStatusProvider.swift`。
- [ ] 定义 status enum、entry、snapshot。
- [ ] 实现路径 normalizer。
- [ ] 复用或封装 LibGit2Swift status 获取。
- [ ] 对非 Git 仓库返回 empty snapshot。
- [ ] 添加 provider 单元测试。

### Phase 2: Coordinator 接入

- [ ] 在 `EditorFileTreeRefreshCoordinator` 持有 snapshot。
- [ ] 项目切换时刷新 Git 状态。
- [ ] 文件系统变化时 debounced 刷新 Git 状态。
- [ ] 增加 `.git` 元数据监听。
- [ ] 处理 worktree `gitdir`。
- [ ] 确保项目切换取消旧 refresh task。

### Phase 3: UI 标记

- [ ] `EditorFileTreeView` 向根节点传入 snapshot。
- [ ] `EditorFileTreeNodeView` 接收 snapshot 并计算当前节点状态。
- [ ] 在行尾渲染固定宽度状态标记（M/A/D/R/?/C）。
- [ ] 为选中、hover、深浅色主题调整颜色。
- [ ] 为状态标记添加 tooltip。
- [ ] 👤 需要用户参与：验证标记在不同主题/选中态下的视觉可读性。

### Phase 4: 边界场景

- [ ] 删除文件：本期只让父目录显示聚合状态。
- [ ] ignored 文件不显示。
- [ ] submodule 先按普通目录处理。
- [ ] nested Git repo 只显示项目根仓库状态。
- [ ] rename 只在新路径显示 `R`。
- [ ] conflict 预留 enum 和 UI。

### Phase 5: 验证

- [ ] 👤 需要用户参与：打开 Git 仓库修改文件显示 `M`。
- [ ] 👤 需要用户参与：新建未跟踪文件显示 `?`。
- [ ] 👤 需要用户参与：`git add` 后标记仍显示具体变更。
- [ ] 👤 需要用户参与：切换项目后旧项目状态不残留。
- [ ] 👤 需要用户参与：非 Git 目录不显示标记且无报错。
- [ ] 大目录展开和滚动不触发每行 Git 查询。

---

## 8. Auto 模型路由

> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。

### Phase 1: 基础路由（最小可用）

- [ ] 新增 `AutoModelRouter`（能力过滤 + 模型强度评分）。
- [ ] 新增 `AutoModelMiddleware`。
- [ ] `LLMVM` 新增 `isAutoMode` 状态。
- [ ] `LLMRequester` 支持 Auto 配置获取。
- [ ] `ModelSelectorTab` 新增 `.auto`。
- [ ] `ChatToolbarView` 支持 Auto UI 状态（`wand.and.stars` 图标 + 实际模型名）。
- [ ] 👤 需要用户参与：验证模型选择器 Auto Tab 的 UI 文案和推荐理由展示是否合理。

### Phase 2: 历史数据驱动

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`。
- [ ] TPS 和可靠性评分生效。
- [ ] 模型选择器 Auto Tab 展示评分详情。

### Phase 3: 复杂度感知

- [ ] 消息长度分析。
- [ ] 对话轮数感知。
- [ ] 代码检测。

### Phase 4: 学习型路由

- [ ] 用户手动切换模型后调整权重。
- [ ] 路由失败自动 fallback。
- [ ] 基于对话类别的偏好学习。

### Phase 5: 成本优化

- [ ] 模型定价数据接入。
- [ ] 简单任务自动选便宜模型。
- [ ] Token 用量预算控制。

---

## 9. 多窗口支持

> 目标：让 Lumi 支持类似 VS Code 的多主窗口体验。用户可以新建空窗口、把项目打开到新窗口、把会话打开到新窗口；每个窗口拥有独立的窗口级状态，同时共享插件、设置、模型供应商、数据库和底层服务。

### 背景

当前应用已经具备一部分多窗口基础，但主窗口仍被 Scene 限制为单实例：

- `App.swift` 当前主窗口使用 `Window("Lumi", id: MainWindowID.main)`，会阻止创建第二个同 ID 主窗口。
- `ContentView` 每个 view 内部已通过 `@StateObject` 创建独立 `WindowState`，通过 `WindowManager.shared.registerWindow` 注册。
- `ContentLayout` 已支持 `conversationId` 和 `projectPath` 作为初始窗口上下文。
- `WindowManager` 已提供窗口注册、关闭、激活、广播、NSWindow 关联等能力。
- `RootContainer` 中大量 ViewModel 和服务是全局单例注入，适合共享服务，但不适合承载"当前窗口正在看的项目/会话/编辑器 tab"。

因此第一阶段不需要重写窗口管理系统，而是把主 Scene 改成可重复创建的 `WindowGroup`，并明确哪些状态属于窗口，哪些状态属于全局。

### 设计原则

- 主窗口使用 `WindowGroup`，设置窗口继续使用单例 `Window`。
- 每个主窗口拥有独立的 `WindowState`。
- 打开项目/会话到新窗口时，通过 window route 传递初始上下文。
- 全局服务继续由 `RootContainer.shared` 管理，避免一次性大改。
- 当前项目、当前会话、打开的编辑器 tab、面板布局等"用户当前视图状态"逐步迁移到窗口级状态。
- 多窗口改造分阶段推进，每个阶段都能编译和运行。
- 先支持同一进程内多窗口，不引入多进程架构。

### 窗口模型

新增轻量 route 模型，建议放在 `LumiApp/Core/Entities/LumiWindowRoute.swift`：

```swift
struct LumiWindowRoute: Codable, Hashable, Identifiable {
    var id: UUID
    var conversationId: UUID?
    var projectPath: String?
    init(id: UUID = UUID(), conversationId: UUID? = nil, projectPath: String? = nil) {
        self.id = id
        self.conversationId = conversationId
        self.projectPath = projectPath
    }
}
```

route 职责只是在创建窗口时传递初始上下文，不承担窗口运行期状态。窗口创建后运行期状态由 `WindowState` 持有。

### Scene 改造

将 `App.swift` 主窗口从 `Window` 改为 `WindowGroup`：

```swift
// 当前
Window("Lumi", id: MainWindowID.main) {
    ContentLayout().inRootView()
}
// 改为
WindowGroup("Lumi", id: MainWindowID.main, for: LumiWindowRoute.self) { route in
    ContentLayout(
        conversationId: route.wrappedValue?.conversationId,
        projectPath: route.wrappedValue?.projectPath
    ).inRootView()
}
```

设置窗口保持当前单例 `Window("设置", id: SettingsWindowID.settings)` 结构不变。

### 命令入口

新增 `LumiApp/Core/Commands/WindowCommand.swift`：

```swift
struct WindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("新建窗口") {
                openWindow(id: MainWindowID.main, value: LumiWindowRoute())
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
    }
}
```

在 `App.swift` 的 `.commands` 注册 `WindowCommand()`。后续可增加：在新窗口打开项目、在新窗口打开会话、关闭窗口、关闭其他窗口、切换到下一个窗口。

### 打开项目/会话到新窗口

新窗口入口统一调用 `openWindow`，不要让业务代码直接创建 `NSWindow`：

```swift
openWindow(id: MainWindowID.main, value: LumiWindowRoute(projectPath: path))
openWindow(id: MainWindowID.main, value: LumiWindowRoute(conversationId: conversationId))
```

注意：如果 `ConversationVM.selectedConversationId` 仍是全局状态，新窗口打开会话可能影响其他窗口。短期先接受，长期需迁移到窗口级状态。

### 状态边界

**全局状态**（继续由 `RootContainer.shared` 管理）：
- 主题和外观设置、插件注册与启用状态、LLM provider 注册表、API key 和供应商配置
- SwiftData `ModelContainer`、聊天历史数据库服务、工具执行服务
- 全局消息渲染器、应用更新、日志、菜单栏控制器

**窗口级状态**（应属于每个主窗口）：
- 当前项目路径、当前选中会话、当前激活插件面板
- rail / sidebar 展开状态、编辑器打开文件列表、编辑器当前 active tab
- 编辑器分栏布局、文件树展开状态、当前搜索条件
- 当前终端 tab 或终端工作目录、当前窗口 title

第一阶段只保证 `WindowState` 独立，后续逐步把全局 VM 中的"当前选择"字段迁移到窗口级模型。

### WindowManager 调整

1. **避免重复注销**：`closeWindow(_:)` 当前主动调用 `window.close()` 后又调用 `unregisterWindow`，而 `windowWillClose` 也会注销。多窗口后只让 `windowWillClose` 负责最终注销。
2. **新增按 ID 查找 NSWindow**：新增 `func window(for windowId: UUID) -> NSWindow?`。
3. **标题同步修复**：`ContentView.setupWindowTitleObserver()` 中查找逻辑不可靠，多窗口后会导致标题串窗。改为使用 `WindowManager.shared.window(for: windowId)` 定位窗口。

### 当前窗口识别

新增轻量 `WindowAccessor`（NSViewRepresentable），在 `ContentView` 中使用以可靠获取当前 SwiftUI view 所在的 `NSWindow`：

```swift
.background {
    WindowAccessor { window in
        WindowManager.shared.associateWindow(window, with: windowState.id)
        window.title = windowState.title
    }
}
```

避免 `NSApplication.shared.keyWindow` 在多窗口场景下指向其他窗口。

### 插件适配

多窗口后插件需要避免依赖全局"当前窗口"隐式状态，优先从环境读取窗口状态：

```swift
@Environment(\.windowState) private var windowState
```

短期兼容策略：旧插件继续使用全局 VM；新增多窗口入口只保证窗口能创建和显示；对编辑器、终端、项目文件树等强窗口相关插件逐个迁移。优先迁移：EditorPanelPlugin、EditorRailFileTreePlugin、TerminalPlugin、AgentChatPlugin、AgentNewChatPlugin、Project 相关入口。

### 验证清单

- [ ] 启动应用后默认打开一个主窗口。
- [ ] `Cmd+Shift+N` 创建第二个主窗口。
- [ ] 两个主窗口拥有不同的 `WindowState.id`。
- [ ] 切换窗口时 `WindowManager.activeWindowId` 正确变化。
- [ ] 关闭一个窗口不会误注销另一个窗口。
- [ ] 修改一个窗口标题不会影响另一个窗口。
- [ ] 打开设置始终复用同一个设置窗口。
- [ ] 新窗口可以通过 route 接收 `projectPath`。
- [ ] 新窗口可以通过 route 接收 `conversationId`。
- [ ] 多窗口下插件工具栏、ActivityBar、PanelContentView 正常渲染。

### 风险和限制

- 全局 `ConversationVM`、`ProjectVM`、`EditorVM` 仍可能导致多个窗口互相影响。
- `NSApplication.shared.keyWindow` 在多窗口中不可靠，必须避免用于绑定当前 SwiftUI window。
- 插件如果缓存了全局当前项目，需要逐个迁移。
- 多窗口恢复涉及状态持久化和启动顺序，建议单独设计。
- 本方案只覆盖单进程多窗口，如需多进程隔离需另起架构。

### 推荐落地顺序

先完成 Phase 1 和 Phase 2，让应用具备稳定的多主窗口能力。之后选择一个垂直场景打通（例如"项目列表在新窗口打开项目"），再迁移编辑器相关窗口级状态。能尽早暴露真实多窗口问题，同时避免一次性重构所有全局 ViewModel。

### Phase 1: 打开多个主窗口

- [x] 新增 `LumiWindowRoute`。
- [x] 将主 Scene 从 `Window` 改成 `WindowGroup(..., for: LumiWindowRoute.self)`。
- [x] 新增 `WindowCommand`（`Cmd+Shift+N`）。
- [x] 在 `.commands` 注册 `WindowCommand()`。
- [ ] 👤 需要用户参与：验证能创建多个主窗口且设置窗口仍然单例。

### Phase 2: 修复窗口跟踪

- [x] 新增 `WindowAccessor`（NSViewRepresentable）。
- [x] `ContentView` 使用 `WindowAccessor` 获取当前 `NSWindow`。
- [x] `WindowManager` 新增 `window(for:)`。
- [x] 修复标题同步只更新当前窗口。
- [x] 修复 `closeWindow(_:)` 避免重复注销。

### Phase 3: 项目和会话新窗口入口

- [x] 在项目入口增加「在新窗口打开」。
- [x] 在最近项目入口增加「在新窗口打开」。
- [x] 在会话列表增加「在新窗口打开」。
- [x] 使用 `openWindow(id:value:)` 统一创建窗口。

### Phase 4: 窗口级状态迁移

- [ ] 将当前选中会话迁移到 `WindowState`。
- [ ] 将当前项目迁移到 `WindowState`。
- [ ] 为每个窗口维护独立编辑器状态。
- [ ] 插件优先从 `@Environment(\.windowState)` 获取窗口上下文。
- [ ] 👤 需要用户参与：验证多窗口下状态不串（会话、项目、编辑器各自独立）。

### Phase 5: VS Code 风格行为

- [ ] 支持拖拽文件夹到 Dock/App 图标打开窗口。
- [ ] 支持从命令行参数打开项目窗口。
- [ ] 支持窗口恢复。
- [ ] 支持「打开同一项目时聚焦已有窗口」设置。
- [ ] 👤 需要用户参与：验证拖拽、命令行、窗口恢复等系统集成行为在真实环境下正常。

---

## 10. LLM Provider Kit

> 目标：将多个 OpenAI-compatible 供应商插件中重复的请求构造、消息转换、工具格式化、响应解析和 SSE 流解析逻辑提取到独立 Swift Package。

### Phase 1: 新建 Package 和测试骨架

- [ ] 新增 `Packages/LLMProviderKit/Package.swift`。
- [ ] 新增 `Sources/LLMProviderKit` 和 `Tests/LLMProviderKitTests`。
- [ ] 配置 macOS platform，添加最小 public API 和空测试。

### Phase 2: 下沉核心模型

- [ ] 将 `LLMModelCapabilities`、`LLMModelSpec`、`LLMModelCatalogItem` 移入 package。
- [ ] 将 `ChatMessage`、`ToolCall`、`StreamChunk`、`StreamEventType` 移入 package。
- [ ] 评估 `SuperAgentTool` 是否整体下沉。
- [ ] App target 引入 `LLMProviderKit`，更新引用确保编译。

### Phase 3: 实现 OpenAI-compatible 公共逻辑

- [ ] 实现 request builder。
- [ ] 实现 message transformer。
- [ ] 实现 tool formatter。
- [ ] 实现普通 response DTO 和 parser。
- [ ] 实现 SSE parser。
- [ ] 支持 provider 配置项（additional headers、stream usage options、empty chunk fallback、tool call id 策略）。

### Phase 4: 迁移第一批 Provider

- [ ] OpenAI、DeepSeek、OpenRouter 使用 `OpenAICompatibleProviderAdapter`。
- [ ] 迁移 AiRouter、FreeModel、Feifeimiao、FlyMux、HyperAPI、MegaLLM、Xiaomi、Xybbz。
- [ ] 删除每个 provider 中重复的 DTO、`transformMessage`、`formatTool`、`parseStreamChunk`。
- [ ] 保留 provider 自身 model catalog、default model、api key storage key、website URL。

### Phase 5: 清理和文档

- [ ] 删除迁移后不再使用的重复 DTO。
- [ ] 更新 provider 插件说明，记录新 provider 接入方式。
- [ ] 增加 `Packages/LLMProviderKit/README.md` 新供应商模板。
