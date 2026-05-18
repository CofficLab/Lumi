# TODO

整合自多个 todo/planning 文档，按主题分类。

---

## 1. UI Jank 调查

> 来源：`ui-jank-investigation-todo.md`
> 目标：识别并验证可能导致 UI 卡顿、掉帧或交互迟滞的代码路径。

### Priority 0: 建立基线

- [ ] 使用 Instruments Time Profiler 在以下场景运行应用：
  - [ ] 启用所有默认插件启动应用。
  - [ ] 打开主工作区并切换活动栏面板。
  - [ ] 滚动包含 Markdown 和代码块的长对话。
  - [ ] 发送消息并观察流式/工具状态更新。
  - [ ] 在 DeviceInfo/Network 插件激活时打开菜单栏弹出窗口。
- [ ] 记录 Main Thread Checker 和 SwiftUI body 更新热点。
- [x] 在高风险路径周围添加临时 signposts。
  - 已在聊天历史保存/页面/工具输出获取、QuickFileSearch 索引/搜索和 RAG 自动索引触发工作周围添加 `ui-performance` signposts。

### Priority 1: 主线程数据库工作

- [x] 检查 `ChatHistoryService.swift`（`@MainActor` 风险）。
- [x] 优化 `saveMessage` 中的单行查询（`fetchLimit = 1`）。
- [x] 用 `fetchCount` 替换 `getMessageCount` 的全量获取+内存过滤。
- [x] 优化分页加载和工具输出查询，按 `toolCallID` 查询。
- [x] 评估将 SwiftData 工作迁移到后台 actor → 决定暂缓完整迁移。

### Priority 2: 常驻监控定时器

- [x] 将 `ProcessService` 进程枚举和 CPU 计算移到后台 task。
- [x] 将 CPU tick 快照和 VM 内存统计采样移到后台 task。
- [x] 去重 `NetworkManagerViewModel` 实例（共享 VM）。
- [x] 将网络接口计数器采样移到后台 task。
- [x] 验证 DeviceInfo 菜单栏 CPU 指标不启动 top-process 扫描。
- [x] 验证 Network 菜单栏保持实时速度更新。

### Priority 3: SwiftUI Body 中的插件视图聚合

- [x] 检查 `PluginVM.swift` 的 `get...Views()` 方法。
- [x] 检查 `ContentView.swift` toolbar 和 layout body。
- [x] 验证 `StatusBar.swift` 从缓存读取。
- [x] 验证 `PanelContentView.swift`、`RailView.swift`、`BottomPanelBarView.swift` 从缓存读取。
- [x] 添加基于插件设置版本和 `activePanelIcon` 的缓存。
- [x] 决定暂缓协议迁移（61 个插件仍用 `AnyView` 回调 API）。

### Priority 4: 聊天渲染和滚动

- [x] 检查 `MessageListView.swift`。
- [x] 检查 `ScrollPositionObserver`。
- [x] 添加滚动指标回调去重/节流。
- [x] 修复同行流式更新不使用动画。
- [x] 验证 80 消息窗口行创建开销可控。

### Priority 5: Markdown 和代码高亮

- [x] 移除 Markdown 内容哈希 `.id(...)` 强制重建。
- [x] 检查 `MarkdownBlockRenderer.swift`、`HighlightedCodeView.swift`、`TreeSitterCodeHighlightProvider.swift`。
- [x] 添加有界 actor 缓存（Markdown 解析 + 代码高亮）。
- [x] 将解析/高亮工作移到后台线程。

### Priority 6: 根覆盖层和全局变更传播

- [x] 检查所有根覆盖层插件（Layout、RecentProjects、QuickFileSearch、ThemeStatusBar、AgentRAG、ModelPreference、LLMAvailability）。
- [x] 修复 RecentProjects 启动恢复在后台读取文件。
- [x] 修复 ModelPreference 项目偏好读取在后台进行。
- [x] 移除 `RootViewContainer` 的广泛 `objectWillChange` 转发。

### Priority 7: 由 UI 触发的文件/系统扫描

- [x] 修复文件树行图标不在 body 评估期间查询文件系统。
- [x] 修复 QuickFileSearch 项目索引/搜索匹配在后台运行。
- [x] 修复 AppManager 相关文件扫描可取消且防过期。
- [x] 修复 DiskManager 清理视图只在首次出现时自动扫描。
- [x] 修复 AgentRAG 自动索引触发器减少重复工作。

### 交付物

- [ ] Instruments trace 总结（主线程热点排名）。
- [x] 带文件/行引用的问题排名列表。
- [x] 按风险和预期影响分组的最小修复计划。
- [x] 回归检查清单（聊天滚动、菜单栏弹出、面板切换、应用启动）。

### 执行日志

- [x] 2026-05-14: 优化 `ProcessService` 进程采样。
- [x] 2026-05-14: 优化聊天消息计数 `fetchCount`。
- [x] 2026-05-14: 添加插件贡献视图缓存。
- [x] 2026-05-14: 去重聊天滚动指标回调。
- [x] 2026-05-14: 验证 `Packages/DeviceMonitorKit` 测试通过。
- [ ] 2026-05-14: 全量 `Lumi` scheme 构建被截图功能变更阻塞（`ScreenshotOverlay.swift` 使用不可用的 `CGDisplayCreateImage`）。
- [x] 2026-05-14: 去重网络插件 VM，移网络计数器采样到后台。
- [x] 2026-05-14: 移 CPU 和内存采样到后台。
- [x] 2026-05-14: 添加 Markdown 解析和代码高亮有界 actor 缓存。
- [x] 2026-05-14: 移除 Markdown 子树强制重建 id，减少流式自动滚动动画抖动。
- [x] 2026-05-14: 移除 `RootViewContainer` 广泛 object-change 转发。
- [x] 2026-05-14: 防止 DiskManager 视图重新出现时重复自动扫描。
- [x] 2026-05-14: QuickFileSearch 索引/搜索移出同步主 actor 路径。
- [x] 2026-05-14: AppManager 相关文件扫描添加取消和过期保护。
- [x] 2026-05-14: 减少 RAG 自动索引触发器重复工作。
- [x] 2026-05-14: 文件树 body 期间不再查询文件系统，取消过期的目录加载。
- [x] 2026-05-14: RecentProjects 根恢复文件读取移出主 actor。
- [x] 2026-05-14: ModelPreference 项目偏好读取移出主 actor。
- [x] 2026-05-14: ChatHistory 工具输出查询按请求的 toolCallID 查询。
- [x] 2026-05-14: ChatHistory 单行获取设置 `fetchLimit = 1`。
- [x] 2026-05-14: DeviceInfo 菜单栏不启动 top-process 监控。
- [x] 2026-05-14: 验证聊天行创建受分页和 80 消息窗口限制。
- [x] 2026-05-14: 暂缓 SwiftData actor 和插件描述符迁移。
- [x] 2026-05-14: 验证 `DeviceMonitorKit`（52 测试）和 `MarkdownKit`（84 测试）。
- [x] 2026-05-14: 为当前 UI jank 热路径添加 Instruments signposts。

---

## 2. 编辑器滚动卡顿修复

> 来源：`editor-scroll-jank-fix-todo.md`
> 目标：通过消除每次滚动的状态抖动、去重视口发布、延迟持久化来减少编辑器滚动卡顿。

### Phase 0: 基线和检测

- [ ] 添加临时 signposts 到编辑器滚动路径。
- [ ] 使用 Instruments Time Profiler 在不同文件大小和配置下分析。
- [ ] 记录基线指标（主线程时间、snapshot 调用频率、viewport 发布频率等）。

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
- [ ] 针对不同文件大小进行应用验证。
- [ ] 重新运行 Instruments 对比基线。
- [ ] 移除临时 signposts。

### 成功标准

- [ ] 连续滚动不再每帧触发 `activeSession.applySnapshot`。
- [ ] `LineOffsetTable` 不因滚动事件重建。
- [ ] `viewportRenderLineRange` 仅在渲染行范围变化时发布。
- [ ] 快速滚动时语义 token 视口刷新调度有界。
- [ ] Gutter/minimap 更新视觉正确。
- [ ] 滚动位置恢复仍正常工作。
- [ ] 普通和中等文件上快速滚动流畅。

---

## 3. App UI 平滑度

> 来源：`app-ui-smoothness-todo.md`
> 目标：让 Lumi 在输入、聊天流式、面板切换、主题/布局刷新等高频 UI 路径中更流畅。

### Priority 0: 基线和测量

- [ ] Instruments 测量各场景。
- [ ] 添加/复用 `UIPerformanceSignpost`。
- [ ] 记录基线指标。

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

### Priority 6: 高频日志

- [ ] 审计 `verbose: Bool = true` 在 UI 和输入路径中的使用。
- [ ] 关闭 `CommandSuggestionVM`、`InputAreaView`、`MessageListView`、`PluginVM` 的 verbose 日志。
- [ ] 将昂贵日志参数构造放在 `if Self.verbose` 后面。

### Priority 7: 输入区域布局动画

- [ ] 检查 `InputAreaView.macEditorView`。
- [ ] 仅对有意义的跨行高度变化应用动画。
- [ ] 快速输入时禁用高度动画，稳定后重新启用。

### 成功标准

- [ ] 快速输入不卡顿。
- [ ] 长 Markdown 流式更新流畅。
- [ ] 聊天自动跟随不抖动。
- [ ] 面板切换缓存预热后即时响应。
- [ ] 窗口调整大小和主题切换无明显掉帧。
- [ ] Instruments 显示输入、聊天流式和插件贡献重建路径的主线程工作减少。

---

## 4. 截图功能加固

> 来源：`screenshot-hardening-todo.md`
> 目标：提升多屏幕、错误反馈和截图准备阶段的健壮性。

### 任务

- [x] 1. 明确截图状态（增加 `isPreparing` 状态，工具栏按钮在准备阶段显示进度）。
- [x] 2. 增强错误反馈（快照失败、无屏幕、无截图数据、权限异常分别给出明确处理）。
- [x] 3. 优化多屏幕覆盖层（每个 `NSScreen` 一个 overlay window，全局坐标，绘制交集）。
- [x] 4. 坐标与裁剪稳健性（比例映射、边界裁切）。
- [x] 5. 验证（typecheck 通过，xcstrings 校验通过）。

### QA 清单

- [ ] 单屏 Retina 截图
- [ ] 外接屏截图
- [ ] 左右排列多屏截图
- [ ] 上下排列多屏截图
- [ ] 跨屏拖拽截图
- [ ] 过小选区自动取消
- [ ] ESC 取消
- [ ] 未授权屏幕录制权限
- [ ] 截图后附件预览出现并可发送

---

## 5. 文件树图标主题

> 来源：`file-tree-icon-theme-todo.md`
> 目标：让 Lumi 主题插件通过单一 `LumiThemeContribution` 配置文件树图标。

### 设计要求

- [x] 主题插件只需实现 `addThemeContributions()` 一条路径。
- [x] `LumiThemeContribution` 支持可选文件树图标贡献者。
- [x] 无图标规则时回退到内置行为。
- [x] 支持精确文件名、文件夹名、扩展名、目录开/关状态、默认图标。
- [x] 图标查找不在 SwiftUI body 评估期间添加文件系统 I/O。
- [x] 主题切换立即更新文件树图标。

### API 和内置解析器

- [x] 新增 `LumiFileIconContext`、`LumiFileIcon`、`LumiFileIconThemeContributor`。
- [x] 扩展 `LumiThemeContribution` 和 `ThemeVM`。
- [x] 将硬编码映射移到 `DefaultLumiFileIconThemeContributor` / `VscodeLikeFileIconThemeContributor`。
- [x] 定义查找优先级（精确文件夹名 > 精确文件名 > 扩展名 > 贡献者默认 > 内置回退）。

### 文件树集成

- [x] 用缓存文件元数据替换 `fileIconName`。
- [x] 通过 `themeVM.activeFileIconTheme` 解析图标。
- [x] 添加 `themeVM.currentThemeId` 作为图标解析依赖。

### 主题插件工作

- [x] 所有 16 个主题插件已提供文件图标贡献者。
- [x] 添加可复用基础类/结构体。
- [x] 初始版本所有主题使用相同图标集，但各自通过 `fileIconThemeContributor` 接入。

### 测试

- [ ] 添加精确文件名查找单元测试。
- [ ] 添加扩展名查找单元测试。
- [ ] 添加文件夹开/关图标查找单元测试。
- [ ] 添加证明回退行为与当前 `EditorFileTreeService` 映射一致的测试。
- [ ] 添加 `ThemeVM` 测试证明活跃主题暴露其文件图标贡献者。
- [ ] 添加文件树视图级别冒烟测试（如可行）。

### 迁移

- [x] 引入新模型和协议而不改变行为。
- [x] 添加镜像当前硬编码映射的默认贡献者。
- [x] 连接 `LumiThemeContribution` 和 `ThemeVM`。
- [x] 更新 `EditorFileTreeNodeView`。
- [x] 更新所有主题插件。
- [x] 保留 `EditorFileTreeService.getFileIcon` 作为兼容 shim。
- [ ] 在所有调用点迁移后移除或弃用直接文件图标映射。

### 验证记录

- [x] `xcodebuild -scheme Lumi build` 于 2026-05-15 成功。

---

## 6. Onboarding 插件选择界面

> 来源：`todo-onboarding-plugin-selection.md`
> 目标：在首次引导最后一步之前新增「选择要启用的插件」页面。

### 实现方案

在 Onboarding 第 5 页（插件系统）和第 6 页（快速开始）之间，**新增第 6 页「选择你的插件」**，原第 6 页顺延为第 7 页。

### 涉及文件

| 文件 | 改动 |
|---|---|
| `LumiApp/Plugins/AgentOnboardingPlugin/Views/OnboardingRootOverlay.swift` | 新增 OnboardingPage；底部操作栏「完成」按钮写入用户选择 |

### 详细步骤

- [ ] 新增 OnboardingPage（icon: `puzzlepiece.extension.fill`，标题: "选择你的插件"）。
- [ ] 新增 `@State private var selectedPluginIDs: Set<String>` 视图状态，初始化时从 `PluginVM` 读取可配置插件默认启用状态。
- [ ] 自定义页面内容：遍历可配置插件显示勾选列表。
- [ ] 修改 `pageContent` 用 `page.id`（建议给 `OnboardingPage` 增加 `id: String` 字段）判断是否为插件选择页。
- [ ] 修改底部操作栏：「开始使用」按钮点击时先调用 `applyPluginSelection()` 写入用户选择。
- [ ] 页面尺寸适配：插件选择页使用 `ScrollView` 或增大 sheet 高度。
- [ ] 国际化：新增本地化字符串到 `AgentOnboardingPlugin.xcstrings`。

### 注意事项

1. `PluginVM` 是 `@MainActor`，`OnboardingSheetView` 也在 MainActor，无需额外调度。
2. Onboarding 仅首次运行展示，选择结果由 `PluginSettingsVM` 持久化。
3. `AgentOnboardingPlugin` 的 `isConfigurable = false`，不会出现在可选列表。
4. 引导结束后禁用的插件 UI 扩展点应立即消失（`PluginVM` 监听 `settingsStore.$settings` 变化）。
5. 如果所有插件都不可配置，跳过插件选择页。

### 验证方式

1. 删除 onboarding state plist 重启 App 触发引导。
2. `#Preview("新手引导")` 中预览。
3. 发送 `AgentOnboarding.Show` 通知 + `reset: true` 强制展示。

---

## 7. 编辑器文件树 Git 状态标记

> 来源：`editor-file-tree-git-status-plan.md`
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

### Phase 4: 边界场景

- [ ] 删除文件：本期只让父目录显示聚合状态。
- [ ] ignored 文件不显示。
- [ ] submodule 先按普通目录处理。
- [ ] nested Git repo 只显示项目根仓库状态。
- [ ] rename 只在新路径显示 `R`。
- [ ] conflict 预留 enum 和 UI。

### Phase 5: 验证

- [ ] 打开 Git 仓库修改文件显示 `M`。
- [ ] 新建未跟踪文件显示 `?`。
- [ ] `git add` 后标记仍显示具体变更。
- [ ] 切换项目后旧项目状态不残留。
- [ ] 非 Git 目录不显示标记且无报错。
- [ ] 大目录展开和滚动不触发每行 Git 查询。

### 建议文件变更

- **新增**：`EditorFileTreeGitStatusProvider.swift`、`EditorFileTreeGitStatusModels.swift`
- **修改**：`EditorFileTreeRefreshCoordinator.swift`、`EditorFileTreeWatcher.swift`、`EditorFileTreeView.swift`、`EditorFileTreeNodeView.swift`、`GitService.swift` 或 LibGit2Swift 封装层

---

## 8. Auto 模型路由

> 来源：`auto-model-router-plan.md`
> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。

### Phase 1: 基础路由（最小可用）

- [ ] 新增 `AutoModelRouter`（能力过滤 + 模型强度评分）。
- [ ] 新增 `AutoModelMiddleware`。
- [ ] `LLMVM` 新增 `isAutoMode` 状态。
- [ ] `LLMRequester` 支持 Auto 配置获取。
- [ ] `ModelSelectorTab` 新增 `.auto`。
- [ ] `ChatToolbarView` 支持 Auto UI 状态（`wand.and.stars` 图标 + 实际模型名）。

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

> 来源：`multi-window-plan.md`
> 目标：支持类似 VS Code 的多主窗口体验。

### Phase 1: 打开多个主窗口

- [ ] 新增 `LumiWindowRoute`。
- [ ] 将主 Scene 从 `Window` 改成 `WindowGroup(..., for: LumiWindowRoute.self)`。
- [ ] 新增 `WindowCommand`（`Cmd+Shift+N`）。
- [ ] 在 `.commands` 注册 `WindowCommand()`。
- [ ] 验证能创建多个主窗口。
- [ ] 确认设置窗口仍然单例。

### Phase 2: 修复窗口跟踪

- [ ] 新增 `WindowAccessor`（NSViewRepresentable）。
- [ ] `ContentView` 使用 `WindowAccessor` 获取当前 `NSWindow`。
- [ ] `WindowManager` 新增 `window(for:)`。
- [ ] 修复标题同步只更新当前窗口。
- [ ] 修复 `closeWindow(_:)` 避免重复注销。

### Phase 3: 项目和会话新窗口入口

- [ ] 在项目入口增加「在新窗口打开」。
- [ ] 在最近项目入口增加「在新窗口打开」。
- [ ] 在会话列表增加「在新窗口打开」。
- [ ] 使用 `openWindow(id:value:)` 统一创建窗口。

### Phase 4: 窗口级状态迁移

- [ ] 将当前选中会话迁移到 `WindowState`。
- [ ] 将当前项目迁移到 `WindowState`。
- [ ] 为每个窗口维护独立编辑器状态。
- [ ] 插件优先从 `@Environment(\.windowState)` 获取窗口上下文。

### Phase 5: VS Code 风格行为

- [ ] 支持拖拽文件夹到 Dock/App 图标打开窗口。
- [ ] 支持从命令行参数打开项目窗口。
- [ ] 支持窗口恢复。
- [ ] 支持「打开同一项目时聚焦已有窗口」设置。

---

## 10. LLM Provider Kit

> 来源：`llm-provider-kit-plan.md`
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
