# AgentTool 动态注入(per-request)改造 — 最终计划

## 目标
把工具集从「启动时一次性冻结进全局单例」改为「每次发消息时按当前 context 动态构建 per-request 工具集」。本轮一次性打通内核 + ChatKit + 必要 App 层,让 per-request **立即生效**。依据 `docs/agenttool-dynamic-injection-proposal.md`。

## 两个待决策点 — 按最小改动方案执行
1. **`makeAssistantMessage` 如何拿到 `AgentToolProviding`**:方案 (a) — `LumiCore.init` 把 provider 注册进服务表,`buildToolSet` 从服务表取。(`LumiCore.init` 已接收 provider 参数 `LumiCore.swift:40`,只是没存;它是 `AnyObject` 可注册。)
2. **子 Agent 的工具执行权**:方案 (a) — `SubAgentDelegateTool` 同时持有「用于过滤的快照 `availableTools`」和「用于执行的 `executionToolService`」。过滤改成读快照,执行仍走主 turn 的 per-request toolService。

---

## 执行步骤(9 步,逐步独立编译)

### 步骤 1:`ToolService` 支持 per-request 构造
`Packages/LumiCoreKit/Sources/AgentTool/ToolService.swift`
- 新增 `init(tools:environment:)`:直接接收初始工具集。
- 抽出私有 `reindex()`:统一重建 `toolsByName` + 排序 `tools`。
- **保留** `init()` / `registerTools` / `appendTools` / `registerBuiltInTools` 不动(测试 + 兜底路径仍用)。

### 步骤 2:内核新增 per-request 构建入口 `buildToolSet`
`Packages/LumiCoreKit/Sources/AgentTool/AgentToolComponent.swift`
新增方法:合并 [插件工具 + builtInTools + subAgent 工具],**软去重**(同名后到者跳过 + 记入 `toolContributionFailures`,不抛错)。provider 从服务表取(`resolveService((any AgentToolProviding).self)`)。返回 `ToolService(tools:environment:)`。
**保留** `bootstrapToolContributions` 和 `validateToolNameUniqueness`(启动期路径,步骤 6 决定去留)。

### 步骤 3:`LumiCoreAccessing` 暴露 `agentToolComponent`
`Packages/LumiCoreKit/Sources/LumiCoreAccessing.swift`
协议加只读 `var agentToolComponent: AgentToolComponent { get }`(`LumiCore.swift:15` 已有字段,纯加法)。

### 步骤 4:`LumiPluginContext` 加便捷项目访问
`Packages/LumiCoreKit/Sources/Plugin/LumiPluginContext.swift`
加 `@MainActor var currentProject: ProjectEntry? { lumiCore?.projectComponent.currentProject }`。

### 步骤 5:`SubAgentDelegateTool` 改持有工具集快照
`Packages/LumiCoreKit/Sources/SubAgent/SubAgentDelegateTool.swift`
- 加 `availableTools: [any LumiAgentTool]` 字段(用于过滤)。
- 保留 `executionToolService`(用于 `SubAgentLoopRunner.run` 的 `.execute`,见 `:292`)。
- `resolveTools()`(`:109`)读 `availableTools` 而非 `toolService.tools`。
- 同步更新 `SubAgentDelegateToolTests.swift`(mock 改为传 tools 数组)。
- `AgentToolComponent.buildToolSet`(步骤 2)和 `bootstrapToolContributions`(`:107`)两处构造点同步改。

### 步骤 6:启动期路径瘦身 + provider 注册
`Packages/LumiCoreKit/Sources/LumiCore.swift`
- `init` 里把 provider 注册进服务表:`registerService((any AgentToolProviding).self, provider)`。
- `bootstrapToolService` 保留(造空壳 ToolService + 注入 environment + 注册服务表,给 per-request 复用 environment)。
- 启动期 `validateToolNameUniqueness` **保留**(早期反馈,与构建时软去重并存:一硬一软)。
- `bootstrapToolContributions` 标记 deprecated(暂不删,避免破 App 编译;步骤 8 同步删 App 调用后再在后续清理)。

### 步骤 7:ChatKit 切换到 per-request
`Packages/LumiChatKit/Sources/Managers/SendPipeline.swift` + `ChatService.swift`
- **(a)** `processPendingSend`(:185 附近)在发消息前构建 per-request:`service.lumiCore?.agentToolComponent.buildToolSet(...)`,得到 `perRequestToolService`。
- **(b)** `makeAssistantMessage`(:251)的 `tools` 从 `service.agentTools` 改为 `perRequestToolService.tools`;签名加 `toolService` 参数透传(或通过外层已构建的实例)。
- **(c)** `runAgentTurn`(:850)加 `toolService: any LumiToolServicing` 参数;turn loop 三处(`:945/956/967/1018`)从 `self.toolService` 改为传入参数。
- **(d)** 两个调用点(`SendPipeline.swift:203/354`)传入 `perRequestToolService`。
- 同步更新 4 个 ChatKit 测试文件(`ToolApprovalCancellationTests` / `EmptyResponseRetryTests` / `ToolExecutionStatusTests` / `InlineToolCallRetryTests`):`runAgentTurn` 调用点补参数;旧 `registerToolService` 测试桩改为构造 per-request 或保留兼容。

### 步骤 8:App 层移除启动期注入
`Packages/LumiAppKit/Sources/LumiAppKit/Bootstrap/RootContainer.swift`
- `bootstrapAfterPluginLifecycle`(:185)移除 `bootstrapToolContributions()` 调用。
- `onLumiEnabledPluginsDidChange` 订阅(:138-145)移除(下次发消息自然反映插件开关)。
- `bootstrapToolContributions` 私有方法(:204)删除。
- `OpenProjectHandler.requestOpen`(App 层)打开项目时调 `ProjectLanguageDetector` 填充语言字段(配合步骤 9)。

### 步骤 9:ProjectEntry 加语言字段 + 检测
- `Packages/LumiCoreKit/Sources/Project/ProjectEntry.swift`:加 `Language` 枚举(swift/go/rust/javascript/typescript/python/unknown)+ `language` 字段;init 加参数(默认 `.unknown` 向后兼容);Codable 用 `decodeIfPresent` fallback `.unknown`。
- 新建 `Packages/LumiCoreKit/Sources/Project/ProjectLanguageDetector.swift`:扫 marker 文件(`Package.swift`→.swift,`go.mod`→.go,`Cargo.toml`→.rust,`package.json`→按 dependencies 判 ts/js,`pyproject.toml`/`.py`→.python)。
- `ProjectState.setCurrentProjectPath`(`:50`)创建 entry 时调检测填充。
- grep 全仓库 `ProjectEntry(name:path:)` 调用点补参数(多数用默认值)。
- 新增 `ProjectLanguageDetectorTests`。

---

## 风险与缓解
| 风险 | 缓解 |
|---|---|
| ChatKit 测试依赖旧 `registerToolService` + weak 持有 | 测试改为构造 per-request ToolService 传入 `runAgentTurn`;保留旧 API 不删以免破坏 |
| `ProjectEntry` Codable 旧数据无 language 字段 | `decodeIfPresent` fallback `.unknown` |
| `bootstrapToolContributions` deprecated 但暂留 | App 调用点(步骤 8)删除后,后续单独清理内核残留 |
| 并发:多会话 per-request 隔离 | per-request 实例天然隔离,不共享可变状态;`environment` 是只读共享 |
| 子 Agent 工具执行 | 方案 (a):`executionToolService` 复用主 turn per-request 实例 |

## 执行顺序
1→2→3→4→5(内核+测试) → 编译内核 → 6 → 7(ChatKit+测试) → 编译 ChatKit → 8→9(App+ProjectEntry) → 全量编译 + 测试。

每步独立可编译。先完成内核层(步骤 1-6)让你审核,再继续 ChatKit/App。

## 编译/测试命令
- 内核:`cd Packages/LumiCoreKit && swift build`
- ChatKit:`cd Packages/LumiChatKit && swift build`
- 全量:`xcodebuild -scheme Lumi -configuration Debug -destination 'platform=macOS' build`
- 测试:`swift test`(各包内)

## 产出
- 9 处代码改动(内核 6 + ChatKit 1 + App 2,含新建 2 个文件)
- 更新 6 个测试文件 + 新增 2 个测试文件
- 改造完成后 `docs/agenttool-dynamic-injection-proposal.md` 状态从"提案"更新为"已实施"