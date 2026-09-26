# Lumi 单元测试覆盖率提升报告

**日期**: 2026-09-26
**范围**: /Users/angel/Code/Coffic/Lumi/Packages（SwiftPM monorepo，233 个含源码包）

---

## 一、执行摘要

本次共触及 **35 个包**，新增 **243 个**有意义的单元测试，其中 **218 个已验证通过**，**25 个已编写但因网络依赖缺失暂无法编译验证**。

| 批次 | 包数 | 新增测试 | 状态 |
|------|------|----------|------|
| Provider 小包（10个） | 10 | +106 | ✅ 全部通过 |
| Kit 逻辑包（6个） | 6 | +38 | ✅ 全部通过 |
| LLMProvider 供应商包（15个） | 15 | +74 | ✅ 全部通过 |
| 原无测试包（4个） | 4 | +25 | ⚠️ 测试已写，无法编译验证 |
| **合计** | **35** | **+243** | **31/35 验证通过** |

此外，修复了 **15 个 LLMProvider 包中原有的无法编译的测试**（注册键引用了已删除的协议 `LLMProviderManagerProviding`），以及 Tencent 包过期的模型数量断言（24→实际 34）。

---

## 二、方法论

1. **先测量后动手**: 扫描全部 233 个包，按源文件数、测试文件数、远程依赖分类排序
2. **优先级排序**: 无测试包 → 覆盖率最低/逻辑密集的小包 → 其余包
3. **测试框架**: 统一使用 Swift Testing（`@Suite` / `@Test` / `#expect` / `Issue.record`），与仓库现有风格一致
4. **质量要求**: 正常路径 + 边界/错误路径断言，禁止空壳测试，不改动被测源码行为
5. **验证**: 每个包修改后独立运行 `swift test` 确认全部通过

---

## 三、逐包详细结果

### 批次 A：Provider 小包（10 个，全部通过 ✅）

| 包名 | 源文件 | 基线测试 | 新测试数 | 总测试 | 新增覆盖场景 |
|------|--------|----------|----------|--------|-------------|
| ProviderActivityHeatmap | 1 | 1 | +11 | 12 | commitCount 边界(负/零/极大)、Equatable/Hashable/Set去重、Codable往返、Snapshot排序稳定性、事件相等性 |
| ProviderAgentRules | 1 | 2 | +14 | 16 | 默认版本号、重复注册幂等、移除后顺序保持、空/空白id跳过、分组顺序、add/remove观察者通知、状态不变不通知、取消观察 |
| ProviderAppUpdate | 1 | 1 | +6 | 7 | rawValue正反查(含非法值/空串)、Codable往返、Hashable字典键/Set去重、userDefaultsKey常量 |
| ProviderDiagnostics | 1 | 1 | +8 | 9 | Equatable(相同/不同url/不同filename)、空filename、特殊字符URL、协议契约stub(logsDirectory/makeArchive/错误rethrows) |
| ProviderExternalFile | 1 | 2 | +8 | 10 | 无handler返回false、全拒绝返回false、同插件多handler按序、首个成功即停止、注销未知no-op、注销后重注册排末尾、standardized URL透传 |
| ProviderGitRepositoryWatch | 1 | 2 | +9 | 11 | 初始无监听、未监听stop no-op、切换广播started、stop后restart、standardized URL存储、重复start幂等、扇出观察者、二次cancel安全、事件相等性 |
| ProviderLLMContext | 1 | 5 | +26 | 31 | 预算负值钳零、effective/fallback window 4096下限、inputTokenLimit 1024下限、conservative()缩放、模式/来源rawValue、请求优先级解析、token估算(空文本=1/UTF8/空消息=0)、默认prepareContext扩展 |
| ProviderMessageStreaming | 1 | 3 | +9 | 12 | 四stage rawValue、change按UUID相等、end后start创建新消息、中途重置、未知会话end通知但状态保持、多观察者扇出、二次cancel安全、appendThinking初始化 |
| ProviderOnboarding | 1 | 6 | +8 | 14 | 默认空状态、多页面按注册顺序、unregister仅移除目标、replay未展示时自动展示、无onReplay不崩溃、多观察者事件、事件按case分类计数、dismiss后show重新通知 |
| ProviderProjectRAG | 1 | 3 | +17 | 20 | 四种MatchKind rawValue/相等性、line range单行/相等性、search result全字段Equatable、response结果顺序/空结果、IndexStatus全字段/Equatable、Event关联值相等性、默认扩展(isIndexing/observer/search重载/ensureIndexed/NoopHandle) |

**小计: 26 → 132 测试（+106）**

### 批次 B：Kit 逻辑包（6 个，全部通过 ✅）

| 包名 | 源文件 | 基线测试 | 新增 | 总测试 | 新增覆盖场景 |
|------|--------|----------|------|--------|-------------|
| KitLocalization | 1 | 5 | +8 | 13 | 构造临时bundle真实走运行时查找：lproj优先于xcstrings、lproj未命中回退catalog、zh-Hans catalog解析、zh-Hant-TW变体回退zh-TW、各语言专属key、未命中原样返回、记忆化缓存一致、preferredLocale非空 |
| KitHttp | 4 | 77 | +6 | 83 | onResponseReceived在2xx与503均回调(含响应头)、流式请求自动注入Accept头、行级流式网络错误包装、JSON请求POST往返与解析、KitHttpLocalization回退key |
| KitKeychain | 4 | 既有XCTest | +7 | +7 | 瞬时失败(errSecNotAvailable)后重试成功、stringWithoutPrompt成功路径(allowInteraction=false)、无提示迁移UserDefaults→Keychain并清理legacy、迁移写失败抛错且legacy不丢失、keychain已有值不触发迁移、Backend扩展默认allowInteraction=true |
| KitSuperLog | 6 | 既有XCTest | +7 | +7 | ms(_:) Duration格式化为毫秒串(1s/12ms/0.5s/1.5s边界)、author剥泛型<>、r()/makeReason包装➡️、onAppear/onInit/a/i前缀、实例author/className/isMain、级别路由(info/warning/error/debug)、静态log路由shared且caller截断文件名 |
| KitDownload | 9 | 75 | +4 | 79 | Configuration默认值(并发3/超时3600/续传/不限速/默认目录名)、自定义值覆盖、DownloadTaskState.isFinal对pending/downloading=false与completed/failed/cancelled=true |
| KitFileSystem | 11 | 79 | +6 | 85 | 编辑未命中oldString抛错且内容不变、oldString==newString抛错、非空文件传空oldString抛错、读取截断边界(内容恰等于上限时truncated=false)、WorkspaceReadFileState按会话隔离、iconSFSymbol更多扩展名映射(jpg/pdf/大小写) |

**小计: +38 测试**

### 批次 C：LLMProvider 供应商包（15 个，全部通过 ✅）

每个包统一从 1-2 个测试扩充至 6 个，覆盖：插件 metadata（id/name/description/category/stage/policy）、order、onBoot 注册唯一性与 providerInfo 全字段、模型列表完整有序且默认模型在列、关键模型上下文窗口/视觉能力、API endpoint URL、onBoot 缺管理器不抛错、onShutdown 不抛错。

| 包名 | 基线 | 总数 | 新增 | 关键模型/端点 |
|------|------|------|------|--------------|
| PluginLLMProviderAiRouter | 1 | 6 | +5 | 11模型(gpt-5.4=1M)、relay |
| PluginLLMProviderAnthropic | 1 | 6 | +5 | 7个Claude均200k+vision、Messages端点 |
| PluginLLMProviderCommandCode | 1 | 6 | +5 | **69个模型完整清单**、commandcode网关 |
| PluginLLMProviderFeifeimiao | 1 | 6 | +5 | 5模型、feifeimiao.top |
| PluginLLMProviderFlyMux | 1 | 6 | +5 | 2模型均1M+vision、flymux.ai |
| PluginLLMProviderHappyCode | 1 | 6 | +5 | 单模型1M、happycode.vip |
| PluginLLMProviderHyperAPI | 1 | 6 | +5 | 11模型(gpt-5.4=1M)、hyperapi.cc |
| PluginLLMProviderLPgpt | 1 | 6 | +5 | 2模型均1M、lpgpt.us |
| PluginLLMProviderMegaLLM | 1 | 6 | +5 | 13模型、逐模型vision标志、ai.megallm.io |
| PluginLLMProviderMiniMax | 1 | 6 | +5 | MiniMaxVendorModels.all共享清单与provider一致、5模型vision、minimaxi.com |
| PluginLLMProviderOpenAI | 1 | 6 | +5 | 7模型(gpt-4=8192/gpt-3.5=16385)、官方端点+includeUsageInStreamOptions |
| PluginLLMProviderOpenRouter | 1 | 6 | +5 | **19模型**(gpt-4o=128k)、openrouter.ai |
| PluginLLMProviderSublyx | 1 | 6 | +5 | 5模型(gpt-4o=128k其余1M)、sublyx.org |
| PluginLLMProviderTencent | 2 | 6 | +4 | **修正后34模型完整清单**(原断言24已过期)、tokenhub.tencentmaas.com |
| PluginLLMProviderXybbz | 1 | 6 | +5 | 2模型均1M、sub2api.xybbz.xyz |

**小计: ~16 → 90 测试（+74）**

**额外修复**: 全部 15 个包原有测试使用了已删除的协议 `(any LLMProviderManagerProviding).self` 作为注册键，导致无法编译；已统一修正为 `(any LLMManaging).self`。Tencent 原有模型数量断言(24)与实际(34)不符，已修正。

### 批次 D：原无测试包（4 个，测试已编写 ⚠️）

以下 4 个包原本完全没有 Tests/ 目录和 testTarget。测试文件和 Package.swift 配置已添加，但因 **MCP Swift SDK（modelcontextprotocol/swift-sdk）无法从 GitHub 克隆**（网络过慢，<1000 bytes/sec），依赖 KitMCP 的包无法完成依赖解析，故测试暂无法编译验证。

| 包名 | 源文件 | 新增测试 | 测试内容 | 状态 |
|------|--------|----------|----------|------|
| ProviderMCP | 1 | 4 | 协议可被类遵循、contribute透传完整字段、多次贡献按序累积、AnyObject身份比较 | ⚠️ 已写未验证 |
| PluginGithubMCP | 1 | 5 | metadata稳定、init/logger、onShutdown不抛错、无收集器时onBoot不崩溃、onBoot贡献GitHub模板(docker/ghcr.io) | ⚠️ 已写未验证 |
| PluginXcodeMCP | 1 | 5 | metadata稳定、init/logger、onShutdown不抛错、无收集器时onBoot不崩溃、onBoot贡献Xcode配置(xcrun mcpbridge) | ⚠️ 已写未验证 |
| FactoryLumiACP | 7 | 11 | ACPBootstrapError description/Error协议/抛捕、ACPPluginFactory返回≥50插件/含核心插件/含LLM供应商/ID唯一/新实例、迁移版本号=6、PluginFactory协议自定义实现 | ⚠️ 已写未验证 |

**小计: 0 → 25 测试（+25，未验证）**

> **验证方法**: 当网络恢复后，在每个包目录下执行 `swift test` 即可验证。测试代码遵循与已验证包相同的模式和断言质量。

---

## 四、覆盖率提升估算

由于 233 个包逐一运行 `--enable-code-coverage` 耗时极长（每包需完整构建+测试+llvm-cov导出），且大量包依赖远程 git 包，本次未做全量精确覆盖率测量。基于新增测试的断言密度和源码规模，估算如下：

- **10 个 Provider 小包**: 源码 3-209 行，新增测试覆盖了绝大部分公开 API，估算行覆盖率从 ~30% 提升至 ~70-90%
- **6 个 Kit 包**: 已有较好基础，新增测试填补了配置默认值、错误路径、边界条件等缺口，估算提升 5-15 个百分点
- **15 个 LLMProvider 包**: 原测试仅 1 个且多数无法编译，修复+扩充后覆盖了插件全部公开属性和生命周期，估算从 ~10% 提升至 ~60-80%
- **4 个无测试包**: 从 0% 起步，测试覆盖了可独立测试的类型和方法

---

## 五、限制与阻塞

1. **MCP Swift SDK 网络阻塞**: `modelcontextprotocol/swift-sdk.git` 无法克隆（GitHub 网络过慢），导致所有依赖 KitMCP 的包（ProviderMCP、PluginGithubMCP、PluginXcodeMCP、FactoryLumiACP、PluginMCP、KitMCP 等）无法构建测试。这 4 个包的测试已编写，待网络恢复后可直接验证。

2. **全量覆盖率测量未执行**: 233 个包逐一运行覆盖率测量不现实。建议后续在 CI 中集成 `swift test --enable-code-coverage` + `llvm-cov report` 做持续追踪。

3. **未覆盖包**: 本次聚焦 35 个优先级最高的包（无测试包 + 小包 + 逻辑密集包）。其余 198 个包未触及，其中：
   - 31 个大包（>20 源文件）需要更多投入
   - 纯 UI 层包（SwiftUI View）单元测试价值有限
   - 强依赖网络/硬件/权限的包需要 mock 基础设施

4. **磁盘空间**: 过程中磁盘一度占满（多包并行构建的 .build 目录），已清理已验证包的可再生 .build 目录。

---

## 六、后续建议

1. **网络恢复后**: 执行 4 个未验证包的 `swift test`，确认通过
2. **CI 集成**: 在仓库 CI 中添加覆盖率测量步骤，使用 `swift test --enable-code-coverage` + `xcrun llvm-cov report`
3. **下一批优先级**:
   - 中号 Provider 包（ProviderCommand、ProviderConversationInput、ProviderGit 等，2-3 源文件）
   - PluginOpenIn* 家族（6 个包结构高度统一，4 源文件）
   - KitPrototype、KitResume（6 源文件，仅 1 个测试）
4. **Mock 基础设施**: 为强依赖网络/硬件的包建立共享 mock 层，降低测试编写门槛
5. **大包包**: KitEditorSource（169 文件）、KitEditorKernel（110 文件）、PluginCodeEditorHost（144 文件）等需要专项投入

---

## 七、改动文件清单

### 新增测试文件（17 个）
- `Packages/ProviderMCP/Tests/ProviderMCPTests/MCPServerContributionProvidingTests.swift`
- `Packages/PluginGithubMCP/Tests/PluginGithubMCPTests/PluginGithubMCPTests.swift`
- `Packages/PluginXcodeMCP/Tests/PluginXcodeMCPTests/PluginXcodeMCPTests.swift`
- `Packages/FactoryLumiACP/Tests/FactoryLumiACPTests/FactoryLumiACPTests.swift`
- `Packages/KitLocalization/Tests/KitLocalizationTests/LumiLocalizationResolutionTests.swift`
- `Packages/KitHttp/Tests/HTTPClientCoverageTests.swift`
- `Packages/KitKeychain/Tests/KitKeychainTests/KeychainStoreAdditionalCoverageTests.swift`
- `Packages/KitSuperLog/Tests/SuperLogCoverageTests.swift`
- `Packages/KitDownload/Tests/DownloadConfigurationAndStateTests.swift`
- `Packages/KitFileSystem/Tests/KitFileSystemCoverageTests.swift`

### 修改测试文件（25 个）
- 10 个 Provider 包的现有测试文件（追加测试）
- 15 个 LLMProvider 包的现有测试文件（重写+修复注册键）

### 修改 Package.swift（4 个）
- `Packages/ProviderMCP/Package.swift`（添加 testTarget）
- `Packages/PluginGithubMCP/Package.swift`（添加 testTarget）
- `Packages/PluginXcodeMCP/Package.swift`（添加 testTarget）
- `Packages/FactoryLumiACP/Package.swift`（添加 testTarget）

> 注：`Packages/FactoryLumi/` 和 `Packages/PluginChromeMCP/` 的改动非本次任务产生，未予触碰。
