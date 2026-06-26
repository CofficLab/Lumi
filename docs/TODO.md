# TODO

整合自多个 todo/planning 文档，按主题分类。只列出未完成的工作。

标记说明：`👤 需要用户参与` 表示该任务需要人类操作物理设备、做主观体验判断或最终产品验收，AI 无法独立完成。

---

## 0. App UI LumiUI 化迁移

> 目标：让整个 app 的通用 UI 尽可能由 `Packages/LumiUI` 承担，app 和插件只表达业务结构、状态和少量领域特定布局。首轮审计见 `docs/lumiui-migration-audit.md`，可重复运行 `scripts/audit-lumiui-styles.sh LumiApp` 更新基线。

### Phase 3: 第一批迁移

- [ ] 迁移状态栏和菜单栏详情：DeviceInfo、NetworkManager、HistoryDB 等。
- [ ] 迁移管理类插件详情页：Git commit detail、Docker images、Model availability、GitHub plugin settings。
- [ ] 每批迁移后重新运行审计脚本，记录数量下降和剩余例外。

### 剩余逃逸点清理（LumiApp 17 处）

- [ ] `RoundedRectangle` (17 处)：Settings 页面背景裁剪，可替换为 `AppCard` 或提取为 LumiUI 修饰器
- [ ] `.font(.system(size: 38, weight: .semibold))` (4 处)：Settings 页面大数字显示，可考虑添加 `AppTypography.displayNumber` 
- [ ] `Color(hex:)` (3 处)：`MenuBarPopupView` 特定颜色，可提取为语义色
- [ ] `.foregroundColor(` (4 处)：Settings 页面主题色引用，改用 `theme.textPrimary` 等语义色

### 成功标准

- [ ] 👤 需要用户参与：深色/浅色主题各完成一轮视觉验收。

---

## 1. App UI 平滑度

> 目标：让 Lumi 在输入、聊天流式、面板切换、主题/布局刷新等高频 UI 路径中更流畅。

### 动效体验规划

- [ ] 梳理全 App 动效入口，按“导航/面板切换、列表增删、弹层、按钮反馈、状态变化、流式内容、编辑器 overlay”建立动效清单。
- [ ] 建立动效验收标准：不影响快速输入、不打断滚动、不改变焦点、不制造布局跳动、不对流式 token 更新逐帧重排。
- [ ] 👤 需要用户参与：用真实使用路径录屏评审动效节奏，确认“顺滑但不花哨”。

### Priority 0: 全局动效基建

- [ ] 为所有无限循环动画添加可见性和 reduce-motion gating，避免后台或不可见面板持续动画。（LumiUI 组件硬编码 hover/status 动画已收敛，循环动画待单独扫描）
- [ ] 增加一个轻量 `MotionDebugOverlay` 或日志开关，定位过度动画、重复动画和高频状态抖动。

### Priority 1: 主框架导航和面板切换

- [ ] 面板内容切换使用稳定身份和 `contentTransition`/opacity，避免整个树突兀重建。（已统一 Rail、主面板、底部面板 opacity transition）
- [ ] 底部面板高度变化使用受控动画；拖动/连续 resize 时禁用动画，结束后再恢复。

### Priority 2: 聊天体验动效

- [ ] 检查 `MessageListView.swift`、`StreamingAssistantRowView.swift`、`AssistantMessage.swift`、`UserMessage.swift`、`MessageWithToolCallsView.swift`。（已完成 `MessageListView`、`MessageWithToolCallsView`、`SpecialErrorView`、`ToolExecutionStatusCardView`、`ThinkingProcessView`、`MessageHeaderView`）
- [ ] 流式消息正文更新不对每个 token 做布局动画，只对“开始回答、完成回答、工具状态变化”做状态动效。

### Priority 3: 编辑器和开发者工作流动效

- [ ] 检查 `SourceEditorView.swift`、`EditorCommandPaletteView.swift`、`EditorTabHeaderView.swift`、`EditorTabItemView.swift`、`BreadcrumbNavHeaderView.swift`。（已完成 `EditorTabItemView`、`BreadcrumbNavHeaderView`、`EditorCommandPaletteView` 滚动路径）
- [ ] 编辑器 tab 新增、关闭、选中态增加稳定且不改变宽度的过渡。（已统一 hover/selection/close affordance 动效）
- [ ] Command Palette 打开/关闭、搜索结果更新使用轻量 transition；快速输入搜索时禁用列表重排动画。（已接入 selection scroll motion preference）
- [ ] 编辑器 overlay（peek、inline rename、signature help、code action）恢复后统一进入/退出动画，并确保不遮挡光标和当前行。
- [ ] 文件树/搜索结果/引用结果列表增加插入、删除、选中动效，但大结果集和批量刷新时禁用逐项动画。

### Priority 4: 弹层、Popover、Toast 和状态栏细节

- [ ] 检查 `QuickFileSearchOverlay`、`ShowImageOverlay`、`PermissionRequestView`、各 StatusBar detail popover。
- [ ] 统一 popover/detail 面板出现节奏，避免不同插件各自使用不同 spring。
- [ ] Toast、错误横幅、权限请求采用一致的 move+opacity transition，并处理重复触发队列。（已接入 `AppErrorBanner`、`PermissionRequestView`，Toast 队列待检查）
- [ ] 状态栏 loading/progress 使用统一符号动效；完成/失败时提供短促状态过渡。
- [ ] 图片预览、文件搜索、主题选择器等 overlay 关闭时保留退出动画，不直接从视图树消失。

### Priority 5: 列表、设置和插件页面

- [ ] 检查设置页、插件列表、模型选择器、会话列表、历史库、磁盘管理等长列表页面。
- [ ] 为 `List`/`LazyVStack` 行 hover、selection、展开/折叠建立统一样式。
- [ ] 搜索过滤和排序变化使用批量动画或禁用动画，避免大列表重排卡顿。
- [ ] 空状态、加载态、错误态之间增加统一 crossfade。
- [ ] 扫描进度页保留必要 loading 动效，但减少重复的自定义无限动画实现。

### Priority 6: 可访问性和性能约束

- [ ] 对输入、流式聊天、编辑器滚动、窗口 resize 等高频路径设置“默认不动画，只在状态边界动画”的规则。
- [ ] 👤 需要用户参与：在低端 Mac 或电池模式验证动效不会造成明显掉帧。
- [ ] 👤 需要用户参与：验证 VoiceOver/键盘导航下焦点不因动画丢失。

### 动效成功标准

- [ ] 主导航、面板、弹层切换都有一致且克制的过渡。
- [ ] 按钮、列表行、tab、卡片 hover/press/selection 反馈一致。
- [ ] 流式聊天和快速输入没有被动画拖慢。
- [ ] 大列表刷新、搜索、窗口 resize 不出现大面积抖动。
- [ ] Reduce Motion 生效后界面仍可理解且无突兀跳变。
- [ ] 👤 需要用户参与：完成一轮全 App 视觉走查，记录剩余不顺滑细节。

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

## 19. Editor 性能优化

> 目标：解决 Editor 相关功能的卡顿问题，提升编辑、滚动、高亮和 LSP 交互的流畅度。详细分析见 `docs/editor-performance-analysis.md`。

### Phase 1: TreeSitter 解析优化 (高优先级)

- [ ] 优化异步任务调度：使用 `Task(priority: .utility)` 替代 `.userInitiated`，降低主线程争用
- [ ] 实现增量语法树更新：只更新受影响的语法范围，避免全量重新解析
- [ ] 添加 TreeSitter 解析性能监控：记录解析时间、取消次数、异步切换次数

### Phase 2: Highlighting 延迟更新 (高优先级)

- [ ] 实现 HighlightProvider 并行处理：使用 `TaskGroup` 并行执行多个 provider 的高亮查询
- [ ] 添加高亮更新性能监控：记录更新频率、单次更新耗时、可见区域变化次数
- [ ] 优化 `StyledRangeContainer.runsIn(range:)`：缓存最近查询结果，避免重复计算

### Phase 3: LineOffsetTable 增量更新 (中优先级)

- [ ] 添加行偏移表性能监控：记录重建次数、增量更新次数、查询命中率

### Phase 4: TextLayoutManager 布局优化 (中优先级)

- [ ] 增加 View 复用池大小：从默认值增加到 200，减少视图创建开销
- [ ] 优化 `layoutLines` 循环：跳过不需要重新布局的行，减少循环迭代次数
- [ ] 实现布局结果缓存：缓存最近的布局结果，避免相同可见区域重复布局
- [ ] 添加布局性能监控：记录单次布局耗时、布局行数、视图创建/复用比例

### Phase 5: LSP 请求调度优化 (中优先级)

- [ ] 实现 LSP 请求优先级队列：区分补全、诊断、悬停等不同优先级
- [ ] 优化 debounce 策略：为不同场景（输入、滚动、文件切换）设置不同的 debounce 时间
- [ ] 添加 LSP 请求取消机制：确保取消的请求不会执行回调
- [ ] 实现 LSP 结果缓存：缓存最近的查询结果，避免相同位置重复请求
- [ ] 添加 LSP 请求性能监控：记录请求频率、响应时间、取消比例

### Phase 6: 内存泄漏修复 (高优先级)

- [ ] 实现插件 `onDisable()` 调用：确保禁用插件时清理资源
- [ ] 添加 `WindowContainer.cleanup()` 方法：窗口关闭时清理编辑器状态
- [ ] 清理 EditorSession 状态：包括 LSP 请求、定时器、观察者、缓存的 UI 状态
- [ ] 清理插件 UI 缓存：窗口关闭、插件禁用时清除 `AnyView` 缓存
- [ ] 添加内存监控：记录编辑器相关对象的生命周期、内存使用峰值

### Phase 7: EditorUndoManager 优化 (低优先级)

- [ ] 实现撤销栈大小限制：最大 100 个条目，超出时移除最旧的
- [ ] 优化撤销状态存储：只存储变化的部分，而不是完整文本快照
- [ ] 实现撤销状态压缩：合并连续的小编辑为一个撤销条目
- [ ] 添加撤销管理器性能监控：记录栈大小、内存使用、压缩次数

### Phase 8: ContextMenuManager 优化 (低优先级)

- [ ] 优化 ObjC runtime 使用：缓存方法查找结果，避免重复的 `class_replaceMethod`
- [ ] 减少关联对象查找：缓存 helper 引用，避免每次右键都查找
- [ ] 实现菜单项复用：复用已创建的 NSMenuItem，减少对象创建
- [ ] 添加右键菜单性能监控：记录菜单创建时间、注入时间、菜单项数量

### 性能监控指标

建议在 `EditorPerformance.swift` 中添加以下监控点：

```swift
case treeSitterParse = "treesitter.parse"
case highlightUpdate = "highlight.update"
case layoutCalculation = "layout.calculation"
case lspRequestQueue = "lsp.request.queue"
case memoryPressure = "memory.pressure"
case undoManagerSize = "undoManager.size"
```

### 成功标准

- [ ] 快速输入时不卡顿，保持 60fps
- [ ] 大文件（>1MB）编辑流畅，无明显延迟
- [ ] 滚动时高亮更新不掉帧
- [ ] LSP 请求响应及时，无堆积
- [ ] 长时间运行无内存泄漏，对象正确释放
- [ ] 👤 需要用户参与：在不同大小文件（小、中、大、超大）上验证编辑流畅度
- [ ] 👤 需要用户参与：长时间使用（>2小时）后验证无明显卡顿
- [ ] 👤 需要用户参与：使用 Instruments 验证主线程工作减少 40-60%

---

## 23. 编辑器架构简化与优化

> 目标：收束编辑器模块的依赖关系，消除 God Object，降低底层 API 变动对插件层的级联影响。详细分析见本次对话的架构审查。

### 现状问题

- **46% 的 Editor/LSP 插件（21/46）绕过 EditorService 门面，直接依赖底层包**（EditorKernel / EditorSource / EditorTextView / EditorLanguages）
- **EditorService.swift 874 行、80+ 公开 API**，是一个典型的 God Object
- **EditorService/Sources/Kernel/ 中有 5 个同名桥接文件**（3-6 行的 typealias/extension），增加认知负担
- **EditorKernel 包含 106 个文件**，涵盖 6+ 个独立领域，无内部目录分组
- **EditorSymbols 仅被 EditorSource 一处使用**，作为独立包维护成本过高

### Phase 1: 建立插件依赖规范，收敛底层依赖（高优先级）

> 目标：插件只依赖 `EditorService`，不再直接引用 `EditorKernel` / `EditorSource` / `EditorTextView` / `EditorLanguages`。

#### 1.1 EditorService Proto 层增加类型桥接


#### 1.2 逐批迁移 LSP 插件（纯模型依赖，风险最低）


#### 1.3 迁移需要 TextView 的 LSP 插件（中风险）


#### 1.4 迁移语言/功能插件


#### 1.5 迁移核心 UI 插件


### Phase 2: 拆分 EditorService 门面（高优先级）

> 目标：将 874 行的 God Object 拆分为职责清晰的子门面。


### Phase 3: 清理 EditorService/Kernel 桥接层（中优先级）

> 目标：消除 5 个同名文件的冗余间接层。


### Phase 4: EditorKernel 内部目录分组（中优先级）

> 目标：将 106 个扁平文件按领域分组到子目录，提升可读性和导航效率。


### Phase 5: EditorSymbols 合并到 EditorSource（低优先级）

> 目标：减少一个独立 Package，简化依赖树。


### 成功标准


---

## 20. 文件树图标主题

> 目标：让 Lumi 主题插件通过单一 `LumiThemeContribution` 配置文件树图标。

- [ ] 添加精确文件名查找单元测试。
- [ ] 添加扩展名查找单元测试。
- [ ] 添加文件夹开/关图标查找单元测试。
- [ ] 添加证明回退行为与当前 `EditorFileTreeService` 映射一致的测试。
- [ ] 添加 `ThemeVM` 测试证明活跃主题暴露其文件图标贡献者。
- [ ] 添加文件树视图级别冒烟测试（如可行）。
- [ ] 在所有调用点迁移后移除或弃用直接文件图标映射。

---

## 3. Onboarding 插件选择界面

> 涉及文件：`Plugins/PluginAgentOnboarding/Sources/PluginAgentOnboarding/Views/OnboardingRootOverlay.swift`

- [ ] 👤 需要用户参与：验证首次引导流程的视觉和交互体验（删除 onboarding state plist 重启 App 触发）。

---

## 4. 编辑器文件树 Git 状态标记

> 目标：在文件树中实现类似 Xcode 的 Source Control 状态标记。

### Phase 1: 模型和 Provider

- [ ] 添加 provider 单元测试（modified、added/untracked、deleted、staged + unstaged 同文件、nested directory aggregate）。

### Phase 2: Coordinator 接入

- [ ] 增加 `.git` 元数据监听（index、HEAD、refs/heads、MERGE_HEAD、rebase-merge）。

### Phase 3: UI 标记

- [ ] 👤 需要用户参与：验证标记在不同主题/选中态下的视觉可读性。

### Phase 5: 验证

- [ ] 👤 需要用户参与：打开 Git 仓库修改文件显示 `M`。
- [ ] 👤 需要用户参与：新建未跟踪文件显示 `?`。
- [ ] 👤 需要用户参与：`git add` 后标记仍显示具体变更，样式可体现 staged。
- [ ] 👤 需要用户参与：切换项目后旧项目状态不残留。
- [ ] 👤 需要用户参与：非 Git 目录不显示标记且无报错。
- [ ] 👤 需要用户参与：通过 Xcode / 终端 / Lumi 自身修改文件，标记自动刷新。

---

## 5. Auto 模型路由

> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。

### 测试与验证

- [ ] 编写单元测试：可用性 Store 并发写入安全性、状态查询准确性
- [ ] 编写单元测试：路由过滤逻辑、评分排序、边界场景（无可用模型、所有模型不支持工具等）
- [ ] 验证：插件禁用后内核 Store 为空，App 正常运行（Auto 路由退化为默认行为）

### UI 完善

- [ ] Auto Tab 展示评分详情（模型强度、TPS、可靠性、推荐原因）
- [ ] 👤 需要用户参与：验证模型选择器 Auto Tab 的 UI 文案和推荐理由展示是否合理

### Phase 6: 历史数据驱动

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`（已在内核中）
- [ ] TPS 评分生效
- [ ] 可靠性评分生效（成功率、平均延迟）
- [ ] 模型选择器 Auto Tab 展示历史评分详情

### Phase 7: 复杂度感知

- [ ] 对话轮数感知（多轮复杂对话偏向强模型）

### Phase 8: 学习型路由

- [ ] 用户手动切换模型后调整对应模型权重（持久化到 UserDefaults）
- [ ] 路由失败时自动 fallback 到下一个候选模型
- [ ] 基于对话类别的偏好学习

### Phase 9: 成本优化

- [ ] 模型定价数据接入（供应商声明或配置文件）
- [ ] 简单任务自动选便宜模型
- [ ] Token 用量预算控制

---

## 7. 编辑器文件树 Package Dependencies

> 目标：在文件树底部显示类似 Xcode 的 Swift Package Dependencies 列表。

### Phase 1: 数据模型与解析

- [ ] `EditorPackageDependency.swift`（identity, displayName, location, kind, version, branch, revision, status）
- [ ] `EditorPackageResolved.swift`（Xcode v1 + SwiftPM v2 格式解析）
- [ ] `EditorXcodePackageReferenceParser.swift`（解析 project.pbxproj 中的包引用）
- [ ] `EditorPackageDependencyResolver.swift`（项目类型检测、resolved 文件定位、路径解析）

### Phase 2: Store 与刷新

- [ ] `EditorPackageDependencyStore.swift`
- [ ] 扩展 `EditorFileTreeStore.swift`（持久化展开状态）
- [ ] 刷新触发：项目路径变化、view appear、pbxproj 变化、Package.resolved 变化

### Phase 3: UI

- [ ] `EditorPackageDependencySection.swift`
- [ ] `EditorPackageDependencyRow.swift`
- [ ] 集成到 `EditorFileTreeView.swift`

### Phase 4: 基础交互

- [ ] 右键菜单：Reveal in Finder、Copy URL/path、Open in Terminal
- [ ] 错误处理：Retry refresh、Copy diagnostic text

### Phase 5: 展开包内容

- [ ] `EditorPackageDependencyNode.swift`
- [ ] Lazy-load package children on expand
- [ ] 持久化已展开的 package identity

### Phase 6: Resolve / Update 命令

- [ ] `EditorPackageCommandService.swift`（xcodebuild / swift package 命令封装）
- [ ] UI actions: Resolve Packages、Update Packages

### Phase 7: 测试

- [ ] Parser tests、Resolver tests、UI verification

### Phase 8: 后续增强

- [ ] Version update checking、Dependency graph、Package size analysis

---

## 8. Motrix 下载管理插件

> 目标：以插件形式提供 Motrix 等价的下载管理能力（HTTP/HTTPS、BitTorrent、Magnet）。

### V1 Scope

- [ ] Create `Plugins/PluginMotrixDownload/Sources/PluginMotrixDownload/`
- [ ] 插件元数据、面板入口、设置入口
- [ ] HTTP/HTTPS 下载、任务列表、暂停/恢复/移除/重试
- [ ] 全局下载速度显示、下载目录设置、全局限速、完成通知

### Aria2 Runtime

- [ ] 内置 aria2c 二进制资源管理（首次运行复制到可写目录）
- [ ] 确保可执行权限、aria2.session 管理、优雅退出
- [ ] 开发环境外部 aria2c 路径回退

### RPC Security

- [ ] 绑定 127.0.0.1、动态端口、RPC 密钥管理
- [ ] 端口冲突和启动失败的 UI 错误状态

### Models & Services

- [ ] DownloadTask、TransferStats、Error models
- [ ] Aria2Service：进程启动、JSON-RPC 客户端、核心 RPC 方法
- [ ] DownloadManagerViewModel：后台任务聚合、全局速度汇总

### UI

- [ ] DownloadManagerView、task row、empty state、URL 输入流程
- [ ] DownloadSettingsView、GlassCard/AppTheme 风格

### Settings

- [ ] downloadDirectory、maxConcurrentTasks、defaultUserAgent、speedLimitGlobal

### Tests & Packaging

- [ ] 单元测试、集成测试
- [ ] aria2c 打包签名、Apple Silicon 兼容、Entitlements 确认

### V2+ (BT/Magnet/Advanced)

- [ ] Magnet URI、.torrent 文件导入、选择性文件下载
- [ ] Tracker 自动更新、FTP、每任务限速、UPnP/NAT-PMP

---

## 9. CodeReview Plugin

> 目标：审查当前 Git 变更，报告可操作问题。

### Phase 6: Status Bar UI

- [ ] `ReviewStatusBarView.swift`
- [ ] 显示审查状态、问题计数（按 severity 着色）
- [ ] 使用 `StatusBarHoverContainer` 弹出报告

### Phase 7: Report Popover

- [ ] `ReviewReportPopover.swift`
- [ ] 展示报告摘要、评分、diff 统计
- [ ] 按 severity 分组、展示修复建议
- [ ] Rerun review、Copy report、Open file 操作

### Phase 8: Plugin Entry

- [ ] Register status bar view
- [ ] Add localization file for user-facing strings

### Phase 9: PR Description Support

- [ ] 从 diff、commit log、review report 生成 PR 标题和正文
- [ ] 支持常规章节（summary、changes、tests、risks、review notes）

### Phase 10: Tests

- [ ] 单元测试：模型解析、LLM JSON、confidence 降级、diff 截断
- [ ] Tool tests for `run_review`、Store persistence tests

---

## 11. ErrorDoctor Plugin

> 目标：自动监听构建/测试/运行时错误，由 Agent 分析根因并生成修复方案。

### Phase 1: 错误监听与解析

- [ ] 定义 ErrorReport 数据模型
- [ ] 实现 ErrorListener: Shell 输出捕获与 Regex 提取
- [ ] 支持 Swift Compiler / xcodebuild 错误格式

### Phase 2: 诊断与分析

- [ ] 实现 ErrorAnalyzer: LLM 诊断 Prompt 构建与结果解析
- [ ] 实现 FixGenerator: 生成 CodePatch
- [ ] 错误知识库 (JSON 存储)

### Phase 3: 工具与中间件

- [ ] 实现 DiagnoseTool / ApplyFixTool
- [ ] 实现 ErrorContextMiddleware (Order: 40)

### Phase 4: UI 开发

- [ ] 实现 ErrorStatusBarView
- [ ] 实现 ErrorReportPopover: 错误详情和 Apply Fix 按钮
- [ ] Diff 预览与确认交互

### Phase 5: 优化与扩展

- [ ] 支持更多语言/编译器
- [ ] 测试失败自动重试机制

---

## 12. FocusGroup Plugin

> 目标：模拟一批虚拟用户对内容给出个性化反馈，自动汇总统计。

### Phase 1: 数据模型与画像存储

- [ ] 定义 Persona、PersonaTag、SimulationQuestion、SimulationResult
- [ ] 实现 PersonaStore (Actor): CRUD、持久化、默认数据加载
- [ ] 创建 DefaultPersonas.json (8-12 个典型用户)

### Phase 2: 模拟引擎

- [ ] 实现 SimulationEngine: Prompt 构建、LLM 并行调用 (TaskGroup)
- [ ] LLM Response 解析
- [ ] 支持 6 种预设场景 + 自定义场景
- [ ] 实现 ResultAggregator: 统计计算 + 关键洞察提取

### Phase 3: Agent 工具

- [ ] 实现 FocusGroupTool: focus_group_simulate 注册

### Phase 4: 面板 UI

- [ ] 实现 FocusGroupPanelView、SimulationInputView、SimulationResultView
- [ ] 实现 PersonaListView、PersonaEditorView

### Phase 5: 设置与优化

- [ ] 设置视图、结果持久化、导入/导出画像配置

---

## 13. GitHubInsight Plugin

> 目标：分析项目技术栈，异步搜索 GitHub 发现相关开源项目、替代方案和最佳实践。

- [ ] gh CLI 降级方案、请求队列 + 限流

---

## 14. GoEditorPlugin

> 目标：对 Go 项目提供接近 VS Code + Go 扩展的开发体验。

### Phase 1: LSP 基础


### Phase 2: 工程命令


### Phase 3: 测试系统


### Phase 4: 体验打磨


### Phase 5: 调试系统


---

## 17. VueEditorPlugin

> 目标：对 Vue 3 SFC 提供原生般的单文件组件编辑体验。

### Phase 1: Volar 集成与基础 SFC 支持

- [ ] VolarServiceManager、VueVersionDetector
- [ ] 混合模式配置、VueTreeSitterRegistration

### Phase 2: SFC 编辑器增强

- [ ] SFCBlockHighlighter、TemplateAttributeCompleter
- [ ] 区块导航命令

### Phase 3: 高级特性与重构

- [ ] ComponentImportResolver、ScopedStyleHelper
- [ ] ComponentRenamer、CSSModulesTypeGenerator

### Phase 4: 调试与工具链

- [ ] Vue DevTools 桥接、Vite 联动优化

---

## 18. EditFileTool 改进

> 目标：借鉴 Claude Code 的 FileEditTool 实现，提升 Lumi 的文件编辑工具的安全性和用户体验。
> 分析来源：Claude Code 源码研究 (`claude-code/src/tools/FileEditTool/`)

### Priority 0: 安全性改进（必须）

- [ ] **先读后写强制校验**：维护 `ReadFileState` 字典，记录哪些文件已被读取、时间戳和内容。`edit` 方法强制检查文件是否已读取，未读取则拒绝编辑。
- [ ] **并发修改检测（乐观锁）**：编辑前比对文件修改时间戳，如果文件在读取后被外部修改（用户手动编辑、linter、cloud sync），拒绝编辑并提示重新读取。
- [ ] **文件大小保护**：限制编辑文件不超过 1GB，防止 OOM。检查 `FileManager.attributesOfItem(.size)`。

### Priority 1: 用户体验改进（重要）

- [ ] **引号风格保留（`preserveQuoteStyle`）**：匹配时做了引号标准化（弯引号→直引号），替换时应自动将 `new_string` 中的引号也转换为弯引号，保持文件风格一致。需正确处理缩写（如 `don't`）。
- [ ] **Diff 生成质量**：当前手写的逐行比较存在逻辑问题（`+`/`-` 和空格标记混合不正确）。建议：
  - 方案 A：调用系统 `/usr/bin/diff -u` 生成 unified diff
  - 方案 B：引入 Swift diff 库（DifferenceKit / SwiftDiff）
  - 方案 C：使用 LCS 算法重写
- [ ] **编辑器/LSP 通知**：编辑完成后通知 `EditorKernel`，触发编辑器状态更新和 LSP 诊断（didChange + didSave）。

### Priority 2: 边缘场景支持（可选）

- [ ] **编码检测**：当前只支持 UTF-8。读取文件时检测 BOM，支持 UTF-16LE 编码。保留原文件编码和换行符风格（LF/CRLF）写入。
- [ ] **相似文件提示**：文件不存在时，自动搜索相近文件名（不同扩展名），给出 "Did you mean xxx?" 建议。例如 `Foo.swift` 不存在时提示 `FooTests.swift`。
- [ ] **反标准化机制**：处理 LLM API 对特殊 XML 标签的清理（如 `<function_results>` → `<fnr>`）。建立反标准化映射表，匹配前还原。

### 实现参考

Claude Code `FileEditTool` 核心文件结构：
```
FileEditTool/
├── FileEditTool.ts    # 主入口：validateInput + call
├── prompt.ts          # 工具描述/Prompt
├── types.ts           # Zod Schema + TS 类型
├── utils.ts           # findActualString + preserveQuoteStyle + getPatchForEdit
├── constants.ts       # 错误常量
└── UI.tsx             # 结果渲染
```

关键实现要点：
1. `validateInput` 中有 10+ 种校验（errorCode 0-10），包括文件是否已读、是否被外部修改
2. `readFileState` 存储已读文件的内容和时间戳，用于乐观并发控制
3. `findActualString` 先精确匹配，失败后做引号标准化再匹配，返回文件中实际字符串
4. `preserveQuoteStyle` 根据匹配结果将新字符串的引号风格转换为文件原有风格
5. `call` 方法在 `await fs.stat()` 和 `writeTextContent()` 之间避免任何异步操作，保证原子性

### 成功标准

- [ ] LLM 不读取文件直接编辑会被拒绝，错误信息清晰
- [ ] 用户在 Lumi 读取后手动修改文件，Lumi 会提示重新读取而非覆盖
- [ ] 编辑包含弯引号的文件后，文件保持弯引号风格
- [ ] Diff 输出格式正确，显示删除行（`-`）和新增行（`+`）
- [ ] 编辑后编辑器 UI 立即更新，LSP 诊断刷新
- [ ] 👤 需要用户参与：验证并发编辑场景（同时用外部编辑器修改）

---

## 19. 插件 Panel API 重构

> 目标：将 `addPanelIcon()` 和 `addPanelView()` 合并为 VS Code 风格的 `addViewContainer()`，统一命名，简化插件开发。

### 任务 1: 合并 API

  ```swift
  struct ViewContainerItem: Identifiable {
      let id: String
      let title: String
      let icon: String
      let makeView: @MainActor () -> AnyView  // 闭包，延迟创建视图
  }
  ```
  - `getPanelIconItems()` → `getViewContainerItems()`
  - `getActivePanelItem()` → `getActiveViewContainer()`

### 任务 2: 统一 VS Code 风格命名

  | VS Code | Lumi |
  |---------|------|
  | Activity Bar | ActivityBar |
  | View Container | ViewContainerItem |
  | `viewsContainers.activitybar` | `addViewContainer()` |

### 影响范围

- `SuperPlugin.swift` — 协议定义和默认实现
- `AppPluginVM.swift` — 类型定义、聚合方法、缓存逻辑
- `ActivityBar.swift` (LeftBar.swift) — 图标渲染
- `PanelContentView.swift` — 面板视图展示
- `WindowLayoutVM.swift` — `activePanelIcon` → `activeViewContainerIcon`
- 所有已实现 `addPanelIcon()` 和 `addPanelView()` 的插件

---

## 20. 多窗口作用域重构 — 收尾

> WindowContainer 架构已全部落地。剩余少量代码清理和集成验证。

### 代码清理

- [ ] 清理 `AgentTurnNotificationOverlay.swift` 中 `RootContainer.shared.conversationVM` 直接访问，改为通过 environment 或 WindowContainer 获取
- [ ] 清理 `SplitViewPersistence.swift` 中 `RootContainer.shared.layoutVM` 直接访问（2处），改为通过 environment 或 WindowContainer 获取

### 集成验证

- [ ] 👤 需要用户参与：多窗口各自选中不同会话，各自发消息不串窗口
- [ ] 👤 需要用户参与：两个窗口同时请求工具权限，弹窗不冲突
- [ ] 👤 需要用户参与：窗口 A 发送长任务，窗口 B 同时发消息，两者互不阻塞
- [ ] 👤 需要用户参与：窗口 A 取消任务不影响窗口 B
- [ ] 👤 需要用户参与：关闭窗口后 VM 和 Controller 自动释放（Instruments 内存验证）
- [ ] 👤 需要用户参与：重启 App 后窗口状态正确恢复（会话、项目、布局）

---

## AutoTask 任务编辑

> 目标：对于未做的任务（`pending` 状态），允许用户在侧栏 UI 中直接编辑任务的标题和描述，而不仅由 Agent 通过工具操控。

### 需求说明

当前 AutoTask 插件的任务（`TaskItem`）只能由 Agent 通过 `CreateTaskTool`、`UpdateTaskTool`、`AppendTaskTool` 等工具创建和修改。用户在侧栏 `AutoTaskSidebarView` 中只能查看任务列表和进度，无法手动编辑任何任务内容。

需要新增的能力：对于状态为 `pending` 的任务，用户可以在 `TaskRowView` 上通过双击或右键菜单触发编辑，修改 `title` 和 `detail` 字段。

### 任务

#### Phase 1: 数据层

- [ ] `TaskStateManager` 新增 `updateTaskContent(id:conversationId:title:detail:)` 方法，仅允许 `pending` 状态的任务被编辑
- [ ] 编辑完成后发送 `autoTaskDidChange` 通知刷新 UI

#### Phase 2: ViewModel

- [ ] `AutoTaskSidebarViewModel` 新增编辑状态管理：`editingTaskId`、`editingTitle`、`editingDetail`
- [ ] 提供 `startEditing(_ task:)` / `confirmEditing()` / `cancelEditing()` 方法
- [ ] `confirmEditing()` 调用 `TaskStateManager.updateTaskContent()` 并刷新列表

#### Phase 3: UI

- [ ] `TaskRowView` 支持 `pending` 任务双击进入内联编辑模式（TextEditor/TextField 替代 Text）
- [ ] 编辑模式下显示确认（✓）和取消（✗）按钮
- [ ] 非 `pending` 状态的任务不响应编辑交互，视觉上可适当区分（如已完成的任务标题置灰）
- [ ] 支持按 Enter 确认、Escape 取消的键盘快捷操作

#### Phase 4: 右键菜单（可选增强）

- [ ] `pending` 任务右键菜单增加"编辑任务"选项
- [ ] 非 `pending` 任务右键菜单不显示"编辑任务"选项

### 成功标准

- [ ] `pending` 状态任务可双击编辑标题和描述，修改立即持久化并刷新 UI
- [ ] `in_progress` / `completed` / `skipped` 状态任务不可编辑
- [ ] 编辑中途切换会话或关闭侧栏不丢失已有任务数据
- [ ] 👤 需要用户参与：验证编辑交互手感流畅，无明显延迟

---

## 21. 插件注册策略重构

> 目标：将当前 `enable` 属性身兼两职（扫描门槛 + 默认开关状态）的问题，拆分为语义清晰的三层策略，让每个插件精确控制「是否注册 → 是否可配置 → 默认开关」。

### 当前问题

`enable` 同时承担两个职责：
1. **扫描门槛**：`enable=false` 的插件在 `autoDiscoverAndRegisterPlugins()` 中直接被跳过，不会进入 `plugins` 列表
2. **默认开关**：`isConfigurable=true` 时，`enable` 作为用户未配置过时的默认启用状态

这导致 `enable=false` + `isConfigurable=true` 自相矛盾——插件根本不会被加载，用户连设置页面都看不到它。

### 新的三层策略

| 属性 | 类型 | 默认值 | 含义 |
|------|------|--------|------|
| `shouldRegister` | `Bool` | `true` | **第一关**：是否注册插件。`false` = 完全不存在，扫描阶段直接跳过 |
| `isConfigurable` | `Bool` | `false` | **第二关**：是否允许用户配置。`false` = 注册后直接启用，用户无权切换 |
| `enabledByDefault` | `Bool` | `true` | **第三关**：仅当 `isConfigurable=true` 时有意义，控制用户未配置时的初始开关状态 |

典型组合：

| shouldRegister | isConfigurable | enabledByDefault | 效果 | 适用场景 |
|---|---|---|---|---|
| `false` | — | — | 完全不加载 | 开发中/废弃的插件 |
| `true` | `false` | — | 始终启用，用户看不到开关 | 核心插件（Editor、Chat） |
| `true` | `true` | `true` | 可配置，默认启用 | 大多数功能插件 |
| `true` | `true` | `false` | 可配置，默认不启用 | 可选插件（AppStore、Docker） |

### 任务

#### Phase 1: 核心协议改造

- [ ] 在 `SuperPlugin+Defaults.swift` 中添加 `shouldRegister` 和 `enabledByDefault` 默认实现，均返回 `true`
- [ ] 在 `SuperPlugin.swift` 协议中声明 `shouldRegister` 和 `enabledByDefault` 属性
- [ ] 保留 `enable` 属性，标记 `@available(*, deprecated, message: "Use enabledByDefault")`，默认实现转发到 `enabledByDefault`

#### Phase 2: 加载逻辑升级

- [ ] 更新 `AppPluginVM.autoDiscoverAndRegisterPlugins()`：用 `shouldRegister` 替代 `enable` 作为扫描门槛
- [ ] 更新 `AppPluginVM.isPluginEnabled()`：用 `enabledByDefault` 替代 `enable` 作为用户未配置时的默认值
- [ ] 更新设置页中读取默认值的逻辑（`PluginSettingsView`、`PluginCategorySettingsView`）

#### Phase 3: 插件迁移

- [ ] 搜索所有插件的 `enable` 属性，按语义迁移到 `shouldRegister` 或 `enabledByDefault`
- [ ] `AppStoreConnectPlugin`：`shouldRegister=true, isConfigurable=true, enabledByDefault=false`（默认不启用，用户可在设置中开启）
- [ ] 其他当前 `enable=false` 的插件（`HostsManagerPlugin`、`MenuBarManagerPlugin`、`NettoPlugin`、`DatabaseManagerPlugin`、`EditorStickySymbolBarPlugin`）：确认为"开发中"还是"可选功能"，分别设置 `shouldRegister=false` 或 `enabledByDefault=false`
- [ ] 清理所有插件中对旧 `enable` 属性的引用

#### Phase 4: 清理

- [ ] 确认所有插件迁移完毕后，移除 `enable` 属性（或保留 deprecated 默认实现一个版本周期）
- [ ] 更新插件开发文档

### 成功标准

- [ ] 插件属性语义清晰：`shouldRegister` 控制注册，`enabledByDefault` 控制默认开关
- [ ] `AppStoreConnectPlugin` 默认不启用，但用户可在设置中看到并开启
- [ ] 所有原有 `enable=false` 的插件行为不变
- [ ] 不存在 `shouldRegister=false` + `isConfigurable=true` 的矛盾组合

---

## 22. search_code 工具性能优化

> 目标：解决 `search_code` agent tool 偶发运行 10+ 分钟无响应的问题。
> 分析来源：`Packages/RAGKit` 和 `Plugins/PluginAgentRAG` 源码审查。
> 涉及文件：`RAGFileScanner.swift`、`RAGCodeSearchTool.swift`、`RAGRetriever.swift`、`RAGSQLiteStore.swift`

### 根因分析

| 排序 | 根因 | 位置 | 影响 |
|------|------|------|------|
| 1 | `temp/` 目录未被跳过 | `RAGFileScanner.skipDirectories` | 枚举 27,306 个无关文件（占总量 69%） |
| 2 | keywordSearch 同步逐文件读取 | `RAGCodeSearchTool.keywordSearch` | 每次搜索重新遍历全量文件，无缓存 |
| 3 | sqlite-vec 不可用时回退到 Swift 全量余弦计算 | `RAGSQLiteStore.detectRuntimeInfo` | 最多加载 7,000 chunks 逐个计算相似度 |

### Phase 1: 修复文件发现（高优先级）

- [ ] **扩展 `skipDirectories`**：在 `RAGFileScanner.swift` 中将 `temp` 加入 `skipDirectories` 集合，避免扫描项目根目录下的 `temp/` 目录（含 27,306 个无关文件）
- [ ] **模糊匹配 DerivedData 变体**：`shouldSkipPath` 当前使用精确匹配 `DerivedData`，无法跳过 `DerivedData-Lumi-Multilang`、`DerivedData-Lumi-PluginDescriptionLocalization` 等变体目录。改为前缀匹配或正则匹配 `DerivedData.*`
- [ ] **审查是否需要扫描 `SourcePackages`**：`build/SourcePackages` 目录包含 22,221 个文件（5,976 个 swift/m/h）。虽然当前 `build` 已在 skip 列表中，但需确认不会被其他路径引入。如项目根目录存在独立的 `SourcePackages/`，也应加入跳过列表
- [ ] **添加单元测试**：验证 `discoverFiles` 在含 `temp/`、`DerivedData-*`、`SourcePackages/` 等目录的 mock 项目中不会返回这些目录下的文件

### Phase 2: keywordSearch 性能优化（高优先级）

- [ ] **缓存 discoverFiles 结果**：`discoverFiles` 每次调用都重新遍历整个目录树。在 `RAGCodeSearchTool` 中添加短期缓存（如 5 分钟 TTL），避免同一项目短时间内重复枚举
- [ ] **替换为 grep 子进程**：当前 `keywordSearch` 逐个加载文件到内存并执行 `String.range(of:)`。改为调用 `/usr/bin/grep -rn --include='*.swift' --include='*.h' ...` 子进程，利用 grep 的 C 实现和 mmap 优化，速度可提升 10-100 倍。注意保持 `ToolExecutionContext.checkCancellation()` 的调用以支持任务取消
- [ ] **添加超时保护**：为 keywordSearch 添加可配置超时（建议 30 秒），超时后返回已有结果并附带超时提示

### Phase 3: semanticSearch 优化（中优先级）

- [ ] **确认 sqlite-vec 可用性**：检查 `RAGSQLiteStore.detectRuntimeInfo` 的运行时日志，确认 vector backend 是否为 `.sqliteVec`。如果是 `.swiftCosine`，说明 sqlite-vec 扩展加载失败
- [ ] **sqlite-vec 加载失败时的用户提示**：当 sqlite-vec 不可用时，在 RAG 状态栏中显示警告，告知用户 semantic 搜索性能会下降
- [ ] **降低 fallback chunk 数量上限**：`loadCandidateChunks` 的 `fallbackLimit` 为 7,000。在 swiftCosine 回退模式下，应降低到 1,000-2,000，避免大量余弦计算导致超时
- [ ] **ANN 检索添加超时**：`RAGRetriever.retrieve` 中为 `loadANNCandidates` 和 fallback 路径分别添加超时保护

### Phase 4: 整体可观测性（低优先级）

- [ ] **为 keywordSearch 添加日志**：当前 `keywordSearch` 完全没有耗时日志。添加 `discoverFiles` 耗时、文件读取数量、匹配数量等日志（参考 `semanticSearch` 的日志风格）
- [ ] **添加性能预警阈值**：当 `keywordSearch` 耗时 > 5 秒或 `semanticSearch` 耗时 > 3 秒时，输出 warning 级别日志
- [ ] **RAG 状态栏展示搜索耗时**：在 `RAGStatusBarView` 中展示最近一次 search_code 的 keyword/semantic 各自耗时，便于用户判断性能问题

### 成功标准

- [ ] `search_code` 在 Lumi 项目（180+ packages）上的 keyword 搜索响应时间 < 5 秒
- [ ] `search_code` 的 semantic 搜索在索引已就绪时响应时间 < 3 秒
- [ ] `temp/`、`DerivedData-*` 等无关目录不再出现在搜索结果的扫描路径中
- [ ] 用户无需手动配置即可获得合理的搜索性能
- [ ] 👤 需要用户参与：在 Lumi 项目上分别测试 keyword、semantic、hybrid 三种模式的响应时间

---

## 24. 编辑器文件树 UI 流畅度优化

> 目标：让 `EditorFileTreePlugin` 的文件树在大项目、批量刷新、快速展开/折叠等高频路径下保持流畅，避免整树重建和无效磁盘 I/O。
> 分析来源：`Plugins/EditorFileTreePlugin` 与 `Packages/FileTreeKit` 源码审查。
> 涉及文件：`EditorFileTreeNodeView.swift`、`EditorFileTreeView.swift`、`EditorFileTreeRefreshCoordinator.swift`、`EditorFileTreeGitStatusProvider.swift`、`FileTreeWatcher.swift`、`FileTreeStore.swift`

### 根因分析

| 排序 | 根因 | 位置 | 影响 |
|------|------|------|------|
| 1 | 节点视图未实现 `Equatable` | `EditorFileTreeNodeView` + `ForEach(children)` | 每次 `refreshToken` 变化，整棵展开树所有节点 `body` 全量重新求值 |
| 2 | 刷新令牌 `onChange` 让每个节点都重载子项 | `EditorFileTreeNodeView.body` 的 `.onChange(of: refreshToken)` | 所有已展开目录都重新 `loadContents` 做磁盘 I/O，即使自身未变 |
| 3 | watcher 已知变化目录却被丢弃，改全量刷新 | `handleDirectoryChanged` 丢弃 `url`，`triggerRefresh` 全量 +1 | 精准刷新信息丢失，放大 #1/#2 的重建成本 |
| 4 | 刷新防抖固定 0.3s，首帧延迟 | `debounceInterval = 300_000_000` | `git checkout`、`npm install` 等持续刷盘场景观感迟钝 |
| 5 | `body` 每次都 `new` icon contributor + 重算 `gitRelativePath` | `resolvedIcon`、`currentGitStatus` | 配合全量重建，每个可见节点每次刷新都重复分配和路径标准化 |
| 6 | 多处 `AnyView` 包裹阻断 SwiftUI diff 优化 | `EditorFileTreeNodeView`/`EditorPackageDependencyRow`/`EditorPackageDependencySection` 的 `body` | 强制动态派发，递归树里成本放大 |
| 7 | 展开状态每次增删都全量读写 plist | `FileTreeStore.addExpandedPath/removeExpandedPath` | 连续展开含几十个子目录的大目录时触发几十次原子磁盘写 |
| 8 | `visibleOrder` 数组 + O(n) `removeAll` | `EditorFileTreeSelectionState.untrackVisible` | 快速滚动时每行消失 O(n) 扫描 |

### Phase 1: 消除整树全量重建（高优先级，收益最大）

- [ ] **为 `EditorFileTreeNodeView` 实现 `Equatable`**：定义 `static func ==`，比较 `url / isExpanded / children / 选中态 / gitStatusSnapshot / refreshToken`；在递归 `ForEach` 处用 `.equatable()` 包裹，让未变化的子节点跳过 `body`
- [ ] **在 `init` 缓存 `gitRelativePath`**：仿照已有 `iconMetadata` 的做法，把 `currentGitStatus` 依赖的相对路径一次性算好，避免 `body` 里反复跑 `EditorFileTreePathFormatter.gitPath` → `standardizingPath`
- [ ] **去掉 `body` 中的 `AnyView`**：`EditorFileTreeNodeView`、`EditorPackageDependencyRow`、`EditorPackageDependencySection` 改用 `@ViewBuilder`，让 SwiftUI 走静态 diff

### Phase 2: 精准刷新，消除无效 I/O（高优先级）

- [ ] **透传 watcher 的变化目录**：`FileTreeWatcher` 回调已带 `url`，让 `EditorFileTreeRefreshCoordinator` 把变更路径集合随 `refreshToken` 下发，节点仅在自己或后代目录命中时才 `reloadChildren`
- [ ] **缩小节点 `.onChange(of: refreshToken)` 的副作用**：仅命中变更的节点重载，其余节点只靠 `Equatable` 跳过
- [ ] **刷新防抖改为"首帧即时 + 后续合并"**：第一次 FS 事件立即刷新响应首帧，后续事件做 trailing debounce，解决持续刷盘场景的感知延迟

### Phase 3: 减少 body 内重复开销（中优先级）

- [ ] **缓存 `LumiDefaultFileIconThemeContributor`**：改为静态常量或单例，避免每个节点每次 `body` 都分配新实例；或在 `init` 阶段就把最终 `LumiFileIcon` 解析结果缓存
- [ ] **`DragPreview` 复用节点的 `isDirectory`**：把已缓存的 `isDirectory` 传入 `FileTreeDragPreview`，避免拖拽热路径上再做 `resourceValues(forKeys: [.isDirectoryKey])` 文件系统 I/O
- [ ] **隔离选中态失效范围**：`selectionState.isSelected(url)` 放在 `body` 顶部会让任意选中变化使所有可见节点失效；配合 Phase 1 的 `Equatable` 后评估是否只需让选中/上次选中两个节点感知变化

### Phase 4: 持久化与多选数据结构（低优先级）

- [ ] **`EditorFileTreeStore` 内存缓存 + 防抖落盘**：展开/折叠操作只改内存，用 ~1s 防抖批量写 plist，避免每次增删都全量原子写盘
- [ ] **`visibleOrder` 改为有序集合或索引字典**：替换数组 + `removeAll { $0 == path }`，让 `untrackVisible` 和 Shift 多选的 `firstIndex` 不再 O(n)
- [ ] **评估 `EditorFileTreeView` 的 `ScrollView + VStack` 改为懒加载**：当前 `VStack` 是 eager 的，超大项目可考虑 `LazyVStack`，但需权衡与展开动画的兼容性

### 成功标准

- [ ] 展开 500+ 文件的项目后，文件系统刷新不再重建整棵树（仅受影响节点更新）
- [ ] `git checkout`、`npm install` 等持续刷盘场景下文件树无明显周期性掉帧
- [ ] 快速展开/折叠含大量子目录的目录时不触发密集磁盘写
- [ ] 👤 需要用户参与：在大项目上验证滚动、展开/折叠、Git 状态刷新、多选交互的流畅度
