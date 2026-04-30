# AgentEditorPlugin Xcode Project Editor Experience Roadmap

## 目标

不是只把 `AgentEditorPlugin` 做成"能打开 Swift 文件的编辑器"，而是把它逐步推进成一个**管理 Xcode 项目时，编辑器核心体验接近 Xcode** 的工作台。

这份路线图只关注编辑器能力，不覆盖完整 IDE 的 archive / signing / distribution 能力。

核心成功标准：

1. 打开 `.xcodeproj` / `.xcworkspace` 后，Swift / ObjC / C / plist / entitlements / xcconfig 等常见文件的编辑体验连续
2. Swift 跨文件语义能力稳定可用：definition、declaration、type definition、implementation、references、rename、diagnostics、fix-it
3. 编辑器对 Xcode 项目的理解来自**工程编译上下文**，而不是"仅靠文件路径 + 通用 LSP root"
4. 用户在 Lumi 中处理 Xcode 工程时，不需要频繁回退到 Xcode 才能完成基础代码导航和重构

## 设计原则

### 1. Build Context First

对 Xcode 项目，语言能力的真相来源不是"当前打开的文件"，而是"这个文件在工程中的编译上下文"。

### 2. Workspace Identity First

`.xcworkspace`、`.xcodeproj`、scheme、target、configuration、destination 应该是编辑器一级概念，而不是隐藏在日志里的参数。

### 3. Language Fidelity Over Generic Fallback

对 Swift 语义导航，优先保证 `sourcekit-lsp` / build system 正确工作，而不是继续依赖 AST / regex 回退去伪装"功能可用"。

### 4. Editor Workflow Over Build UI

路线图重点放在会直接影响编辑体验的能力。

### 5. Xcode-Exact Where It Matters

不是所有 UI 都要像 Xcode，但 scheme / destination / configuration 对编辑行为的影响、Swift package / target / build settings 的感知、Issue / fix-it / symbol navigation 的连续工作流需要尽量贴近。

## 范围

### In Scope

1. `.xcodeproj` / `.xcworkspace` 打开与识别
2. build context 建立与切换
3. Swift / ObjC / C / C++ 语言能力稳定化
4. 编辑器内 diagnostics / fix-it / navigation / rename / references
5. scheme / target / destination 对编辑器的上下文绑定
6. package dependency、xcconfig、Info.plist、entitlements 等工程相关编辑体验

### Out of Scope

1. 签名、archive、上传、TestFlight 发布
2. Instruments、LLDB 调试器、Interface Builder 完整复刻
3. Xcode Organizer、证书管理、设备管理完整复刻

---

## 已完成基线（代码库现状）

以下是当前代码库中**已经完整实现**的能力，作为新 Phase 的起点：

### 项目识别与解析
- `XcodeWorkspaceContext` / `XcodeProjectContext` / `XcodeTargetContext` / `XcodeSchemeContext` / `XcodeDestinationContext` / `XcodeBuildConfigurationContext` — 完整的 Xcode 工程模型层
- `XcodeProjectResolver` — 自动发现 `.xcworkspace` / `.xcodeproj`，调用 `xcodebuild -list -json` 解析
- `XcodeBuildSettingsParser` — 解析 `xcodebuild -list -json` 和 `xcodebuild -showBuildSettings -json` 输出
- `XcodePBXProjParser` — 轻量级 pbxproj 解析（支持 File System Synchronized Group 模式）
- 文件归属查询 — `findTargetsForFile` / `resolvePreferredTarget` / `targetsCompatibleWithActiveScheme`
- `XcodeEditorContextSnapshot` — Sendable 快照供编辑器消费

### Build Context 生成
- `XcodeBuildContextProvider` — 完整生命周期：项目发现 → 解析 → xcode-build-server 查找 → buildServer.json 生成 → 缓存 → 文件归属查询
- `XcodeFileBuildContext` — 文件级编译上下文（SDK / toolchain / target triple / header search paths / framework search paths / active compilation conditions / module name）
- build settings 缓存策略 — `workspace|scheme|configuration|destination` 缓存键
- context 失效机制 — `invalidateAllContexts()` / scheme 切换自动失效
- `BuildContextStatus` 枚举 — `unknown` / `resolving` / `available` / `unavailable` / `needsResync`

### SourceKit-LSP 集成
- `XcodeProjectContextBridge` — XcodeProjectEditorPlugin 与 LSPService 之间的桥梁
- workspaceFolders 正确生成 — `makeWorkspaceFolders()` 为 sourcekit-lsp 生成参数
- `LanguageServer` 接受 workspaceFolders，不再硬编码 nil
- pending changes flush 策略 — definition / references / rename 前 flush
- `LSPDebouncer` — 文档同步防抖和节流
- LSP 自动恢复机制 — transport 断链检测 → 重启 → 重开文档

### 语义导航
- definition / type definition / implementation / declaration — 通过 LSP 请求完整实现
- references / call hierarchy / workspace / document symbols — 已实现
- `EditorJumpToDefinitionDelegate` — Cmd+Click 跳转 + AST 回退 + regex 回退
- preflight 拦截 — `XcodeSemanticAvailability.preflightMessage()` / `preflightError()`
- missing result 分类 — `missingResultMessage()` 区分"没结果"与"上下文不可用"

### 诊断与重构
- diagnostics 发布处理 — `handlePublishDiagnostics`
- rename / code action / fix-it — 请求链路完整
- 问题面板集成 — `ProblemsPanelView` 与 LSP diagnostics 分区显示

### 错误处理与可用性
- `XcodeLSPErrorTaxonomy` — 13 种错误分类，每种含 `errorDescription` + `suggestedAction` + `category`
- `XcodeLSPErrorClassifier` — 通用错误 → Xcode 特定错误分类，含 `classifyPreflight` / `classify` / `classifyMissingResult`
- `XcodeSemanticAvailability` — 统一语义可用性检查（workspace 级 + 文件级），9 种原因类型

### 编辑器 UX
- `XcodeProjectStatusBar` — scheme / configuration / destination 选择器 + build context 状态指示器
- `XcodeProjectStatusDetailView` — 浮窗详情含完整上下文信息 + semantic availability 报告
- `XcodeFileNotInTargetWarning` — 文件未绑定 target 提示
- "需要重新解析" 提示 — needsResync 状态 + 重新解析按钮
- `BridgeCachedState` — Sendable 缓存快照
- 通知中心事件 — `lumiEditorXcodeContextDidChange` / `lumiEditorXcodeSnapshotDidChange`

### 工程文件编辑
- `XCConfigSyntax` — xcconfig 语法高亮（comment / include / key / value / operator / variable reference / string）
- `XCConfigValidator` — xcconfig 验证器
- `PlistEditing` — Info.plist key 参考（19 个）+ Entitlements key 参考（10 个）+ 基础验证 + key 定位

### 测试
- `XcodeProjectFixtureFactory` — Xcode 项目 fixture 工厂
- `XcodePBXProjParserTests` — pbxproj 归属解析测试
- `XcodeSemanticAvailabilityTests` — semantic availability 规则测试（9 个用例）
- `WorkspaceSymbolProviderTests` — workspace symbols 消费层测试
- `CallHierarchyProviderTests` — call hierarchy 消费层测试
- `LSPCoordinatorDocumentSymbolsTests` — document symbols 消费层测试

---

## Phase 1: 全面工程解析（XcodeProj 集成）

**目标**：引入 `tuist/XcodeProj` 替换手写的 `XcodePBXProjParser`，让 Lumi 能解析**所有类型**的 Xcode 项目（不仅是 Xcode 16 的 File System Synchronized Group 模式）。

当前 `XcodePBXProjParser` 仅支持 Xcode 16 新格式的 target → 文件归属，无法处理传统 PBXBuildFile / PBXSourcesBuildPhase 模式的项目，这会直接影响大量存量项目的语义编辑体验。

- [ ] 引入 [tuist/XcodeProj](https://github.com/tuist/XcodeProj)（MIT）作为 SPM 依赖
  - SPM 集成：`.package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0"))`
  - `XcodeProj` 被Tuist / XcodeGen / Sourcery 等项目生产使用，支持所有 pbxproj section 的完整解析和读写
- [ ] 用 `XcodeProj` 重写 `XcodePBXProjParser`，覆盖传统 PBXBuildFile / PBXSourcesBuildPhase / PBXHeadersBuildPhase 模式
  - 同时保留 File System Synchronized Group 模式的支持
  - 确保 `MembershipGraph` 接口不变，上层调用方无需修改
- [ ] 用 `XcodeProj` 解析 PBXGroup / PBXFileReference 树，暴露项目 navigator 数据源接口
  - 提供 `ProjectNavigatorDataSource` 协议，为后续项目文件树 UI 提供数据
- [ ] 用 `XcodeProj` 直接读取 Build Configuration 的 settings 字典，减少对 `xcodebuild -showBuildSettings` 的进程调用依赖
  - 仅在需要展开 build setting 变量（`$(SRCROOT)` 等）时才 fallback 到 `xcodebuild`
- [ ] 用 `XcodeProj` 解析 PBXTargetDependency，暴露 target 间依赖关系
  - 用于 scheme 自动选择和依赖关系可视化
- [ ] 为新的解析逻辑编写回归测试
  - 传统 Build Phase 项目 fixture
  - File System Synchronized Group 项目 fixture
  - 混合项目 fixture

**交付标准**：打开任意 `.xcodeproj`（无论新旧格式），target → 文件归属查询都能正确工作。

---

## Phase 2: 导航体验完善（返回栈 / 面板联动）

**目标**：补齐用户最敏感的编辑器导航体验，让跨文件跳转、返回、面板之间的联动形成完整闭环。

- [ ] 实现导航返回栈 / 前进栈（Navigation Back / Forward Stack）
  - 记录每次跨文件跳转的来源和目标
  - 支持快捷键和工具栏按钮
  - 栈深度上限（如 100 条），防止内存膨胀
- [ ] references 面板与导航历史联动
  - 从 references 面板跳转后，自动记入导航栈
  - 支持从导航栈回到 references 面板的上一次上下文
- [ ] breadcrumb / outline / symbols 三者联动
  - 当前 breadcrumb 已有 `BreadcrumbToolBarView`，需与 document symbols 联动
  - 光标移动时 breadcrumb 自动跟踪当前 scope
  - 点击 breadcrumb 节点跳转到对应 outline / symbol 位置
- [ ] Swift 跨文件 definition 稳定性回归集
  - 编写针对真实 Xcode 工程的跨文件跳转测试用例
  - 覆盖：同 target 内跳转、跨 target 跳转、系统框架跳转、SPM 依赖跳转

**交付标准**：用户执行跨文件跳转后可以通过快捷键返回；breadcrumb 实时反映光标所在 scope。

---

## Phase 3: 诊断与重构稳定性

**目标**：把"能跳转"提升到"能做日常 Swift 编辑工作"——diagnostics 准确、rename 稳定、问题面板和编辑器 gutter 联动。

- [ ] diagnostics 与 `xcodebuild build` 输出的一致性比对
  - 确认 sourcekit-lsp diagnostics 和 `xcodebuild` 输出的差异范围
  - 对关键 diagnostic（error / warning）确保不会遗漏或误报
- [ ] 多文件 rename 端到端验证
  - 测试 Swift 跨文件 rename 在各种场景下的正确性
  - 覆盖：同 target rename、跨 target rename、protocol + extension rename、泛型 rename
- [ ] 问题面板与编辑器 gutter 联动
  - gutter 中的 diagnostic icon 点击后跳转到问题面板对应条目
  - 问题面板条目点击后跳转到编辑器对应行并高亮
  - 文件切换时 gutter diagnostic 同步更新
- [ ] 保存前后 diagnostics 刷新策略统一
  - 保存文件后自动触发 diagnostics 更新
  - 避免"保存后 diagnostics 消失又重现"的闪烁问题

**交付标准**：用户在日常 Swift 编辑中，diagnostics 和 rename 的准确性和稳定性达到可信赖的水平。

---

## Phase 4: 工程文件编辑增强

**目标**：让 Xcode 工程常见辅助文件的编辑体验不再是"普通文本框"。

- [ ] xcconfig include 指令的文件跳转
  - `#include "path"` 中的路径支持 Cmd+Click 跳转到目标文件
  - 支持相对路径解析（相对于当前 xcconfig 文件所在目录）
- [ ] plist / entitlements 语法高亮与智能编辑
  - XML plist 的 key / value / dict / array / string / data 等节点的语法高亮
  - 编辑 value 时自动补全常见 key 对应的 value 类型
  - 对已知 key 提供 hover 信息
- [ ] `project.pbxproj` 风险控制策略
  - 检测 pbxproj 是否有外部修改（Xcode 同时打开时）
  - 提供"以 Xcode 版本为准 / 以 Lumi 版本为准"的冲突解决提示
  - pbxproj 编辑前确认提示
- [ ] `Package.swift` 与 package dependency 体验对齐
  - 支持 `Package.swift` 中 `.package(url:)` 的 Cmd+Click 跳转到依赖仓库（浏览器）
  - package dependency 版本列表的 hover 信息
- [ ] 工程文件 quick open / symbol 支持
  - quick open 中区分工程文件（xcconfig / plist / entitlements / pbxproj）的搜索权重
  - 支持搜索 plist key、xcconfig key

**交付标准**：xcconfig 的 include 可跳转；plist 编辑有基本高亮和补全；pbxproj 有修改冲突保护。

---

## Phase 5: 状态反馈与索引进度

**目标**：让用户对"编辑器现在处于什么状态"有完整的感知，不再出现"为什么跳转没有结果"的困惑。

- [ ] "LSP 正在索引"的进度指示
  - sourcekit-lsp 的 `window/workDoneProgress` 事件接入
  - 状态栏或编辑器底部显示索引进度条
  - 索引完成前的语义请求自动排队等待，而不是直接返回空结果
- [ ] indexing / build context 状态的实时展示
  - 将 `BuildContextStatus` 和 indexing 状态统一到一个连续的状态机
  - 状态变化时的平滑过渡动画
  - 长时间未就绪时提供可操作的提示（如"检查 xcode-build-server 版本"）
- [ ] 语义就绪状态的通知
  - 从"解析中"变为"就绪"时发送用户可见的轻量通知（如编辑器底部 toast）
  - 避免用户在未就绪时困惑于语义功能为何不可用

**交付标准**：用户打开 Xcode 项目后，能清楚看到 build context 解析 → LSP 初始化 → 索引中 → 就绪的完整状态链路。

---

## Phase 6: 可靠性与回归基线

**目标**：为 Xcode 项目编辑体验建立专属回归基线，确保每次迭代不引入退化。

- [ ] Swift cross-file navigation tests
  - 基于 fixture 工程的跨文件 definition / declaration / typeDefinition / implementation 端到端测试
  - 需要 LSP 测试基础设施（mock 或真实 sourcekit-lsp 实例）
- [ ] scheme switch regression tests
  - 验证 scheme 切换后 build context 正确失效和重建
  - 验证 scheme 切换后缓存被清理
  - 验证 scheme 切换后 LSP 请求使用新上下文
- [ ] build context cache correctness tests
  - 验证缓存键 `workspace|scheme|configuration|destination` 的唯一性
  - 验证缓存失效的完整性
  - 验证缓存优先 → 实时获取 fallback 的正确性
- [ ] Xcode project stress playbook
  - 大型项目（100+ targets / 1000+ source files）的打开和解析性能基准
  - 快速 scheme 切换（连续切换 10 次）的稳定性
  - build context 并发请求的安全性
- [ ] 真实 Xcode 工程样本集
  - 建立 3-5 个不同类型的真实 Xcode 工程样本（macOS app / iOS app / framework / SPM + Xcode 混合）
  - 用于手动和自动化的端到端验证

**交付标准**：每个 Phase 的 PR 都有对应的回归测试；大型项目打开和 scheme 切换不会出现回归。
