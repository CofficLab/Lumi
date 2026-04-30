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

## Phase 1: Xcode Project Identity

让编辑器明确知道"当前打开的是 Xcode 工程"，而不是把它当作普通文件夹。

### ✅ Phase 1 完成清单

- [x] `XcodeWorkspaceContext` — 工作空间模型，包含 projects / schemes / activeScheme / activeDestination
- [x] `XcodeProjectContext` — 项目模型，包含 targets / buildConfigurations / schemes
- [x] `XcodeTargetContext` — Target 模型，包含 sourceFiles / buildConfigurations
- [x] `XcodeSchemeContext` — Scheme 模型，包含 buildableTargets / activeConfiguration / activeDestination
- [x] `XcodeDestinationContext` — 构建目标模型（macOS / iOS / Simulator 等）
- [x] `XcodeBuildConfigurationContext` — Build Configuration 模型
- [x] `XcodeProjectResolver` — 自动发现 `.xcworkspace` / `.xcodeproj`，调用 `xcodebuild -list -json` 解析
- [x] `XcodeBuildSettingsParser` — 解析 `xcodebuild -list -json` 和 `xcodebuild -showBuildSettings -json` 输出
- [x] `.xcworkspace` / `.xcodeproj` 自动识别 — `findWorkspace(in:)` 优先 workspace 再 project
- [x] 文件归属查询接口 — `findTargetsForFile(fileURL:)` / `resolvePreferredTarget(for:)`
- [x] `XcodeEditorContextSnapshot` — 供编辑器主链路消费的 Sendable 快照

---

## Phase 2: Scheme / Target / Configuration Awareness

把会影响语义编辑结果的工程参数显式化。

### ✅ Phase 2 完成清单

- [x] scheme 列表解析 — `xcodebuild -list -json` 输出解析
- [x] target 列表解析 — 同上
- [x] configuration 列表解析 — 同上
- [x] destination 基础模型 — `XcodeDestinationContext`，含 `destinationQuery` 和平台推导
- [x] `setActiveScheme(_:)` — 切换 scheme，清理缓存，重新生成 `buildServer.json`
- [x] `setActiveConfiguration(_:)` — 切换 configuration
- [x] scheme 切换后的 context invalidation — `invalidateAllContexts()` / `invalidateContext(for:)`
- [x] 智能 scheme 自动选择 — `selectBestScheme()`：同名 > target 同名 > 排除依赖包 > 兜底
- [x] active scheme / target 状态栏入口 — 在 Phase 8 的 `XcodeProjectStatusBar` 中实现
- [x] destination 从 build settings 推导 — `deriveDestination(from:)` 支持 macOS / iOS / tvOS / watchOS 及其 Simulator

---

## Phase 3: Build Context Provider

让 Lumi 能为 `sourcekit-lsp` 提供真实可用的 Xcode 编译上下文。

### ✅ Phase 3 完成清单

- [x] `XcodeBuildContextProvider` — 完整生命周期：项目发现 → 解析 → xcode-build-server 查找 → buildServer.json 生成 → 缓存 → 文件归属查询
- [x] `XcodeFileBuildContext` — 文件级编译上下文（含 SDK / toolchain / target triple / header search paths / framework search paths / active compilation conditions / module name）
- [x] `XcodePBXProjParser` — 轻量级 pbxproj 解析，支持 File System Synchronized Group 模式的 target → 文件归属和 membershipExceptions
- [x] build settings 缓存 — 缓存键 `workspace|scheme|configuration|destination`，缓存优先 → 实时获取 fallback
- [x] build context 失效策略 — `invalidateAllContexts()` / `invalidateContext(for:)` / scheme 切换自动失效
- [x] `BuildContextStatus` 枚举 — `unknown` / `resolving` / `available` / `unavailable` / `needsResync`，含 `displayDescription`
- [x] 缺失上下文时的明确错误提示 — 通过 `BuildContextStatus.unavailable(reason)` 和 `XcodeSemanticAvailability` 展示
- [x] `xcode-build-server` 路径查找 — 支持多路径探测 + `which` fallback

### ⚠️ Phase 3 待完善清单

- [ ] 引入 [tuist/XcodeProj](https://github.com/tuist/XcodeProj)（2200⭐，MIT）替换手写的 `XcodePBXProjParser`
  - 当前 `XcodePBXProjParser` 仅支持 Xcode 16 的 File System Synchronized Group 模式，无法解析传统 Build Phase 项目
  - `XcodeProj` 支持所有 pbxproj section 的完整解析和读写，被 Tuist / XcodeGen / Sourcery 等项目生产使用
  - SPM 集成：`.package(url: "https://github.com/tuist/XcodeProj.git", .upToNextMajor(from: "8.12.0"))`
- [ ] 用 `XcodeProj` 重写 target → 文件归属查询，覆盖传统 PBXBuildFile / PBXSourcesBuildPhase 模式
- [ ] 用 `XcodeProj` 解析 PBXGroup / PBXFileReference 树，为项目 navigator 提供数据源
- [ ] 用 `XcodeProj` 直接读取 Build Configuration，减少对 `xcodebuild -showBuildSettings` 的进程调用依赖
- [ ] 用 `XcodeProj` 解析 Target Dependency，支持 target 间依赖关系的可视化

---

## Phase 4: SourceKit-LSP Integration Hardening

把当前通用 LSP 接线提升为"面向 Xcode 项目的 Swift 语言服务接线"。

### ✅ Phase 4 完成清单

- [x] `XcodeProjectContextBridge` — XcodeProjectEditorPlugin 与 LSPService 之间的桥梁，管理 provider 注册、缓存状态、workspace folders 生成
- [x] `XcodeProjectEditorPlugin.register()` 向 Bridge 注册 buildContextProvider
- [x] `LSPService.setProjectRootPath()` 触发 `XcodeProjectContextBridge.projectOpened(at:)`
- [x] `workspaceFolders` 补齐 — `LSPService.makeWorkspaceFolders()` 为 sourcekit-lsp 生成正确的 workspaceFolders
- [x] `LanguageServer.create()` 接受 `workspaceFolders` 参数
- [x] `LanguageServer.makeInitParams()` 使用传入的 workspaceFolders，不再硬编码 `nil`
- [x] definition / references / rename 前的 pending changes flush 策略 — `flushPendingChangesIfNeeded(uri:operation:)`
- [x] `LSPDebouncer` — 文档同步防抖（debounce）和节流（throttle）
- [x] `XcodeLSPErrorTaxonomy` — 13 种错误分类（server / project / build / semantic / timeout），每种含 `errorDescription` + `suggestedAction` + `category`
- [x] `XcodeLSPErrorClassifier` — 将通用错误分类为 Xcode 特定错误，含 `classifyPreflight` / `classify` / `classifyMissingResult`
- [x] LSP 自动恢复机制 — `recoverServerIfNeeded` 检测 transport 断链 → 重启 → 重开文档

---

## Phase 5: Swift Semantic Navigation Parity

补齐用户最敏感的 Swift 语义导航体验。

### ✅ Phase 5 完成清单

- [x] definition / type definition / implementation / declaration 请求已在 `LSPService` 中实现
- [x] references / call hierarchy / workspace symbols 已实现
- [x] 跳转失败原因细分 — `XcodeSemanticAvailability.preflightMessage()` / `missingResultMessage()` 区分 "没结果" 与 "上下文不可用"
- [x] `JumpToDefinitionDelegate` 集成 `XcodeSemanticAvailability` preflight 和 missing result 分类
- [x] workspace / document symbols 接入 Xcode semantic availability preflight
- [x] call hierarchy 接入 Xcode semantic availability preflight

### ⚠️ Phase 5 待完善清单

- [ ] 返回栈 / 前进栈导航
- [ ] references 面板与导航历史统一
- [ ] breadcrumb / outline / symbols 联动
- [ ] Swift 跨文件 definition 稳定性回归集

---

## Phase 6: Swift Diagnostics, Fix-It, and Rename

把"能跳转"提升到"能做日常 Swift 编辑工作"。

### ✅ Phase 6 完成清单

- [x] diagnostics 发布处理 — `handlePublishDiagnostics` 接收 LSP diagnostics
- [x] rename / code action / fix-it 请求链路完整 — `LSPService` 中 rename 和 code action 前均 flush pending changes
- [x] 自动恢复机制 — `recoverServerIfNeeded` 检测断链后重启并重开文档
- [x] 问题面板集成 Xcode semantic problems — `ProblemsPanelView` 与 LSP diagnostics 分区显示

### ⚠️ Phase 6 待完善清单

- [ ] diagnostics 与 `xcodebuild` 一致性比对
- [ ] 多文件 rename 端到端验证
- [ ] 问题面板与编辑器 gutter 联动
- [ ] 保存前后 diagnostics 刷新策略统一

---

## Phase 7: Xcode Project File Editing

让 Xcode 工程常见辅助文件的编辑体验不再是"普通文本框"。

### ✅ Phase 7 完成清单

- [x] `XCConfigSyntax` — xcconfig 语法高亮（comment / include / key / value / operator / variable reference / string）
- [x] `XCConfigValidator` — xcconfig 验证器（include 格式检查、键值对格式检查）
- [x] `PlistEditing` — Info.plist 常见 key 参考（19 个）+ Entitlements key 参考（10 个）+ 基础验证 + key 定位

### ⚠️ Phase 7 待完善清单

- [ ] xcconfig include 指令的文件跳转
- [ ] plist / entitlements 语法高亮与智能编辑
- [ ] `project.pbxproj` 风险控制策略（当前仅有读取解析）
- [ ] `Package.swift` 与 package dependency 体验对齐
- [ ] 工程文件 quick open / symbol 支持

---

## Phase 8: Xcode-Oriented Editor UX

把和 Xcode 项目强相关的编辑器状态反馈做成一等体验。

### ✅ Phase 8 完成清单

- [x] `XcodeProjectStatusBar` — 状态栏显示 scheme 选择器 + configuration 选择器 + destination 芯片 + build context 状态指示器（5 种状态 + 颜色编码）
- [x] `XcodeProjectStatusDetailView` — 浮窗详情：workspace / scheme / config / destination / build context / current file target / matched targets / semantic availability
- [x] 集成到 `EditorPlugin.addStatusBarTrailingView()`
- [x] `XcodeFileNotInTargetWarning` — 文件未绑定到 target 的提示组件
- [x] `XcodeSemanticAvailability` — 统一语义可用性检查（workspace 级 + 文件级），9 种原因类型，hard / soft 两种 preflight 强度
- [x] `XcodeSemanticAvailability.preflightError` / `preflightMessage` — LSP 请求前 preflight 拦截
- [x] `XcodeSemanticAvailability.missingResultMessage` — 区分 "符号不存在" 与 "上下文不可用"
- [x] LSP isInitializing 状态追踪
- [x] Problems 面板集成 Xcode semantic problems，支持手动 `重新解析` build context
- [x] 通知中心事件 — `lumiEditorXcodeContextDidChange` / `lumiEditorXcodeSnapshotDidChange`
- [x] 多消费方集成 — `WorkspaceSymbolProvider` / `LSPCoordinator` / `ProblemsPanelView` / `CallHierarchySheetView` / `EditorReferencesPanelView`
- [x] `BridgeCachedState` — Sendable 缓存快照，供非主线程安全访问
- [x] "当前文件未绑定有效 target" 提示 — 通过 `XcodeSemanticAvailability` 的 `file-not-in-target` reason 实现
- [x] "语言服务需要重新解析" 提示 — 通过 `needsResync` 状态 + 重新解析按钮实现

### ⚠️ Phase 8 待完善清单

- [ ] "LSP 正在索引" 的进度指示
- [ ] indexing / build context 状态的实时展示

---

## Phase 9: Reliability, Performance, and Regression Gates

为 Xcode 项目编辑体验建立专属回归基线。

### ✅ Phase 9 完成清单

- [x] `XcodeProjectFixtureFactory` — Xcode 项目 fixture 工厂（PBXProj 文本 fixture）
- [x] `XcodePBXProjParserTests` — pbxproj 归属解析测试（2 个用例：正常解析 + 空 section fallback）
- [x] `XcodeSemanticAvailabilityTests` — semantic availability / preflight 规则测试（9 个用例：覆盖 soft/hard preflight、file-not-in-target、scheme-mismatch、multi-target、needsResync 等）
- [x] `WorkspaceSymbolProviderTests` — workspace symbols 消费层回归测试（2 个用例：preflight 拦截 + 符号映射）
- [x] `CallHierarchyProviderTests` — call hierarchy 消费层回归测试（2 个用例：空结果清理 + incoming/outgoing 映射）
- [x] `LSPCoordinatorDocumentSymbolsTests` — document symbols 消费层回归测试（2 个用例：soft preflight 拦截 + 符号返回）

### ⚠️ Phase 9 待完善清单

- [ ] Swift cross-file navigation tests
- [ ] scheme switch regression tests
- [ ] build context cache correctness tests
- [ ] Xcode project stress playbook
- [ ] 真实 Xcode 工程样本集

