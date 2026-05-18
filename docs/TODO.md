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

## 10. 编辑器文件树 Xcode 风格 Package Dependencies

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

## 11. Motrix 下载管理插件

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
