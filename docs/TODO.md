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

## 4. 文件树图标主题

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

## 5. Onboarding 插件选择界面

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

## 6. 编辑器文件树 Git 状态标记

> 目标：在文件树中实现类似 Xcode 的 Source Control 状态标记。

### 状态定义

新增轻量模型（建议放在 `EditorFileTreeGitStatusProvider.swift`）：

- `EditorFileTreeGitStatus`：`modified`、`added`、`deleted`、`renamed`、`untracked`、`staged`、`conflicted`。
- `EditorFileTreeGitStatusEntry`：`path`（相对路径）、`status`、`isStaged`。
- `EditorFileTreeGitStatusSnapshot`：`entriesByRelativePath`、`directoryAggregateByRelativePath`、`repoRootPath`、`capturedAt`。

状态优先级：`conflicted` > `deleted` > `renamed` > `added`/`untracked` > `modified` > `staged`（辅助样式）。目录聚合显示子树中最高优先级状态。

### 刷新设计

- Git status 查询在后台 task 执行，只有 snapshot 赋值回到 MainActor。
- 项目切换时取消旧 task，校验返回结果仍属于当前 `projectRootPath`。
- 需要额外监听：`.git/index`、`.git/HEAD`、`.git/refs/heads`、`.git/MERGE_HEAD`、`.git/rebase-merge` / `.git/rebase-merge`。
- 如果 `.git` 是 worktree 文件，需解析 `gitdir: ...` 指向真实 git dir。
- 文件系统变化时 debounced（150-300ms）刷新 Git 状态；大仓库保护：单次 status 超 500ms 后续退避到 1-2s。
- 非 Git 仓库返回空 snapshot；查询失败保留上一份 snapshot，不阻断文件树渲染。

### UI 方案

- 字母标记放在行尾 `Spacer()` 后，右对齐，固定宽度 16-20px。
- 字体：`system(size: 10, weight: .semibold, design: .monospaced)`。
- 颜色：`M` accent/warning、`A`/`?` success/green、`D` destructive red、`R` purple/secondary accent、`C` red + stronger weight。选中行保持足够对比度。
- 添加 `.help(...)` tooltip：`M` Modified、`A` Added、`?` Untracked、`D` Deleted、`R` Renamed、`C` Conflict。
- 节点视图不做 Git I/O，状态由文件树级别 coordinator 统一获取通过只读映射传入。

### Phase 1: 模型和 Provider

- [x] 新增 `EditorFileTreeGitStatusProvider.swift`。
- [x] 定义 status enum、entry、snapshot。
- [x] 实现路径 normalizer（将 Git 返回路径规范化为相对 `repoRootPath` 的 POSIX 路径，rename 记录新路径）。
- [x] 复用或封装 LibGit2Swift status 获取；补齐 untracked / conflicted（若当前 `getDiffFileList` 不返回，需在 LibGit2Swift 能力层补方法）。
- [x] 对非 Git 仓库返回 empty snapshot。
- [ ] 添加 provider 单元测试（modified、added/untracked、deleted、staged + unstaged 同文件、nested directory aggregate）。

### Phase 2: Coordinator 接入

- [x] 在 `EditorFileTreeRefreshCoordinator` 持有 `@Published gitStatusSnapshot`。
- [x] 项目切换时重置旧 snapshot、检测 Git repo、启动一次状态刷新。
- [x] 文件系统变化时 debounced 刷新 Git 状态。
- [ ] 增加 `.git` 元数据监听（index、HEAD、refs/heads、MERGE_HEAD、rebase-merge）。
- [x] 处理 worktree `gitdir`。
- [x] 确保项目切换取消旧 refresh task。

### Phase 3: UI 标记

- [x] `EditorFileTreeView` 向根节点传入 snapshot。
- [x] `EditorFileTreeNodeView` 接收 snapshot 并计算当前节点状态。
- [x] 在行尾渲染固定宽度状态标记（M/A/D/R/?/C）。
- [x] 为选中、hover、深浅色主题调整颜色。
- [x] 为状态标记添加 tooltip。
- [ ] 👤 需要用户参与：验证标记在不同主题/选中态下的视觉可读性。

### Phase 4: 边界场景

- [ ] 删除文件：本期只让父目录显示聚合状态（`D` 状态对应文件系统中不存在的路径，单纯文件树无法渲染删除的文件节点）。
- [ ] ignored 文件不显示。
- [ ] submodule 先按普通目录处理，不递归读取子仓库状态。
- [ ] nested Git repo 只显示项目根仓库状态。
- [ ] rename 只在新路径显示 `R`。
- [ ] conflict 预留 enum 和 UI（如 LibGit2Swift 能力不足，先预留后续补数据源）。

### Phase 5: 验证

- [ ] 👤 需要用户参与：打开 Git 仓库修改文件显示 `M`。
- [ ] 👤 需要用户参与：新建未跟踪文件显示 `?`。
- [ ] 👤 需要用户参与：`git add` 后标记仍显示具体变更，样式可体现 staged。
- [ ] 👤 需要用户参与：切换项目后旧项目状态不残留。
- [ ] 👤 需要用户参与：非 Git 目录不显示标记且无报错。
- [ ] 👤 需要用户参与：通过 Xcode / 终端 / Lumi 自身修改文件，标记自动刷新。
- [ ] 大目录展开和滚动不触发每行 Git 查询。

### 建议文件变更清单

- 新增：`EditorFileTreeGitStatusProvider.swift`（如模型较多可拆出 `EditorFileTreeGitStatusModels.swift`）。
- 修改：`EditorFileTreeRefreshCoordinator.swift`、`EditorFileTreeWatcher.swift`（如需 git metadata watcher）、`EditorFileTreeView.swift`、`EditorFileTreeNodeView.swift`、`GitService.swift` 或 LibGit2Swift 封装层。

---

## 7. Auto 模型路由

> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。参考 Cursor Auto 模式。

### 架构概述

路由流程：用户消息 → 信号采集 → 候选过滤 → 评分排序 → 选择最佳 → 发送请求。

新增文件：
- `LumiApp/Core/Services/LLM/AutoModelRouter.swift` — 路由引擎（核心）。
- `LumiApp/Core/Services/LLM/AutoModelScoring.swift` — 评分策略（可替换）。
- `LumiApp/Plugins/ChatInputPlugin/Middlewares/AutoModelMiddleware.swift` — SendPipeline 中间件（order: 10，早期执行）。

核心类型：
- `AutoModelCandidate`：`providerId`、`model`、`score`、`reason`（UI 展示用）。
- `AutoModelRouter`：`selectModel(for:chatMode:)` → `AutoModelCandidate?`；`rankCandidates(message:chatMode:)` → `[AutoModelCandidate]`。
- `AutoModelMiddleware`：在 SendPipeline 中拦截请求，Auto 模式开启时调用 router 选择模型，写入 `LLMVM.lastAutoSelected*`。

路由信号：`hasImages`、`chatMode`、`messageLength`、`allowsTools`、`historicalStats`（`ModelPerformanceStats`）、`modelCapabilities`、`apiKeyConfigured`。

硬过滤（必须满足）：有图片 → supportsVision；Build 模式 → supportsTools；API Key 已配置；模型存在。

软评分公式：`totalScore = capabilityBonus(0-10) + strengthScore(0-30) + tpsScore(0-20) + reliabilityScore(0-10) + complexityMatch(0-10) + explorationBonus(0/15)`。

模型强度评分参考：旗舰级（Claude Opus / o3 / o4 / Gemini 2.5 Pro）30 分；高性能（Claude Sonnet / GPT-4o）25 分；中等（DeepSeek V3 / GPT-4）20 分；轻量快速（Haiku / GPT-4o-mini / Flash）15 分；本地模型按参数量 12-22 分。新模型无历史数据给 15 分探索奖励。

设计决策：路由在 SendPipeline Middleware 中执行，不侵入核心发送逻辑；Auto 不持久化到对话偏好，每次发送独立决策；UI 显示实际选择的模型（透明可解释）。

### Phase 1: 基础路由（最小可用）

- [ ] 新增 `AutoModelRouter`（能力过滤 + 模型强度评分）。
- [ ] 新增 `AutoModelMiddleware`。
- [ ] `LLMVM` 新增 `isAutoMode` 状态。
- [ ] `LLMRequester` 支持 Auto 配置获取（`isAutoMode` 时从 `LLMVM.lastAutoSelected*` 获取 config）。
- [ ] `ModelSelectorTab` 新增 `.auto`。
- [ ] `ChatToolbarView` 支持 Auto UI 状态（`wand.and.stars` 图标 + 实际模型名）。
- [ ] 👤 需要用户参与：验证模型选择器 Auto Tab 的 UI 文案和推荐理由展示是否合理。

### Phase 2: 历史数据驱动

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`。
- [ ] TPS 评分生效（`tpsScore = min(avgTPS / 50.0, 1.0) × 20`）。
- [ ] 可靠性评分生效（`reliabilityScore = min(sampleCount / 50.0, 1.0) × 10`）。
- [ ] 模型选择器 Auto Tab 展示评分详情。

### Phase 3: 复杂度感知

- [ ] 消息长度分析（短消息偏向轻量模型）。
- [ ] 对话轮数感知（长对话可能需要更大 context）。
- [ ] 代码检测（消息包含代码块时偏向编程能力强的模型）。

### Phase 4: 学习型路由

- [ ] 用户手动切换模型后调整对应模型权重。
- [ ] 路由失败（模型不可用）时自动 fallback。
- [ ] 基于对话类别（编程/写作/问答）的偏好学习。

### Phase 5: 成本优化

- [ ] 模型定价数据接入。
- [ ] 简单任务自动选便宜模型。
- [ ] Token 用量预算控制。

---

## 8. LLM Provider Kit

> 目标：将多个 OpenAI-compatible 供应商插件中重复的请求构造、消息转换、工具格式化、响应解析和 SSE 流解析逻辑提取到独立 Swift Package。

### 已完成摘要（2026-05-18）

Package 创建、核心模型下沉、OpenAI-compatible 公共逻辑、Anthropic-compatible 公共逻辑全部完成，50 个单元测试通过。详见 `Packages/LLMProviderKit/`。

### Phase 4: 迁移第一批 Provider

- [ ] OpenAIProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] DeepSeekProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] OpenRouterProvider 使用 `OpenAICompatibleProviderAdapter`，保留额外 headers 和 tool call id 策略。
- [ ] 迁移 AiRouter、FreeModel、Feifeimiao、FlyMux、HyperAPI、MegaLLM、Xiaomi、Xybbz。
- [ ] 删除每个 provider 中重复的 response DTO、`transformMessage`、`formatTool`、`parseStreamChunk`。
- [ ] 保留 provider 自身 model catalog、default model、api key storage key、website URL。

### Phase 5: 清理和文档

- [ ] 删除迁移后不再使用的重复 DTO（如 `DeepSeekResponse` 等同构类型）。
- [ ] 更新 provider 插件说明，记录新 provider 接入方式。
- [ ] 增加 `Packages/LLMProviderKit/README.md` 新供应商模板。

### 注意事项

1. `SuperAgentTool` 依赖 `LanguagePreference`、`ToolArgument`、`CommandRiskLevel` 等 App 概念，package 中已定义轻量 `LLMToolSchemaProviding` 协议解耦。Provider 迁移时需在 `formatTool` 调用点做适配。
2. 不同供应商虽然声称 OpenAI-compatible，但 stream tool call delta 细节可能不同。`OpenAICompatibleProviderConfiguration` 已保留配置 hook（`returnsEmptyChunkWhenNoDelta`、`acceptsFunctionScopedToolCallID`）。
3. 迁移建议先做 OpenAI、DeepSeek、OpenRouter 三个代表，验证回归后再批量处理剩余 provider。

---

## 9. 编辑器文件树 Xcode 风格 Package Dependencies

> 目标：在 `EditorRailFileTreePlugin` 的文件树底部显示类似 Xcode 的 Swift Package Dependencies 列表。
> MVP 目标是先准确显示当前 Xcode 工程的直接 Swift Package 依赖，并能展示版本 / branch / revision。后续再做 checkout 内容展开、resolve/update 命令和更多交互。

### Current Code Targets

- File tree plugin: `LumiApp/Plugins/EditorRailFileTreePlugin/`
- Main view: `Views/EditorFileTreeView.swift`
- Node view: `Views/EditorFileTreeNodeView.swift`
- Store: `Services/EditorFileTreeStore.swift`
- Refresh coordinator: `Services/EditorFileTreeRefreshCoordinator.swift`
- Watcher: `Services/EditorFileTreeWatcher.swift`

### Key Technical Decisions

- For `.xcodeproj`, use `project.pbxproj` package references as the source of direct dependencies.
- Use `Package.resolved` only to enrich direct dependencies with resolved version, branch, and revision.
- Support both Xcode resolved format and SwiftPM resolved format.
- For Xcode projects, package resolve/update commands must use `xcodebuild -resolvePackageDependencies`, not `swift package resolve`.
- For pure SwiftPM projects, use `Package.swift` / `Package.resolved` and `swift package` commands.
- MVP should append the package section inside the existing `EditorFileTreeView` `ScrollView`.

### Phase 1: MVP Data Model And Parser

- [ ] Add `EditorPackageDependency.swift`
  - [ ] Fields: `identity`, `displayName`, `location`, `kind`, `version`, `branch`, `revision`, `requirement`, `checkoutURL`, `status`
  - [ ] Support remote and local package kinds first
  - [ ] Make identity stable and deterministic, not UUID-based

- [ ] Add `EditorPackageResolved.swift`
  - [ ] Decode Xcode v1 format: `object.pins[].package`, `repositoryURL`, `state`
  - [ ] Decode SwiftPM v2 format: `pins[].identity`, `kind`, `location`, `state`
  - [ ] Normalize repository URLs for matching
  - [ ] Unit test both formats with fixtures

- [ ] Add `EditorXcodePackageReferenceParser.swift`
  - [ ] Parse `XCRemoteSwiftPackageReference` entries from `project.pbxproj`
  - [ ] Parse `XCLocalSwiftPackageReference` entries from `project.pbxproj`
  - [ ] Extract display name from comments where available
  - [ ] Extract `repositoryURL`, `relativePath`, and `requirement`
  - [ ] Preserve the direct dependency ordering from `packageReferences`
  - [ ] Unit test with a trimmed `project.pbxproj` fixture

- [ ] Add `EditorPackageDependencyResolver.swift`
  - [ ] Detect project type: `.xcodeproj`, `.xcworkspace`, pure SwiftPM, or plain folder
  - [ ] For `.xcodeproj`, locate `project.pbxproj`
  - [ ] For `.xcodeproj`, locate resolved file at `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - [ ] Fallback resolved search paths:
    - [ ] `{root}/Package.resolved`
    - [ ] `{root}/.swiftpm/Package.resolved`
    - [ ] `{root}/Package.swift` parent package paths
  - [ ] Merge direct references with resolved pins
  - [ ] Do not show transitive resolved pins in MVP
  - [ ] Resolve local package URLs relative to project root
  - [ ] Resolve remote checkout URLs from `.build/checkouts` and `DerivedData/SourcePackages/checkouts` where feasible

### Phase 2: Store And Refresh

- [ ] Add `EditorPackageDependencyStore.swift`
  - [ ] `@Published var packages`
  - [ ] `@Published var isLoading`
  - [ ] `@Published var error`
  - [ ] `@Published var isSectionExpanded`
  - [ ] `func refresh(projectRootPath:) async`
  - [ ] Cancel in-flight refresh when project changes

- [ ] Extend `EditorFileTreeStore.swift`
  - [ ] Persist package section expanded/collapsed state per project
  - [ ] Persist expanded package identities for later phases

- [ ] Refresh triggers
  - [ ] Refresh packages on project path change
  - [ ] Refresh packages on view appear
  - [ ] Refresh packages when `project.pbxproj` changes
  - [ ] Refresh packages when `Package.resolved` changes
  - [ ] Reuse existing watcher/coordinator if practical; otherwise keep package watcher small and isolated

### Phase 3: MVP UI

- [ ] Add `EditorPackageDependencySection.swift`
  - [ ] Header row: chevron + package icon + `Swift Package Dependencies`
  - [ ] Show loading state
  - [ ] Show compact error state
  - [ ] Hide section when no package references exist
  - [ ] Append section at the bottom of the existing `EditorFileTreeView` `ScrollView`

- [ ] Add `EditorPackageDependencyRow.swift`
  - [ ] Match existing file tree row height and typography
  - [ ] Use current theme colors from `ThemeVM`
  - [ ] Remote icon: `cube.box`
  - [ ] Local icon: `folder`
  - [ ] Show package display name
  - [ ] Show version, branch, or short revision as trailing secondary text
  - [ ] Add hover background matching `EditorFileTreeNodeView`
  - [ ] Single click opens local package path or checkout path when available

- [ ] Integrate into `EditorFileTreeView.swift`
  - [ ] Add `@StateObject` package store
  - [ ] Pass `projectVM.currentProjectPath`
  - [ ] Trigger package refresh alongside file tree refresh
  - [ ] Keep package UI inside the same scroll flow as file tree content

### Phase 4: Basic Interactions

- [ ] Add package row context menu
  - [ ] Reveal in Finder
  - [ ] Copy package URL/path
  - [ ] Open in Terminal when path is available
  - [ ] Add to Conversation when path is available

- [ ] Add error affordances
  - [ ] Retry refresh
  - [ ] Copy diagnostic text

### Phase 5: Expand Package Contents

- [ ] Add `EditorPackageDependencyNode.swift`
  - [ ] Model directory/file entries under a package checkout or local package path
  - [ ] Stable IDs based on URL path

- [ ] Add package content loading
  - [ ] Lazy-load package children on expand
  - [ ] Filter hidden files and build artifacts
  - [ ] Prefer showing `Package.swift`, `Sources`, `Tests`, `README*`, `LICENSE*`
  - [ ] Cache package contents per package identity

- [ ] Add expandable package rows
  - [ ] Expand/collapse package contents
  - [ ] Persist expanded package identities
  - [ ] Reuse visual style from `EditorFileTreeNodeView`

### Phase 6: Resolve And Update Commands

- [ ] Add `EditorPackageCommandService.swift`
  - [ ] For `.xcodeproj`: run `/usr/bin/xcodebuild -resolvePackageDependencies -project <project>`
  - [ ] For `.xcworkspace`: run `/usr/bin/xcodebuild -resolvePackageDependencies -workspace <workspace>`
  - [ ] For pure SwiftPM: run `swift package resolve`
  - [ ] Add timeout and cancellation
  - [ ] Capture stdout/stderr for diagnostics

- [ ] Add UI actions
  - [ ] Resolve Packages
  - [ ] Update Packages, only after confirming scope
  - [ ] Disable commands while one is already running
  - [ ] Refresh dependencies after command completion

### Phase 7: Tests

- [ ] Parser tests
  - [ ] Xcode v1 `Package.resolved`
  - [ ] SwiftPM v2 `Package.resolved`
  - [ ] Remote package references in `project.pbxproj`
  - [ ] Local package references in `project.pbxproj`
  - [ ] Direct references merged with resolved pins

- [ ] Resolver tests
  - [ ] `.xcodeproj` resolved path discovery
  - [ ] Local package path resolution
  - [ ] Remote checkout path lookup
  - [ ] No transitive pins shown in MVP

- [ ] UI verification
  - [ ] No package project hides section
  - [ ] Loading state renders
  - [ ] Error state renders
  - [ ] Long package names truncate cleanly
  - [ ] Light and dark theme rows remain readable

### Phase 8: Later Enhancements

- [ ] Version update checking
- [ ] Dependency graph view
- [ ] Package size analysis
- [ ] Registry package support
- [ ] Package editing support
- [ ] Per-package update action
- [ ] Security advisory integration

### Initial Acceptance Criteria

- [ ] Opening this repo shows direct package dependencies from `Lumi.xcodeproj/project.pbxproj`
- [ ] Remote packages show resolved version, branch, or short revision from `Package.resolved`
- [ ] Local packages under `Packages/` appear as local dependencies
- [ ] Transitive packages from `Package.resolved` do not appear in the MVP list unless also directly referenced
- [ ] The package section appears at the bottom of the file tree and matches the existing file tree visual style
- [ ] Package parsing failures do not break the normal file tree

---

## 10. Motrix 下载管理插件

> 目标：在 Lumi 中以插件形式提供 Motrix 等价的下载管理能力（HTTP/HTTPS、BitTorrent、Magnet）。
> 策略：不嵌入 Motrix 的 Electron/Vue 前端；仅复用其核心下载引擎 aria2（RPC），实现原生 SwiftUI UI，统一设计与交互。

### Current Verdict

- [ ] Keep the `aria2c + JSON-RPC + native SwiftUI` direction.
- [ ] Treat "Motrix equivalent" as a long-term target, not the v1 scope.
- [ ] Update the original plan after the v1 implementation details are validated.

### Plan Corrections

- [ ] Replace outdated `SuperPlugin.swift` path with `LumiApp/Core/Proto/SuperPlugin.swift`.
- [ ] Remove references to missing `PluginProvider.swift`.
- [ ] Replace `PluginSettingsStore.swift` references with `PluginSettingsVM` and `AppSettingStore`, or add a plugin-local settings store if typed settings are needed.
- [ ] Replace old `GlassCard.swift` path with the current `GlassCard` compatibility/typealias path under `LumiApp/Core/Components/LumiUICompatibility.swift`.
- [ ] Confirm whether status-bar integration should use `addStatusBarLeadingView`, `addStatusBarCenterView`, `addStatusBarTrailingView`, or menu-bar popup contributions.

### V1 Scope

- [ ] Create `LumiApp/Plugins/MotrixDownloadPlugin/`.
- [ ] Add `MotrixDownloadPlugin.swift`.
- [ ] Implement `SuperPlugin` metadata (`id`, `displayName`, `description`, `iconName`, `order`, `enable`, `instanceLabel`, `static let shared`).
- [ ] Add panel entry with `addPanelView(activeIcon:)`.
- [ ] Add settings entry with `addSettingsView()`.
- [ ] Support HTTP/HTTPS downloads first.
- [ ] Support task list display.
- [ ] Support pause, resume, remove, and retry.
- [ ] Support global download speed display.
- [ ] Support default download directory setting.
- [ ] Support global speed limit setting.
- [ ] Support task completion notification.

### Aria2 Runtime

- [ ] Decide resource location for bundled `aria2c`; do not put executable binaries in `.xcassets`.
- [ ] Add `aria2c` as a bundled resource or documented external dependency.
- [ ] On first run, copy bundled `aria2c` to Application Support or another writable plugin directory.
- [ ] Ensure copied `aria2c` has executable permission.
- [ ] Create writable plugin data directory.
- [ ] Store `aria2.session` in the writable plugin data directory.
- [ ] Store task metadata cache in the writable plugin data directory.
- [ ] Stop `aria2c` cleanly when the plugin/app shuts down.
- [ ] Provide fallback to an external `aria2c` path for development.

### RPC Security

- [ ] Bind RPC to `127.0.0.1` only.
- [ ] Avoid a fixed default port when possible; choose an available local port.
- [ ] Generate an RPC secret per service start or persist a secret in plugin settings.
- [ ] Pass the secret to all JSON-RPC requests.
- [ ] Handle port collision and startup failure with a clear UI error state.
- [ ] Do not expose RPC to LAN.

### Models

- [ ] Add `DownloadTask`.
- [ ] Add task status enum mapped from aria2 statuses.
- [ ] Add `TransferStats`.
- [ ] Add error model for RPC and download failures.
- [ ] Defer `TorrentInfo` until BT support starts.

### Services

- [ ] Add `Aria2Service`.
- [ ] Implement aria2 process launch.
- [ ] Implement JSON-RPC client.
- [ ] Implement `aria2.addUri`.
- [ ] Implement `aria2.pause`.
- [ ] Implement `aria2.unpause`.
- [ ] Implement `aria2.remove` or `aria2.forceRemove`.
- [ ] Implement `aria2.tellActive`.
- [ ] Implement `aria2.tellWaiting`.
- [ ] Implement `aria2.tellStopped`.
- [ ] Implement `aria2.getGlobalStat`.
- [ ] Implement polling or event update loop.
- [ ] Add cancellation handling for polling tasks.

### View Model

- [ ] Add `DownloadManagerViewModel`.
- [ ] Keep aria2 calls off the main actor.
- [ ] Publish task snapshots for SwiftUI.
- [ ] Aggregate global speed.
- [ ] Surface startup, permission, and RPC errors.
- [ ] Add user actions for add, pause, resume, remove, and retry.

### UI

- [ ] Add `DownloadManagerView`.
- [ ] Add task row view with name, progress, speed, ETA, and actions.
- [ ] Add empty state.
- [ ] Add add-download flow for URL input.
- [ ] Add detail panel or inspector for errors and connection stats.
- [ ] Add `DownloadSettingsView`.
- [ ] Use existing `GlassCard` and `AppTheme` patterns.
- [ ] Avoid nesting cards inside cards.
- [ ] Verify text does not overflow in compact widths.

### Settings

- [ ] Store `downloadDirectory`.
- [ ] Store `maxConcurrentTasks`.
- [ ] Store `defaultUserAgent`.
- [ ] Store `speedLimitGlobal`.
- [ ] Store external `aria2c` path for development fallback.
- [ ] Defer `enableTrackerAutoUpdate`.
- [ ] Defer `enablePortMapping`.
- [ ] Re-evaluate whether settings belong in `AppSettingStore` or a plugin-local plist/JSON store.

### Tests

- [ ] Add `Tests/MotrixDownloadPluginTests/`.
- [ ] Add plugin metadata smoke test.
- [ ] Add RPC request encoding tests.
- [ ] Add task status mapping tests.
- [ ] Add view-model action tests with a fake aria2 service.
- [ ] Add integration test for add-download flow when `aria2c` is available.
- [ ] Document tests skipped when `aria2c` is missing.

### Packaging And Signing

- [ ] Confirm `aria2c` is included in the app bundle.
- [ ] Confirm `aria2c` is executable after copy.
- [ ] Confirm Apple Silicon binary works locally.
- [ ] Confirm code signing requirements for the embedded executable.
- [ ] Confirm current entitlements are enough for non-sandboxed distribution.
- [ ] If sandboxing is introduced, add user-selected read/write file access and security-scoped bookmarks.

### V2 BT And Magnet

- [ ] Support magnet URI import.
- [ ] Support `.torrent` file import.
- [ ] Add `TorrentInfo`.
- [ ] Add torrent file tree parsing/display.
- [ ] Support selective file download.
- [ ] Add tracker list cache.
- [ ] Add tracker auto-update.
- [ ] Add tracker update failure fallback.

### V3 Advanced Features

- [ ] Add FTP support if still needed.
- [ ] Add per-task speed limit.
- [ ] Add per-task User-Agent override.
- [ ] Add max split/thread controls.
- [ ] Add recent tasks menu-bar popup.
- [ ] Add optional "delete related files" flow.
- [ ] Add UPnP/NAT-PMP only if BT use proves it is worth the complexity.

### Open Questions

- [ ] Should this plugin be enabled by default?
- [ ] Should the panel icon be visible in the main ActivityBar, menu bar only, or both?
- [ ] Should completed tasks be persisted in Lumi or only in aria2 session state?
- [ ] Should downloads outside the default directory require explicit user confirmation?
- [ ] Should BT/Magnet be hidden behind an advanced setting for compliance reasons?

---

## 12. CodeReview Plugin

> 目标：构建 Lumi 插件，审查当前 Git 变更，报告可操作问题，后续辅助生成 PR 描述或应用安全修复。

### Phase 0: Scope and Integration

- [x] Confirm MVP review scopes: staged, unstaged, all uncommitted changes
- [x] Defer branch comparison until MVP is stable
- [ ] Reuse existing plugin extension points: `addStatusBarTrailingView(activeIcon:)`, SwiftUI popover
- [x] Reuse existing Git infrastructure (`GitService.getDiff`)
- [x] Reuse existing LLM infrastructure (`RootContainer.shared.llmService`, `SuperAgentToolEnvironment.llmService`)

### Phase 1-5: Core (已完成摘要)

Models、Diff Analysis、Review Engine、Report Store、Agent Tools 核心实现已完成。详见 `LumiApp/Plugins/CodeReviewPlugin/`。

### Phase 6: Status Bar UI

- [ ] Create `ReviewStatusBarView.swift`
- [ ] Show nothing when no project or no Git repository is active
- [ ] Show review entry when there are uncommitted changes
- [ ] Show reviewing state while analysis is running
- [ ] Show issue count after review completes with severity color states
- [ ] Keep layout consistent with existing status bar plugins
- [ ] Use `StatusBarHoverContainer` for the popover

### Phase 7: Report Popover

- [ ] Create `ReviewReportPopover.swift`
- [ ] Show report summary, score, and diff stats
- [ ] Group findings by severity
- [ ] Show file and line metadata for every issue
- [ ] Show fix suggestions in readable format
- [ ] Add rerun review and copy report actions
- [ ] Add open file action if existing editor navigation APIs are available

### Phase 8: Plugin Entry

- [x] Create `CodeReviewPlugin.swift` with metadata and tool factory
- [ ] Register status bar view
- [x] Initialize shared store/service dependencies
- [ ] Add localization file for user-facing strings

### Phase 9: PR Description Support

- [ ] Decide whether PR description generation belongs in CodeReviewPlugin or GitHub tools
- [ ] Generate PR title and body from diff, commit log, review report, and project rules
- [ ] Support conventional sections (summary, changes, tests, risks, review notes)

### Phase 10: Tests

- [ ] Add unit tests for review models, LLM JSON parsing, confidence downgrading, diff truncation
- [ ] Add tool tests for `run_review`
- [ ] Add store persistence tests
- [ ] Add regression tests for no-changes and malformed LLM output

### Technical Decisions

- Prefer existing `GitService` and `LibGit2Swift` over direct `git diff` process calls
- Limit MVP review scope to current uncommitted changes
- Store reports in local JSON cache
- Treat automatic fix application as high-risk, ship after review/reporting is stable

---

## 13. ErrorDoctor Plugin

> 目标：自动监听构建失败、Test 失败、运行时 Crash 和 Compiler Errors，由 Agent 分析错误日志结合代码上下文给出根因分析，生成修复方案（Patch 代码），用户一键应用。

### Phase 1: 错误监听与解析

- [ ] 定义 `ErrorReport` 数据模型（type: build/test/runtime/compiler, severity, message, file, line, stackTrace）
- [ ] 实现 `ErrorListener`: Shell 输出捕获与 Regex 提取
- [ ] 支持 Swift Compiler / xcodebuild 错误格式

### Phase 2: 诊断与分析

- [ ] 实现 `ErrorAnalyzer`: LLM 诊断 Prompt 构建与结果解析
- [ ] 实现 `FixGenerator`: 生成 CodePatch
- [ ] 错误知识库 (JSON 存储)

### Phase 3: 工具与中间件

- [ ] 实现 `DiagnoseTool` / `ApplyFixTool`
- [ ] 实现 `ErrorContextMiddleware` (Order: 40)
- [ ] 验证自动修正循环

### Phase 4: UI 开发

- [ ] 实现 `ErrorStatusBarView`: 显示错误计数、诊断中、已修复状态
- [ ] 实现 `ErrorReportPopover`: 错误详情和 Apply Fix 按钮
- [ ] Diff 预览与确认交互

### Phase 5: 优化与扩展

- [ ] 支持更多语言/编译器 (JS/Python/Go)
- [ ] 测试失败自动重试机制
- [ ] 错误知识库搜索与推荐

### 技术决策

| 决策点 | 方案 |
|--------|------|
| 错误提取 | Regex Pattern + Context，轻量快速 |
| LLM 上下文 | Error Line ± 20 行，平衡信息量与 Token |
| 修复应用 | Patch Diff + 用户确认，安全优先 |
| 存储 | JSON (项目级 `.agent/errors.json`) |

---

## 14. FocusGroup Plugin

> 目标：提供虚拟用户面板，模拟一批具有不同背景特征的虚拟用户对内容（标题、文案、产品描述）给出个性化反馈，自动汇总统计。

### Phase 1: 数据模型与画像存储

- [ ] 定义 `Persona`, `PersonaTag`, `SimulationQuestion`, `SimulationResult` 数据模型
- [ ] 实现 `PersonaStore` (Actor): 画像的 CRUD、持久化、默认数据加载
- [ ] 创建 `DefaultPersonas.json` (8-12 个典型用户)

### Phase 2: 模拟引擎

- [ ] 实现 `SimulationEngine`: Prompt 构建、LLM 并行调用 (TaskGroup)
- [ ] 实现 LLM Response 解析（JSON 格式 → `PersonaResponse`）
- [ ] 支持 6 种预设场景 + 自定义场景
- [ ] 实现 `ResultAggregator`: 统计计算 + 关键洞察提取

### Phase 3: Agent 工具

- [ ] 实现 `FocusGroupTool`: `focus_group_simulate` 工具注册
- [ ] 参数解析与结果格式化
- [ ] 错误处理（LLM 超时、解析失败等）

### Phase 4: 面板 UI

- [ ] 实现 `FocusGroupPanelView` 主面板
- [ ] 实现 `SimulationInputView` 输入区
- [ ] 实现 `SimulationResultView` 结果展示（含统计条形图）
- [ ] 实现 `PersonaListView` 用户列表 + 启用/禁用
- [ ] 实现 `PersonaEditorView` 画像编辑器

### Phase 5: 设置与优化

- [ ] 实现设置视图（默认用户数、LLM 参数调优、结果历史管理）
- [ ] 结果持久化与历史记录
- [ ] 导入/导出画像配置
- [ ] 性能优化：结果缓存、并发控制

### 技术决策

- LLM 调用：复用 Lumi 已有的 LLM Provider 体系
- 并行策略：Swift TaskGroup + 限制最大并发数 (5)
- 画像存储：JSON 文件 (`~/Library/Application Support/Lumi/focus-group/`)
- 默认画像数：8 个，平衡覆盖面与 LLM 调用成本

---

## 15. GitHubInsight Plugin

> 目标：自动分析当前项目的技术栈、依赖、架构特征，在后台异步搜索 GitHub 发现相关开源项目、替代方案和最佳实践，通过中间件按需注入对话上下文。

### Phase 1: 项目画像引擎

- [ ] 定义 `ProjectProfile` 数据模型
- [ ] 实现 `ProjectProfiler`: 解析常见 Manifest 文件 (package.json, Podfile, Package.swift, README.md)
- [ ] 输出结构化画像供后续模块消费

### Phase 2: GitHub 发现引擎

- [ ] 实现 `GitHubDiscoverer`: 搜索查询构建
- [ ] 集成 GitHub REST API (搜索端点)
- [ ] 支持 `gh` CLI 降级方案
- [ ] 实现请求队列 + 限流处理 + 本地缓存 (ETag, 24h)

### Phase 3: 知识库构建

- [ ] 定义 `KBEntry` 数据模型 (relationType: alternative/complementary/example)
- [ ] 实现 `KnowledgeBaseManager` (Actor)
- [ ] JSON 持久化 + 增量更新逻辑
- [ ] 相关性评分算法实现

### Phase 4: 中间件与工具

- [ ] 实现 `GitHubKBMiddleware` (Order: 60)
- [ ] 关键词触发检测
- [ ] Top-K 摘要注入
- [ ] (可选) 实现 `QueryEcoKBTool` AgentTool

### Phase 5: UI 与状态栏

- [ ] 实现 `GitHubKBStatusBarView`
- [ ] 实现 `GitHubKBPopover` (含筛选 Tab)
- [ ] 绑定 `KnowledgeBaseManager` 数据源
- [ ] 同步状态管理 (Syncing / Ready / RateLimited)

### Phase 6: 测试与优化

- [ ] 多语言项目画像测试 (Swift/JS/Python/Go/Java)
- [ ] API 限流场景容错测试
- [ ] 增量同步性能验证
- [ ] Token 消耗评估与优化

### 技术决策

- 认证方式：优先 `gh` CLI → 用户 Token → 未认证
- 存储格式：JSON 文件 + 内存缓存
- 中间件 Order：60 (在 Skill(50) 之后，RAG(100) 之前)
- 注入策略：按关键词触发，仅注入 Top-3 摘要

---

## 16. GoEditorPlugin

> 目标：使 Lumi 编辑器对 Go 项目提供接近 VS Code + Go 扩展的开发体验。
> 核心策略：LSP 能力复用现有管线，工程命令原生实现。

### Phase 1: LSP 基础（P0）

- [ ] `GoLSPConfig.swift`: gopls 配置管理（启动参数、环境变量、workspace 配置）
- [ ] `GoProjectDetector.swift`: Go 项目检测（go.mod 定位）
- [ ] `GoEnvResolver.swift`: go env 解析（GOPATH/GOROOT）
- [ ] Cmd+Click 跳转：复用现有 JumpToDefinitionDelegate
- [ ] `GoCompletionPipeline.swift`: 补全策略定制
- [ ] 悬停提示 / 实时诊断：复用现有 LSPService

### Phase 2: 工程命令（P0-P1）

- [ ] `GoBuildCommand.swift` + `GoBuildManager.swift`: go build 封装
- [ ] `GoBuildOutputParser.swift`: 构建输出解析（error/warning 提取）
- [ ] `GoBuildOutputView.swift`: 构建输出面板
- [ ] `GoFmtCommand.swift`: go fmt / gofumpt 格式化
- [ ] `GoModCommand.swift`: go mod tidy / download

### Phase 3: 测试系统（P1）

- [ ] `GoTestCommand.swift` + `GoTestManager.swift`: go test 封装
- [ ] `GoTestOutputParser.swift`: 解析 -json 输出
- [ ] `GoTestResultView.swift`: 测试结果面板
- [ ] Gutter 测试图标集成
- [ ] 单测试函数运行（基于光标位置推导）

### Phase 4: 体验打磨（P1-P2）

- [ ] `GoInlayHintPipeline.swift`: Inlay Hints（类型推断提示）
- [ ] 保存时自动格式化
- [ ] `GoStatusBarIndicator.swift`: 构建/测试状态栏指示器
- [ ] 代码透镜（Code Lens）：Run Test / Debug Test

### Phase 5: 调试系统（P3）

- [ ] `DelveAdapter.swift`: Delve DAP 适配
- [ ] 断点管理、变量查看、步进控制

### 关键配置

- gopls workspace 配置：completeUnimported, staticcheck, vulncheck, nilness, shadow 等
- 构建命令支持：交叉编译 (GOOS/GOARCH)、增量构建、取消构建
- 测试模式：单文件、当前包、全部、覆盖度、基准测试

---

## 17. HTMLEditorPlugin

> 目标：对 HTML 提供开箱即用、高效编辑、多语言无缝衔接的开发体验。
> 核心挑战：结构化编辑效率和内嵌语言（CSS/JS）上下文切换。

### Phase 1: 基础结构与 Emmet（P0）

- [ ] `HTMLServiceManager.swift`: HTML LSP 配置
- [ ] `EmmetEngine.swift`: Emmet 缩写解析与 DOM 生成
- [ ] `EmmetExpansionHandler.swift`: Tab 键触发与冲突处理
- [ ] `AutoclosingController.swift`: 智能闭合逻辑
- [ ] `HTMLTreeSitterRegistration.swift`: tree-sitter-go 注册

### Phase 2: 结构化编辑增强（P0-P1）

- [ ] `TagHighlighter.swift`: 匹配标签高亮
- [ ] `TagRenamer.swift`: 联动重命名（双光标）
- [ ] `HTMLPathCompletion.swift`: src/href 路径补全
- [ ] `HTMLDiagnosticAggregator.swift`: 减少误报

### Phase 3: 内嵌语言支持（P0）

- [ ] `LanguageShunter.swift`: 脚本/样式块上下文路由
- [ ] `OffsetMapper.swift`: 虚拟文档偏移量计算
- [ ] `EmbeddedCSSService.swift`: 内嵌 CSS LSP 适配
- [ ] `EmbeddedJSService.swift`: 内嵌 JS/TS LSP 适配

### Phase 4: 高级体验（P1-P2）

- [ ] `ColorPreviewView.swift`: 颜色值内联预览
- [ ] `ColorPickerInlineView.swift`: 内联颜色选择器
- [ ] `ARIAAttributeDatabase.swift`: 无障碍属性提示
- [ ] CSS 类名联动（与 CSSEditorPlugin 协作）

### 核心技术

- Emmet 本地引擎：毫秒级展开，不依赖网络/进程
- TagMatcher/TagRenamer：DOM 结构感知编辑
- 内嵌语言偏移映射：解决"文件中文件"的坐标问题

---

## 18. JSEditorPlugin

> 目标：对 JS/TS 项目提供开箱即用、生态自适应、可配置扩展的开发体验。
> 核心策略：配置驱动 + 生态适配层 + 诊断聚合。

### Phase 1: LSP 基础 + 项目自动探测（P0）

- [ ] `TSLSPConfig.swift`: tsserver 配置与启动（本地/全局自动探测）
- [ ] `PackageJSONParser.swift`: 解析 scripts、依赖、引擎版本
- [ ] `TSConfigResolver.swift`: tsconfig/jsconfig 解析、paths 别名映射
- [ ] Cmd+Click 跳转 / 补全 / 悬停：复用 LSP 管线
- [ ] `JSTreeSitterRegistration.swift`: tree-sitter-javascript/typescript 注册

### Phase 2: 任务执行 + 格式化（P0-P1）

- [ ] `ScriptTaskRunner.swift`: npm/pnpm/yarn/bun run 流式执行
- [ ] `BuildOutputAdapter.swift`: Vite/Webpack/esbuild/Next.js 错误正则适配
- [ ] `PrettierFormatter.swift`: prettier CLI 封装
- [ ] `FormatOnSaveCoordinator.swift`: 保存时格式化协调
- [ ] `TaskOutputView.swift`: 任务日志面板

### Phase 3: 测试适配层（P1）

- [ ] `TestRunnerDetector.swift`: 自动识别 Jest / Vitest / Playwright
- [ ] `TestOutputParser.swift`: 多格式 JSON 输出标准化
- [ ] `TestResultView.swift`: 测试结果面板
- [ ] Gutter 测试图标集成

### Phase 4: 调试 + ESLint 集成（P2）

- [ ] `NodeDAPAdapter.swift`: Node.js 调试适配
- [ ] `ESLintLSPBridge.swift`: ESLint CLI 解析 / LSP 双模式
- [ ] `DiagnosticAggregator.swift`: tsserver + eslint 冲突解决
- [ ] `DebugToolbarView.swift`: 调试控制栏

### Phase 5: Monorepo + 框架感知 + 浏览器调试（P2）

- [ ] `WorkspaceDetector.swift`: pnpm workspace / nx / turborepo 识别
- [ ] `FrameworkLSPLoader.swift`: Volar / Angular LS / Svelte LS 动态加载
- [ ] `BrowserCDPAdapter.swift`: Chrome/Edge 远程调试
- [ ] `SourceMapResolver.swift`: .map 文件解析与断点源码映射

### 核心架构

- LSP 多服务器协同：tsserver（基础）+ eslint（规范）+ framework LS（按需）
- 运行时桥接：自动探测 .nvmrc / 锁文件，统一执行接口
- 诊断聚合：按 source 标签去重，统一 severity 映射，保留 quickFixes 并集

---

## 19. VueEditorPlugin

> 目标：对 Vue.js（尤其 Vue 3 SFC）提供原生般的单文件组件编辑体验。
> 核心策略：Volar 核心引擎 + 语言虚拟化分流。

### Phase 1: Volar 集成与基础 SFC 支持（P0）

- [ ] `VolarServiceManager.swift`: @vue/language-server 生命周期管理
- [ ] `VueVersionDetector.swift`: Vue 2 vs Vue 3 自动检测
- [ ] 混合模式配置：Script 跳转走 TSServer，Template 走 Volar
- [ ] `VueTreeSitterRegistration.swift`: tree-sitter-vue 注册

### Phase 2: SFC 编辑器增强（P0）

- [ ] `SFCBlockHighlighter.swift`: 区块头高亮与独立折叠控制
- [ ] `TemplateAttributeCompleter.swift`: Vue 指令补全（v-if, v-model, 修饰符）
- [ ] Script Setup 补全：验证 Setup 变量在模板中可补全（Volar 原生）
- [ ] 区块导航命令：Cmd+1/2/3 快速切换区块

### Phase 3: 高级特性与重构（P1）

- [ ] `ComponentImportResolver.swift`: 组件名 → 文件路径自动解析
- [ ] `ScopedStyleHelper.swift`: scoped CSS 辅助（:deep() 语法提示）
- [ ] `ComponentRenamer.swift`: 组件重命名（同步更新文件与模板引用）
- [ ] `CSSModulesTypeGenerator.swift`: CSS Modules 类型生成与提示

### Phase 4: 调试与工具链（P2）

- [ ] Vue DevTools 桥接：组件树查看
- [ ] Vite 联动优化：识别 Vite 配置，优化热重载提示

### 核心架构

- Volar 混合模式：Vue LS 处理 Template，TSServer 处理 Script
- 虚拟文件映射：.vue → .vue.ts + .vue.html + .vue.css
- 与 HTML/JS/CSS 插件协作：Volar 作为协调者，HTML/JS/CSS LSP 作为底层工人
