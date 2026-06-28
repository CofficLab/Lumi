# TODO

标记说明：`👤 需要用户参与` 表示该任务需要人类操作物理设备、做主观体验判断或最终产品验收，AI 无法独立完成。

---

## 19. Editor 性能优化

> 目标：解决 Editor 相关功能的卡顿问题。详细分析见 `docs/editor-performance-analysis.md`。
> 说明：多数为性能监控点（监控指标）与 👤 Instruments 验证项。

### Phase 1–8

- [ ] TreeSitter 解析优化：`.utility` 调度、增量语法树、解析监控。
- [ ] Highlighting 延迟更新：并行 provider、更新监控、`runsIn(range:)` 缓存。
- [ ] LineOffsetTable 增量更新监控。
- [ ] TextLayoutManager 布局优化：复用池扩大、`layoutLines` 跳过未变行、布局结果缓存、布局监控。
- [ ] LSP 请求调度：优先级队列、差异化 debounce、取消机制、结果缓存、请求监控。
- [ ] 内存泄漏修复：插件 `onDisable()`、`WindowContainer.cleanup()`、EditorSession 状态清理、插件 UI 缓存清理、内存监控。
- [ ] EditorUndoManager：栈大小限制、增量状态存储、压缩、监控。
- [ ] ContextMenuManager：ObjC runtime 缓存、关联对象缓存、菜单项复用、监控。


---

## 23. 编辑器架构简化与优化

> 目标：收束编辑器模块依赖关系，消除 God Object。

### 现状问题

- 约 46% 的 Editor/LSP 插件绕过 EditorService 门面，直接依赖底层包。
- EditorService.swift 约 874 行、80+ 公开 API（God Object）。
- EditorService/Sources/Kernel/ 中有 5 个同名桥接文件。
- EditorKernel 包含约 106 个文件，无内部目录分组。
- EditorSymbols 仅被 EditorSource 一处使用。

### Phase 1–5（架构重构，影响面大）

- [ ] Phase 1：建立插件依赖规范，收敛底层依赖（EditorService Proto 层类型桥接、逐批迁移 LSP/语言/核心 UI 插件）。
- [ ] Phase 2：拆分 EditorService 门面为子门面。
- [ ] Phase 3：清理 EditorService/Kernel 桥接层。
- [ ] Phase 4：EditorKernel 内部目录分组。
- [ ] Phase 5：EditorSymbols 合并到 EditorSource。

---



## 5. Auto 模型路由

> 目标：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。

### 测试与验证

- [ ] 编写单元测试：可用性 Store 并发写入安全性、状态查询准确性。
- [ ] 编写单元测试：路由过滤逻辑、评分排序、边界场景（无可用模型、所有模型不支持工具等）。
- [ ] 验证：插件禁用后内核 Store 为空，App 正常运行（Auto 路由退化为默认行为）。

### UI 完善

- [ ] Auto Tab 展示评分详情（模型强度、TPS、可靠性、推荐原因）。
- [ ] 👤 需要用户参与：验证模型选择器 Auto Tab 的 UI 文案和推荐理由展示是否合理。

### Phase 6–9

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`；TPS / 可靠性评分生效；Auto Tab 展示历史评分。
- [ ] 复杂度感知（多轮复杂对话偏向强模型）。
- [ ] 学习型路由：手动切换调整权重（持久化）、失败 fallback、对话类别偏好学习。
- [ ] 成本优化：模型定价数据接入、简单任务选便宜模型、Token 用量预算控制。

---

## 7. 编辑器文件树 Package Dependencies

> 目标：在文件树底部显示类似 Xcode 的 Swift Package Dependencies 列表。

- [ ] Phase 1：`EditorPackageDependency` / `EditorPackageResolved`（Xcode v1 + SwiftPM v2）/ `EditorXcodePackageReferenceParser` / `EditorPackageDependencyResolver`。
- [ ] Phase 2：`EditorPackageDependencyStore`、扩展 `EditorFileTreeStore` 持久化展开、刷新触发。
- [ ] Phase 3：`EditorPackageDependencySection` / `EditorPackageDependencyRow`、集成到 `EditorFileTreeView`。
- [ ] Phase 4：右键菜单（Reveal in Finder / Copy / Open in Terminal）、错误处理（Retry / Copy diagnostic）。
- [ ] Phase 5：展开包内容（Lazy-load children、持久化展开 identity）。
- [ ] Phase 6：Resolve / Update 命令（`EditorPackageCommandService`、UI actions）。
- [ ] Phase 7：Parser / Resolver / UI 测试。
- [ ] Phase 8：Version update checking / Dependency graph / Package size analysis。

---

## 8. Motrix 下载管理插件（全新插件）

> 目标：以插件形式提供 Motrix 等价的下载管理能力（HTTP/HTTPS、BitTorrent、Magnet）。

- [ ] V1 Scope：插件元数据/面板/设置入口、HTTP/HTTPS 下载、任务列表、暂停/恢复/移除/重试、全局速度/目录/限速/通知。
- [ ] Aria2 Runtime：内置 aria2c 资源管理、session 管理、优雅退出、开发环境回退。
- [ ] RPC Security：绑定 127.0.0.1、动态端口、RPC 密钥、端口冲突 UI。
- [ ] Models & Services：DownloadTask / TransferStats / Aria2Service / DownloadManagerViewModel。
- [ ] UI：DownloadManagerView / task row / empty state / URL 输入 / DownloadSettingsView。
- [ ] Settings：downloadDirectory / maxConcurrentTasks / defaultUserAgent / speedLimitGlobal。
- [ ] Tests & Packaging：单元/集成测试、aria2c 打包签名、Apple Silicon 兼容、Entitlements。
- [ ] V2+：Magnet / .torrent、Tracker 自动更新、FTP、每任务限速、UPnP/NAT-PMP。

---

## 9. CodeReview Plugin

> 目标：审查当前 Git 变更，报告可操作问题。

- [ ] Phase 6：`ReviewStatusBarView`（状态、按 severity 着色的问题计数、`StatusBarHoverContainer`）。
- [ ] Phase 7：`ReviewReportPopover`（摘要、评分、diff 统计、按 severity 分组、修复建议、Rerun/Copy/Open）。
- [ ] Phase 8：Plugin Entry（注册状态栏视图、本地化）。
- [ ] Phase 9：PR Description Support（从 diff/commit/report 生成 PR 标题和正文）。
- [ ] Phase 10：单元测试（模型解析、LLM JSON、confidence 降级、diff 截断、`run_review` tool、Store 持久化）。

---

## 11. ErrorDoctor Plugin（全新插件）

> 目标：自动监听构建/测试/运行时错误，由 Agent 分析根因并生成修复方案。

- [ ] Phase 1：`ErrorReport` 模型、`ErrorListener`（Shell 输出 + Regex）、Swift Compiler / xcodebuild 错误格式。
- [ ] Phase 2：`ErrorAnalyzer`（LLM 诊断）、`FixGenerator`（CodePatch）、错误知识库。
- [ ] Phase 3：`DiagnoseTool` / `ApplyFixTool`、`ErrorContextMiddleware`（Order 40）。
- [ ] Phase 4：`ErrorStatusBarView` / `ErrorReportPopover` / Diff 预览确认。
- [ ] Phase 5：更多语言/编译器支持、测试失败自动重试。

---

## 12. FocusGroup Plugin（全新插件）

> 目标：模拟一批虚拟用户对内容给出个性化反馈，自动汇总统计。

- [ ] Phase 1：Persona / PersonaTag / SimulationQuestion / SimulationResult、PersonaStore（Actor）、DefaultPersonas.json。
- [ ] Phase 2：SimulationEngine（Prompt、TaskGroup 并行 LLM）、ResultAggregator。
- [ ] Phase 3：FocusGroupTool。
- [ ] Phase 4：FocusGroupPanelView / SimulationInputView / SimulationResultView / PersonaListView / PersonaEditorView。
- [ ] Phase 5：设置、结果持久化、导入/导出画像。

---

## 13. GitHubInsight Plugin

> 目标：分析项目技术栈，异步搜索 GitHub 发现相关开源项目、替代方案和最佳实践。

- [ ] gh CLI 降级方案、请求队列 + 限流。

---

## 14. GoEditorPlugin

> 目标：对 Go 项目提供接近 VS Code + Go 扩展的开发体验。

- [ ] Phase 1：LSP 基础。
- [ ] Phase 2：工程命令。
- [ ] Phase 3：测试系统。
- [ ] Phase 4：体验打磨。
- [ ] Phase 5：调试系统。

---

## 17. VueEditorPlugin

> 目标：对 Vue 3 SFC 提供原生般的单文件组件编辑体验。

- [ ] Phase 1：VolarServiceManager / VueVersionDetector、混合模式、VueTreeSitterRegistration。
- [ ] Phase 2：SFCBlockHighlighter / TemplateAttributeCompleter、区块导航命令。
- [ ] Phase 3：ComponentImportResolver / ScopedStyleHelper、ComponentRenamer / CSSModulesTypeGenerator。
- [ ] Phase 4：Vue DevTools 桥接、Vite 联动。

---

## 18. EditFileTool 改进

> Priority 0（先读后写+并发、1GB 大小保护）、Priority 1（引号风格保留、diff 质量）、Priority 2（相似文件提示）已完成。剩余：

- [ ] **编辑器/LSP 通知**：编辑完成后通知 EditorKernel 触发 didChange + didSave。（审计结论：open+clean 文件的情况已通过 `EditorExternalFileController` 1s 轮询 + `applyExternalContent` 的 `lspClient.replaceDocument` 自动满足 `didChange`；仅缺 external-reload 路径的 `didSave`。`LumiToolExecutionContext` 无 editor handle，强接入较重。）
- [ ] **编码检测**：当前通过 `String(contentsOf:usedEncoding:)` 做通用编码往返，已能保留检测到的编码；专门的 BOM/UTF-16LE 检测与全文件 LF/CRLF 往返未单独实现。
- [ ] **反标准化机制**：LLM XML 标签清理的反向映射（如 `<fnr>` → `<function_results>`）。
- [ ] **强制先读后写**：当前为「读取后才启用并发保护」的非破坏性策略；按产品策略开启强制拒绝未读取即编辑（行为变更，需产品确认，避免破坏现有 agent 工作流）。
- [ ] 👤 需要用户参与：验证并发编辑场景（同时用外部编辑器修改）。

---



## AutoTask 任务编辑

> 目标：对于 `pending` 状态的任务，允许用户在侧栏 UI 中直接编辑标题和描述。

- [ ] Phase 1：`TaskStateManager` 新增 `updateTaskContent(id:conversationId:title:detail:)`（仅 `pending` 可编辑）+ `autoTaskDidChange` 通知。
- [ ] Phase 2：`AutoTaskSidebarViewModel` 编辑状态管理（`editingTaskId` / `editingTitle` / `editingDetail`、`startEditing` / `confirmEditing` / `cancelEditing`）。
- [ ] Phase 3：`TaskRowView` 双击内联编辑、✓/✗ 按钮、非 `pending` 视觉区分、Enter/Escape 快捷键。
- [ ] Phase 4（可选）：`pending` 任务右键菜单「编辑任务」。
- [ ] 👤 需要用户参与：验证编辑交互手感。

---

## 22. search_code 工具性能优化

> Phase 1（文件发现）、Phase 2（grep + 超时 + 耗时日志 + discoverFiles 5min 缓存）、Phase 3（fallbackLimit + sqlite-vec 警告 + >3s 性能预警）已完成。剩余：

- [ ] retrieve 级别超时（`loadANNCandidates` + fallback）：当前仅在 tool 级别有共享 deadline，未在 retrieve 内部分别加超时（需协作取消，改动 retrieve 签名）。
- [ ] `RAGStatusBarView` 展示最近一次 search_code 的 keyword/semantic 各自耗时（单次搜索耗时为瞬时数据，需跨层 plumbing 到状态栏，属 UX 展示功能）。
- [ ] 👤 需要用户参与：在 Lumi 项目上分别测试 keyword / semantic / hybrid 响应时间。

---

