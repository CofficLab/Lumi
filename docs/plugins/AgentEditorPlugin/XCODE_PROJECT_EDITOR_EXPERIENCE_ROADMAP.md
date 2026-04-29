# AgentEditorPlugin Xcode Project Editor Experience Roadmap

## 目标

不是只把 `AgentEditorPlugin` 做成“能打开 Swift 文件的编辑器”，而是把它逐步推进成一个**管理 Xcode 项目时，编辑器核心体验接近 Xcode** 的工作台。

这份路线图只关注编辑器能力，不覆盖完整 IDE 的 archive / signing / distribution 能力。

核心成功标准：

1. 打开 `.xcodeproj` / `.xcworkspace` 后，Swift / ObjC / C / plist / entitlements / xcconfig 等常见文件的编辑体验连续
2. Swift 跨文件语义能力稳定可用：definition、declaration、type definition、implementation、references、rename、diagnostics、fix-it
3. 编辑器对 Xcode 项目的理解来自**工程编译上下文**，而不是“仅靠文件路径 + 通用 LSP root”
4. 用户在 Lumi 中处理 Xcode 工程时，不需要频繁回退到 Xcode 才能完成基础代码导航和重构

---

## 当前问题诊断

最近的跨文件 `Go to Definition` 失败已经暴露出一个结构性问题：当前 LSP 管线更像“通用文本编辑器接语言服务器”，还不是“理解 Xcode 项目的 Swift 编辑器”。

### 已确认现象

1. `JumpToDefinitionDelegate` 已发出正确的 definition 请求
2. 请求位置换算正确，且请求前没有待同步编辑
3. `sourcekit-lsp` 已成功启动，并声明支持 `definitionProvider`
4. 但对真实存在于工程内的 Swift 类型，`sourcekit-lsp` 返回 `nil`

### 根因判断

根因不是跳转 UI，也不是 AST/regex fallback，而是：

1. 当前只给 `sourcekit-lsp` 提供了 `rootUri`
2. 当前没有把完整的 Xcode build context 提供给 `sourcekit-lsp`
3. 当前没有明确的 workspace / project / target / scheme / destination / build settings 绑定
4. 因此 LSP 知道“你打开了一个 Swift 文件”，但未必知道“这个文件应按哪个工程配置被编译和解析”

### 为什么这会影响编辑器体验

对 Swift 来说，跨文件 definition / rename / references 不是文本能力，而是语义能力。它依赖：

1. target membership
2. module graph
3. SDK / toolchain / target triple
4. build settings
5. active compilation conditions
6. package dependency resolution

如果这层上下文不稳定，编辑器会出现这些症状：

1. 同文件能力看起来正常，跨文件能力间歇失效
2. diagnostics 与真实 `xcodebuild` 结果不一致
3. rename / fix-it / code action 不可靠
4. references / call hierarchy / workspace symbols 结果偏空或错误
5. 用户会误以为“编辑器功能做了，但总是不好用”

---

## 设计原则

### 1. Build Context First

对 Xcode 项目，语言能力的真相来源不是“当前打开的文件”，而是“这个文件在工程中的编译上下文”。

### 2. Workspace Identity First

`.xcworkspace`、`.xcodeproj`、scheme、target、configuration、destination 应该是编辑器一级概念，而不是隐藏在日志里的参数。

### 3. Language Fidelity Over Generic Fallback

对 Swift 语义导航，优先保证 `sourcekit-lsp` / build system 正确工作，而不是继续依赖 AST / regex 回退去伪装“功能可用”。

### 4. Editor Workflow Over Build UI

路线图重点放在会直接影响编辑体验的能力：

1. 打开工程
2. 选定 active scheme / target
3. 稳定的语义导航
4. 稳定的 diagnostics / fix-it / rename
5. 工程相关文件的 discoverability 与状态反馈

### 5. Xcode-Exact Where It Matters

不是所有 UI 都要像 Xcode，但下列体验需要尽量贴近：

1. scheme / destination / configuration 对编辑行为的影响
2. Swift package / target / build settings 的感知
3. Issue / fix-it / symbol navigation 的连续工作流

---

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

## 目标能力栈

### Layer 1: Project Identity

需要明确以下对象：

1. `XcodeWorkspaceContext`
2. `XcodeProjectContext`
3. `XcodeSchemeContext`
4. `XcodeTargetContext`
5. `XcodeBuildConfigurationContext`
6. `XcodeDestinationContext`

### Layer 2: Build Context Resolution

需要明确以下能力：

1. 识别当前文件属于哪个 workspace / project / target
2. 解出有效的编译参数与 module 上下文
3. 将 build context 挂到 `LSPService` / `LanguageServer` 生命周期上
4. context 变化后，能正确失效并重建语言服务

### Layer 3: Editor Language Fidelity

在有正确 build context 的前提下，稳定支持：

1. go to definition / declaration / type definition / implementation
2. find references
3. rename
4. diagnostics / fix-it / code actions
5. workspace symbols / document symbols / call hierarchy

### Layer 4: Xcode Project Editing Surface

需要补齐：

1. scheme / destination / configuration 状态展示
2. issues / problems / fix-it 的编辑器联动
3. package dependency / target / project settings 的编辑器可见性
4. Xcode 相关文件类型的更好编辑体验

---

## Roadmap

## Phase 1: Xcode Project Identity

### 目标

让编辑器明确知道“当前打开的是 Xcode 工程”，而不是把它当作普通文件夹。

### 任务

1. 建立 `XcodeWorkspaceContext` / `XcodeProjectContext` 数据模型
2. 识别当前根目录中的 `.xcworkspace` / `.xcodeproj`
3. 明确 active workspace / project 的来源规则
4. 建立文件到 project target 的归属查询接口

### 验收

1. 打开项目后，编辑器可明确显示当前 workspace / project
2. 任意 Swift 文件都能查询“属于哪个工程上下文”
3. 不再把 `projectRootPath` 当作唯一上下文

### 清单

- [ ] `XcodeWorkspaceContext`
- [ ] `XcodeProjectContext`
- [ ] `.xcworkspace` / `.xcodeproj` 自动识别
- [ ] 当前工程上下文状态存储
- [ ] 文件归属查询接口
- [ ] 基础日志与调试视图

---

## Phase 2: Scheme / Target / Configuration Awareness

### 目标

把会影响语义编辑结果的工程参数显式化。

### 任务

1. 解析 schemes、targets、build configurations
2. 建立 active scheme / target / configuration / destination 状态
3. 让这些状态可被编辑器和语言服务读取
4. scheme 切换时让语言管线正确失效

### 验收

1. 编辑器有明确的 active scheme / configuration 展示
2. 切换 scheme 后，语言服务会刷新上下文
3. 同一文件在不同 target 下可绑定不同语义上下文

### 清单

- [ ] scheme 列表解析
- [ ] target 列表解析
- [ ] configuration 列表解析
- [ ] destination 基础模型
- [ ] active scheme / target 状态栏入口
- [ ] 切换后的 context invalidation

---

## Phase 3: Build Context Provider

### 目标

让 Lumi 能为 `sourcekit-lsp` 提供真实可用的 Xcode 编译上下文。

### 任务

1. 设计 `XcodeBuildContextProvider`
2. 评估并接入可行的 build system 信息来源
3. 为每个打开文件生成稳定的编译上下文
4. 将 build context 从“工程级”细化到“文件级”

### 候选方案

1. `xcode-build-server` / `buildServer.json`
2. 调用 `xcodebuild -showBuildSettings`
3. 调用 `xcodebuild -list -json`
4. 必要时构建本地缓存层，避免每次打开文件都实时求值

### 验收

1. 对 Swift 文件，LSP 初始化不再只有 `rootUri`
2. 至少 definition / references / rename 对真实 Xcode 工程稳定工作
3. build context 可缓存、可失效、可诊断

### 清单

- [ ] `XcodeBuildContextProvider`
- [ ] `XcodeFileBuildContext`
- [ ] build settings 缓存
- [ ] build context 失效策略
- [ ] 缺失上下文时的明确错误提示
- [ ] build context inspector（调试面板或日志）

---

## Phase 4: SourceKit-LSP Integration Hardening

### 目标

把当前通用 LSP 接线提升为“面向 Xcode 项目的 Swift 语言服务接线”。

### 任务

1. 给 `sourcekit-lsp` 补齐 workspace / project / build system 输入
2. 修正当前 server 初始化与并发启动竞态
3. 对 definition / rename / references 等请求统一加入文档同步策略
4. 对 LSP 错误分类：server down / no context / unresolved symbol / stale state

### 验收

1. 同文件与跨文件导航成功率显著提升
2. 同一文件不会并发拉起多个 `sourcekit-lsp`
3. 失败时用户看到的是可行动错误，而不是统一 “No definition found”

### 清单

- [ ] `workspaceFolders` 补齐
- [ ] server 启动单飞保护
- [ ] definition / references / rename 前的 pending changes flush 策略
- [ ] Xcode-specific LSP error taxonomy
- [ ] LSP 状态栏可见反馈
- [ ] 跨文件导航专项测试

---

## Phase 5: Swift Semantic Navigation Parity

### 目标

补齐用户最敏感的 Swift 语义导航体验。

### 任务

1. 稳定化 definition / type definition / implementation / references
2. 建立返回栈、前进栈、peek/references 面板联动
3. 让跳转目标在编辑器、outline、breadcrumb、底部面板之间连续流动
4. 为语义失败场景提供清晰提示

### 验收

1. Swift 跨文件 definition 在主工程上稳定可用
2. references / call hierarchy / workspace symbols 与 definition 工作流打通
3. “没结果” 与 “上下文不可用” 能被区分

### 清单

- [ ] Swift definition 稳定性回归集
- [ ] type definition / implementation / declaration 联调
- [ ] references 面板与导航历史统一
- [ ] breadcrumb / outline / symbols 联动
- [ ] 跳转失败原因细分文案

---

## Phase 6: Swift Diagnostics, Fix-It, and Rename

### 目标

把“能跳转”提升到“能做日常 Swift 编辑工作”。

### 任务

1. 提高 diagnostics 与 `xcodebuild` 的一致性
2. 接入 fix-it / code action 的稳定应用链路
3. 稳定 Swift rename 的多文件编辑事务
4. 明确 unsaved buffer 与 diagnostics 刷新策略

### 验收

1. 常见 Swift 编译错误可在编辑器中及时看到
2. fix-it / quick fix 能稳定应用
3. rename 在多文件与 undo/redo 下保持稳定

### 清单

- [ ] Swift diagnostics 一致性比对
- [ ] fix-it / quick fix 事务接入
- [ ] 多文件 rename 验证
- [ ] 问题面板与编辑器 gutter 联动
- [ ] 保存前后 diagnostics 刷新策略统一

---

## Phase 7: Xcode Project File Editing

### 目标

让 Xcode 工程常见辅助文件的编辑体验不再是“普通文本框”。

### 任务

1. 提升对 `xcconfig`、`Info.plist`、`.entitlements`、`.pbxproj`、`Package.swift` 的编辑支持
2. 为工程元信息文件补齐 syntax / validation / quick navigation
3. 对项目结构相关文件提供更安全的编辑交互

### 验收

1. 常见工程配置文件有基础语言支持和错误提示
2. 与 scheme / target / build settings 相关文件可以被快速发现和定位
3. 高风险文件编辑具备最小保护

### 清单

- [ ] `xcconfig` 语法与跳转
- [ ] plist / entitlements 编辑优化
- [ ] `project.pbxproj` 风险控制策略
- [ ] `Package.swift` 与 package dependency 体验对齐
- [ ] 工程文件 quick open / symbol 支持

---

## Phase 8: Xcode-Oriented Editor UX

### 目标

把和 Xcode 项目强相关的编辑器状态反馈做成一等体验。

### 任务

1. 状态栏展示 active scheme / destination / configuration
2. 明确 LSP / build context / indexing 状态
3. issues / references / symbols / call hierarchy 面板联动统一
4. 把失败场景从日志搬到可见 UI

### 验收

1. 用户不用看日志也知道当前语义服务状态
2. build context 缺失时有清晰可操作提示
3. Xcode 项目编辑中最常用的上下文信息始终可见

### 清单

- [ ] scheme / destination 状态栏
- [ ] indexing / build context 状态提示
- [ ] problems / references / symbols 面板统一
- [ ] “当前文件未绑定有效 target” 提示
- [ ] “语言服务需要重新解析” 提示

---

## Phase 9: Reliability, Performance, and Regression Gates

### 目标

为 Xcode 项目编辑体验建立专属回归基线，而不是沿用通用文本编辑器标准。

### 任务

1. 建立真实 Xcode 工程样本集
2. 建立跨文件导航 / rename / diagnostics / package 解析回归测试
3. 建立性能基线：首次打开工程、首次语义请求、scheme 切换、索引恢复
4. 建立失败分类记录模板

### 验收

1. 每次结构性改动都能回归 Xcode 项目关键工作流
2. 失败原因可以被归类，而不是只表现为“有时不工作”
3. 工程规模扩大后，体验退化可被量化

### 清单

- [ ] Xcode 项目 fixture 集
- [ ] Swift cross-file navigation tests
- [ ] scheme switch regression tests
- [ ] build context cache correctness tests
- [ ] Xcode project stress playbook

---

## 优先级建议

### P0

1. Phase 1
2. Phase 2
3. Phase 3
4. Phase 4

没有这四步，Swift 跨文件编辑体验不会稳定。

### P1

1. Phase 5
2. Phase 6

这两步决定用户是否能把 Lumi 当作主力 Swift 编辑器使用。

### P2

1. Phase 7
2. Phase 8
3. Phase 9

这三步决定体验是否接近 Xcode，而不只是“能工作”。

---

## 近期行动建议

基于当前问题，最应该先做的不是继续补 AST fallback，而是：

1. 建立 `XcodeWorkspaceContext` / `XcodeBuildContextProvider`
2. 让 `sourcekit-lsp` 拿到真实 build context
3. 修正 LSP server 启动竞态与错误分类
4. 在真实 Lumi 工程上把 Swift cross-file definition 跑通并固化成回归用例

如果这一步不先做，后续 references、rename、fix-it、diagnostics 都会建立在不稳定的地基上。
