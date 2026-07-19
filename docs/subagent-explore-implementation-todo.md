# 子 Agent 机制修复与 Explore 子 Agent 实施 TODO

> 目标读者：执行本任务的 Agent。本文档自包含，按顺序执行即可。
>
> 背景：Lumi 的 token 消耗分析（见对话结论）指出，主 Agent 调研类任务会探索大量内容、但只需要结论。
> 项目内已有完整的子 Agent 机制（`SubAgentDelegateTool`）：子 Agent 独立上下文、只回传结论文本、
> 可绑定廉价模型——正好解决该问题。但 2026-07-18 的包拆分重构把注入链路拆断了，
> 且现有 6 个子 Agent 全是"执行任务型"，缺一个"调研探索型"。
>
> 本文档要做的事：**恢复注入链路 → 新增 explore 子 Agent → 补上安全性与体验缺口**。

---

## 0. 开工前必读：现状事实（已核实，勿再重复调查）

### 机制现状

- 子 Agent 核心实现：`Packages/LumiCoreSubAgent/Sources/SubAgentDelegateTool.swift`（325 行）
  - `SubAgentDelegateTool`（:20-178）：把 `LumiSubAgentDefinition` 包装成 `delegate_<id>` 工具，
    输入只有 `task` 字符串；`execute`（:77-109）用 `providerResolver` 解析 provider、过滤工具、
    创建 `SubAgentLoopRunner` 跑隔离循环。
  - `SubAgentLoopRunner.run`（:237-324）：局部 `messages` 数组，从空开始（system prompt + task），
    不继承主会话、不落库、流式 chunk 丢弃；只回传最后一轮 assistant 文本（`formatResult` :168-177）。
  - 工具过滤 `resolveTools()`（:121-166）：requiredTags(OR) → 排除 excludedTags → 排除
    excludedToolNames → 补回 additionalToolNames。
  - 定义模型：`Packages/LumiCoreSubAgent/Sources/LumiSubAgentDefinition.swift:71-91`，
    `maxTurns` 默认 10（:88,106）。
  - 标签体系：`Packages/LumiCoreMessage/Sources/LumiToolTag.swift:52-108`
    （fileSystem/git/shell/network/codeIntelligence/readOnly/destructive/sideEffect/...）。
- 聚合管道（仍然完好，但没有消费者）：
  `LumiPlugin.subAgents(context:)`（`Packages/LumiCorePlugin/Sources/LumiPlugin.swift:42,228`）
  → `LumiPluginRegistry.subAgents`（`Packages/LumiPluginRegistry/Sources/LumiPluginRegistry+State.swift:212-214`）
  → `PluginService.subAgents`（`Packages/LumiAppKit/Sources/LumiAppKit/Services/PluginService.swift:139-141`）。
- 现有 6 个子 Agent 定义：`Plugins/LLMProviderStepFunPlugin/Sources/StepFunPlugin.swift:43-72`
  （git-commit-writer / code-reviewer / test-writer / doc-writer / bug-fixer / xcode-builder），
  定义文件在同包 `SubAgents/` 目录；统一绑 `providerID: "stepfun"` + `modelID: "step-3.7-flash"`，
  注册前有 provider 可用性 gate（:80-103）。

### 断链现状（本次要修的）

- 当前 `AgentToolComponent.buildToolSet`（`Packages/LumiCoreAgentTool/Sources/AgentToolComponent.swift:19-27`）
  只做 `builtInTools + pluginTools` 合并——**没有收集插件工具、没有包装子 Agent、没有 context 参数**。
- 所有调用点只传 `builtInTools`：
  `Packages/LumiCoreChat/Sources/Managers/SendPipeline.swift:245-247`、
  `Packages/LumiCoreChat/Sources/ChatService.swift:457,733,803,859`、
  `Plugins/ChatPanelPlugin/Sources/Views/ChatStatusBarViews.swift:117`。
- 生产代码中没有任何地方构造 `SubAgentDelegateTool`（只有测试构造）。
- 重构前的旧实现可参考：
  `git show 81fb22485:Packages/LumiCoreKit/Sources/AgentTool/AgentToolComponent.swift`
  （旧 `buildToolSet` 第 4 步：`provider.subAgents(context:)` → 构造 `SubAgentDelegateTool` → `appendTools`）。

### 已知腐化（当前工作树可能编译不过/测试红）

1. `Packages/LumiCoreKit/Tests/LumiCoreKitTests/SubAgentDelegateToolTests.swift:417`
   仍用旧签名 `SubAgentDelegateTool(definition:chatService:...)`，新 init 是 `providerResolver:`。
2. `Plugins/LLMProviderStepFunPlugin/Tests/StepFunSubAgentsGateTests.swift:148`
   期望 5 个子 Agent，但 `160bf8410` 已加第 6 个 `XcodeBuildAgent`。
3. `Packages/LumiAppKit/Sources/LumiAppKit/Views/Settings/PluginSettingsPage.swift:268`
   引用了新 `AgentToolComponent` 上已不存在的 `toolContributionFailures`。

---

## 任务清单（按顺序执行，每步独立可交付）

### 任务 1：恢复 buildToolSet 注入链路（核心）

**目标**：让插件工具 + 子 Agent delegate 工具重新进入 per-request 工具集。

1. 改造 `Packages/LumiCoreAgentTool/Sources/AgentToolComponent.swift` 的 `buildToolSet`：
   - 加 `context:` 参数（`LumiPluginContext`，per-request 动态注入的设计见
     `docs/agenttool-dynamic-injection-proposal.md`）。
   - 收集启用插件的 `agentTools(context:)`（单插件抛错要容错，不影响其他插件）。
   - 收集 `subAgents(context:)`，逐个构造 `SubAgentDelegateTool`（新签名 `providerResolver:`），
     append 进工具集。
   - 工具名冲突做软去重（跳过冲突者，不阻断请求）。
   - 参考旧实现：`git show 81fb22485:Packages/LumiCoreKit/Sources/AgentTool/AgentToolComponent.swift`。
2. 更新调用点（SendPipeline / ChatService 的 5 处 + ChatStatusBarViews）传入 context 与插件工具。
   注意 `SendPipeline.makePerRequestToolService`（`SendPipeline.swift:239-248`）是 per-request
   构建入口，插件 context 应在发送消息时构建（反映当前项目等最新状态）。
3. 修复 §0 的三处腐化（旧签名测试、5→6 测试期望、`PluginSettingsPage` 失效引用）。
4. **防递归硬过滤**：在 `SubAgentDelegateTool.resolveTools()` 里显式排除所有 `delegate_*` 工具
   （现在靠"快照不含 delegate"的约定，重构中已证明约定会丢）。

**验收**：
- `LumiCoreAgentTool`、`LumiCoreSubAgent`、`LumiCoreChat` 相关包编译通过、测试全绿。
- 手测：主 Agent 可见 `delegate_*` 工具，调用后子 Agent 跑完返回结论文本。

### 任务 2：新增 explore 子 Agent（本需求的出发点）

**目标**：主 Agent 可把调研任务委派给只读子 Agent，只拿回结论。

1. 新增 `LumiSubAgentDefinition`，id 为 `explore`（放在哪个插件：优先 StepFun 插件旁新增，
   或新建独立插件，与现有 6 个保持同构）：
   - systemPrompt 要点：只做只读调研；输出**结论**（含关键文件:行号证据），不输出过程流水账；
     找不到就明说找不到。
   - `requiredTags: [.readOnly, .fileSystem]`；`excludedTags: [.destructive, .network, .sideEffect]`。
   - `maxTurns` 建议 15（探索比执行任务需要更多轮）。
2. 注册进 `subAgents(context:)`（走与现有 6 个相同的 provider 可用性 gate）。

**验收**：对主 Agent 下一个调研类任务，它能选择 `delegate_explore`，且主会话上下文中只出现结论文本。

### 任务 3：子 Agent 工具执行接审批 / hook（安全缺口）

**现状**：子 Agent 直接调 `toolService.execute`（`SubAgentDelegateTool.swift:308`），
不经过主循环审批（`ChatService.swift:980-999`）也不经过 `toolExecutionHooks`。
只读 explore 无妨，但 bug-fixer / xcode-builder 这类有写权限的子 Agent 等于绕过用户确认。

**改造**：子 Agent 执行有副作用的工具前，走与主循环一致的审批路径（或至少走
`toolExecutionHooks`）。实现方式自选，但不得破坏 `SubAgentLoopRunner` 的"不依赖 ChatService
会话状态"原则——审批能力应通过注入（如 execution context 或闭包）传入。

**验收**：子 Agent 调用写工具时用户能感知/确认；只读工具不打扰。

### 任务 4：子 Agent UI 进度可见性（体验缺口）

**现状**：子 Agent 过程完全黑盒——不落库、chunk 丢弃，用户只看到主会话里一个跑了很久的
工具调用（通用进度见 `ChatService.swift:1002-1034` 的 `statusState.setToolProgress`）。

**改造**：delegate 工具执行期间，至少向主会话进度通道上报"子 Agent 第几轮 / 正在调哪个工具"。
完成后工具结果即结论文本（现状已满足）。

**验收**：UI 上能区分"普通工具调用"与"子 Agent 执行中"，且能看到子 Agent 的推进状态。

### 任务 5（可选，最后做）：解除 StepFun 硬绑定

**现状**：6 个子 Agent 全绑 `providerID: "stepfun"` + `step-3.7-flash`；主 Agent 用其他
provider 时，子 Agent 仍要求用户配置 StepFun key。

**改造**：子 Agent 默认跟随主会话 provider/model（或提供"自动"选项），插件可显式覆盖。

**验收**：未配置 StepFun 的用户也能使用子 Agent。

---

## 贯穿要求

- 每步独立编译、独立可回滚；不要顺手重构无关代码。
- 遵守 `docs/agenttool-dynamic-injection-proposal.md` 的契约：插件的 `agentTools(context:)` /
  `subAgents(context:)` 必须 O(1)，严禁 I/O。
- 改动协议/签名时同步更新调用方与测试；改完跑 `LumiCoreKit` / `LumiCoreChat` / 涉及插件的测试。
- 注意工作树处于重构中间态（§0 腐化清单），先让基线编译通过再往上叠功能。

## 参考文档

- `docs/agenttool-dynamic-injection-proposal.md` — per-request 工具集动态注入设计（已部分落地）
- `docs/architecture-refactor-proposal.md` — 分层架构诊断（背景）
- 旧实现快照：`git show 81fb22485:Packages/LumiCoreKit/Sources/AgentTool/AgentToolComponent.swift`
