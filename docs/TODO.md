# TODO

整合自多个 todo/planning 文档，按主题分类。

标记说明：`👤 需要用户参与` 表示该任务需要人类操作物理设备、做主观体验判断或最终产品验收，AI 无法独立完成。

---

## 1. App UI 平滑度

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

## 3. 文件树图标主题

> 目标：让 Lumi 主题插件通过单一 `LumiThemeContribution` 配置文件树图标。

### 待完成

- [ ] 添加精确文件名查找单元测试。
- [ ] 添加扩展名查找单元测试。
- [ ] 添加文件夹开/关图标查找单元测试。
- [ ] 添加证明回退行为与当前 `EditorFileTreeService` 映射一致的测试。
- [ ] 添加 `ThemeVM` 测试证明活跃主题暴露其文件图标贡献者。
- [ ] 添加文件树视图级别冒烟测试（如可行）。
- [ ] 在所有调用点迁移后移除或弃用直接文件图标映射。

---

## 4. Onboarding 插件选择界面

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

## 5. 编辑器文件树 Git 状态标记

> 目标：在文件树中实现类似 Xcode 的 Source Control 状态标记。

### Phase 1: 模型和 Provider

- [ ] 添加 provider 单元测试（modified、added/untracked、deleted、staged + unstaged 同文件、nested directory aggregate）。

### Phase 2: Coordinator 接入

- [ ] 增加 `.git` 元数据监听（index、HEAD、refs/heads、MERGE_HEAD、rebase-merge）。

### Phase 3: UI 标记

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

---

## 6. Auto 模型路由

> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。参考 Cursor Auto 模式。

### 架构概述

路由流程：用户消息 → 信号采集 → 候选过滤 → 评分排序 → 选择最佳 → 发送请求。

新增文件：
- `LumiApp/Core/Services/LLM/AutoModelRouter.swift` — 路由引擎（核心）。
- `LumiApp/Core/Services/LLM/AutoModelScoring.swift` — 评分策略（可替换）。
- `LumiApp/Plugins/ChatInputPlugin/Middlewares/AutoModelMiddleware.swift` — SendPipeline 中间件（order: 10，早期执行）。

路由信号：`hasImages`、`chatMode`、`messageLength`、`allowsTools`、`historicalStats`、`modelCapabilities`、`apiKeyConfigured`。

硬过滤：有图片 → supportsVision；Build 模式 → supportsTools；API Key 已配置；模型存在。

### Phase 1: 基础路由（最小可用）

- [ ] 新增 `AutoModelRouter`（能力过滤 + 模型强度评分）。
- [ ] 新增 `AutoModelMiddleware`。
- [ ] `LLMVM` 新增 `isAutoMode` 状态。
- [ ] `LLMRequester` 支持 Auto 配置获取。
- [ ] `ModelSelectorTab` 新增 `.auto`。
- [ ] `ChatToolbarView` 支持 Auto UI 状态。
- [ ] 👤 需要用户参与：验证模型选择器 Auto Tab 的 UI 文案和推荐理由展示是否合理。

### Phase 2: 历史数据驱动

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`。
- [ ] TPS 评分生效。
- [ ] 可靠性评分生效。
- [ ] 模型选择器 Auto Tab 展示评分详情。

### Phase 3: 复杂度感知

- [ ] 消息长度分析（短消息偏向轻量模型）。
- [ ] 对话轮数感知。
- [ ] 代码检测（消息包含代码块时偏向编程能力强的模型）。

### Phase 4: 学习型路由

- [ ] 用户手动切换模型后调整对应模型权重。
- [ ] 路由失败时自动 fallback。
- [ ] 基于对话类别的偏好学习。

### Phase 5: 成本优化

- [ ] 模型定价数据接入。
- [ ] 简单任务自动选便宜模型。
- [ ] Token 用量预算控制。

---

## 7. LLM Provider Kit

> 目标：将多个 OpenAI-compatible 供应商插件中重复的逻辑提取到独立 Swift Package。

### Phase 4: 迁移第一批 Provider

- [ ] OpenAIProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] DeepSeekProvider 使用 `OpenAICompatibleProviderAdapter`。
- [ ] OpenRouterProvider 使用 `OpenAICompatibleProviderAdapter`，保留额外 headers 和 tool call id 策略。
- [ ] 迁移 AiRouter、FreeModel、Feifeimiao、FlyMux、HyperAPI、MegaLLM、Xiaomi、Xybbz。
- [ ] 删除每个 provider 中重复的 response DTO、`transformMessage`、`formatTool`、`parseStreamChunk`。

### Phase 5: 清理和文档

- [ ] 删除迁移后不再使用的重复 DTO。
- [ ] 更新 provider 插件说明，记录新 provider 接入方式。
- [ ] 增加 `Packages/LLMProviderKit/README.md` 新供应商模板。

---

## 8. 编辑器文件树 Xcode 风格 Package Dependencies

> 目标：在 `EditorRailFileTreePlugin` 的文件树底部显示类似 Xcode 的 Swift Package Dependencies 列表。

### Phase 1: MVP Data Model And Parser

- [ ] Add `EditorPackageDependency.swift`（identity, displayName, location, kind, version, branch, revision, status）
- [ ] Add `EditorPackageResolved.swift`（Xcode v1 + SwiftPM v2 格式解析）
- [ ] Add `EditorXcodePackageReferenceParser.swift`（解析 project.pbxproj 中的包引用）
- [ ] Add `EditorPackageDependencyResolver.swift`（项目类型检测、resolved 文件定位、路径解析）

### Phase 2: Store And Refresh

- [ ] Add `EditorPackageDependencyStore.swift`
- [ ] Extend `EditorFileTreeStore.swift`（持久化展开状态）
- [ ] 刷新触发：项目路径变化、view appear、pbxproj 变化、Package.resolved 变化

### Phase 3: MVP UI

- [ ] Add `EditorPackageDependencySection.swift`
- [ ] Add `EditorPackageDependencyRow.swift`
- [ ] Integrate into `EditorFileTreeView.swift`

### Phase 4: Basic Interactions

- [ ] 右键菜单：Reveal in Finder、Copy URL/path、Open in Terminal
- [ ] 错误处理：Retry refresh、Copy diagnostic text

### Phase 5: Expand Package Contents

- [ ] Add `EditorPackageDependencyNode.swift`
- [ ] Lazy-load package children on expand
- [ ] Persist expanded package identities

### Phase 6: Resolve And Update Commands

- [ ] Add `EditorPackageCommandService.swift`（xcodebuild / swift package 命令封装）
- [ ] UI actions: Resolve Packages、Update Packages

### Phase 7: Tests

- [ ] Parser tests、Resolver tests、UI verification

### Phase 8: Later Enhancements

- [ ] Version update checking、Dependency graph、Package size analysis

---

## 9. Motrix 下载管理插件

> 目标：以插件形式提供 Motrix 等价的下载管理能力（HTTP/HTTPS、BitTorrent、Magnet）。

### V1 Scope

- [ ] Create `LumiApp/Plugins/MotrixDownloadPlugin/`
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

## 10. CodeReview Plugin

> 目标：审查当前 Git 变更，报告可操作问题。Phase 1-5 核心实现已完成。

### Phase 6: Status Bar UI

- [ ] Create `ReviewStatusBarView.swift`
- [ ] 显示审查状态、问题计数（按 severity 着色）
- [ ] 使用 `StatusBarHoverContainer` 弹出报告

### Phase 7: Report Popover

- [ ] Create `ReviewReportPopover.swift`
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

### Phase 1: 项目画像引擎

- [ ] 定义 ProjectProfile 数据模型
- [ ] 实现 ProjectProfiler: 解析 Manifest 文件

### Phase 2: GitHub 发现引擎

- [ ] 实现 GitHubDiscoverer: 搜索查询构建、GitHub REST API 集成
- [ ] gh CLI 降级方案、请求队列 + 限流 + 本地缓存

### Phase 3: 知识库构建

- [ ] 定义 KBEntry 数据模型
- [ ] 实现 KnowledgeBaseManager (Actor)、JSON 持久化、相关性评分

### Phase 4: 中间件与工具

- [ ] 实现 GitHubKBMiddleware (Order: 60)
- [ ] 关键词触发、Top-K 摘要注入
- [ ] (可选) QueryEcoKBTool

### Phase 5: UI 与状态栏

- [ ] 实现 GitHubKBStatusBarView、GitHubKBPopover

---

## 14. GoEditorPlugin

> 目标：对 Go 项目提供接近 VS Code + Go 扩展的开发体验。

### Phase 1: LSP 基础

- [ ] GoLSPConfig: gopls 配置管理
- [ ] GoProjectDetector: go.mod 定位
- [ ] GoEnvResolver: GOPATH/GOROOT 解析
- [ ] GoCompletionPipeline: 补全策略定制

### Phase 2: 工程命令

- [ ] GoBuildCommand + GoBuildManager: go build 封装
- [ ] GoBuildOutputParser + GoBuildOutputView: 构建输出解析与面板
- [ ] GoFmtCommand、GoModCommand

### Phase 3: 测试系统

- [ ] GoTestCommand + GoTestManager、GoTestOutputParser
- [ ] GoTestResultView、Gutter 测试图标集成

### Phase 4: 体验打磨

- [ ] GoInlayHintPipeline、保存时自动格式化
- [ ] GoStatusBarIndicator、代码透镜

### Phase 5: 调试系统

- [ ] DelveAdapter: Delve DAP 适配

---

## 15. HTMLEditorPlugin

> 目标：对 HTML 提供开箱即用、高效编辑、多语言无缝衔接的开发体验。

### Phase 1: 基础结构与 Emmet

- [ ] HTMLServiceManager、EmmetEngine、EmmetExpansionHandler
- [ ] AutoclosingController、HTMLTreeSitterRegistration

### Phase 2: 结构化编辑增强

- [ ] TagHighlighter、TagRenamer、HTMLPathCompletion
- [ ] HTMLDiagnosticAggregator

### Phase 3: 内嵌语言支持

- [ ] LanguageShunter、OffsetMapper
- [ ] EmbeddedCSSService、EmbeddedJSService

### Phase 4: 高级体验

- [ ] ColorPreviewView、ColorPickerInlineView
- [ ] ARIAAttributeDatabase、CSS 类名联动

---

## 16. JSEditorPlugin

> 目标：对 JS/TS 项目提供开箱即用、生态自适应的开发体验。

### Phase 1: LSP 基础 + 项目自动探测

- [ ] TSLSPConfig、PackageJSONParser、TSConfigResolver
- [ ] JSTreeSitterRegistration

### Phase 2: 任务执行 + 格式化

- [ ] ScriptTaskRunner、BuildOutputAdapter
- [ ] PrettierFormatter、FormatOnSaveCoordinator、TaskOutputView

### Phase 3: 测试适配层

- [ ] TestRunnerDetector、TestOutputParser、TestResultView
- [ ] Gutter 测试图标集成

### Phase 4: 调试 + ESLint 集成

- [ ] NodeDAPAdapter、ESLintLSPBridge、DiagnosticAggregator
- [ ] DebugToolbarView

### Phase 5: Monorepo + 框架感知 + 浏览器调试

- [ ] WorkspaceDetector、FrameworkLSPLoader
- [ ] BrowserCDPAdapter、SourceMapResolver

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
