# Agent Test and Progressive Architecture Governance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 Agent 可靠性从“各包各自有测试”提升为可持续执行的故障注入、真实装配、跨包契约与渐进架构门禁。

**Architecture:** 复用现有 package tests 与 `Scripts/run-all-package-tests.sh`，增加一层可重复的合同测试和独立进程崩溃 helper；FactoryLumi 验证真实 Plugin 装配。只对 Agent 核心 managed packages 实施依赖规则，CI 新增独立 workflow，不改变现有 release archive/签名流程。

**Tech Stack:** Swift 6、Swift Testing、Swift Package Manager、Python 3 标准库、GitHub Actions、FactoryLumi。

---

## 1. 当前事实

- `Scripts/run-all-package-tests.sh` 已是全包测试入口，但当前末尾只 `cat` summary：即使 `FAILED.txt` 非空也会退出 0。把它作为门禁前必须先修复并测试退出码，否则会产生假绿。
- `.github/workflows/release-build-validation.yml` 负责锁定依赖、双架构 archive、签名和产物验证，不是常规 `swift test` 门禁。
- `Packages/FactoryLumi/Tests/FactoryLumiTests` 已有首次消息与多种真实装配测试，可扩展而不是新建 Factory。
- AgentTurnFSM、ToolJob、MessageStore 已有各自测试，但跨层 save/notify/dispatch 顺序、进程崩溃和第二实现容易漏测。
- Lumi 包多，不能一次性给全仓写严格架构规则；应学习 ZCode managed modules，从本次 Agent 核心开始。

### 非目标

- 不重写现有测试框架，不引入 XCTest/Swift Testing 混合的新抽象。
- 不追求全仓行覆盖率数字，不用覆盖率替代故障语义断言。
- 不在 CI 调用真实付费 LLM/MCP 服务，不写入真实凭据。
- 不用 wall-clock 性能阈值制造 flaky tests；性能 benchmark 保持独立。
- 不修改 release archive、签名、构建号或双架构流程。
- 不在第一阶段治理所有 Plugin 的依赖，只治理明确登记的 managed packages。

## 2. 测试分层

| 层 | 位置 | 验证内容 |
|---|---|---|
| 纯 reducer/值语义 | ProviderAgentLoop、KitAgentTool、KitLLM | 状态转换、CAS 决策、Trace、错误分类 |
| Store 事务 | PluginMessageManager、ProviderToolManager、PluginNetworkManager | 真 SwiftData 临时库、save failure、轻量迁移、重启读取 |
| Manager 合同 | PluginAgentLoop、PluginToolManager、两个 MessageSender | save → notify → dispatch 顺序、stale event、幂等、取消 |
| 真实装配 | FactoryLumi | 生产 Plugin 被装配，未落回 Default/内存/nil 能力 |
| 进程故障 | 测试专用 crash helper + parent test | save 点退出、重开数据库、无重复/无自动副作用重放 |
| 架构门禁 | Scripts + architecture-policy.json | managed packages 依赖方向、循环、未登记依赖 |
| CI | 新 agent reliability workflow | PR 可重复运行上述核心集合，release workflow 保持独立 |

## 3. Task 1：可复用故障点与 Manager 合同测试

**Files:**

- Create: `Packages/ProviderAgentLoop/Tests/ProviderAgentLoopTests/AgentTurnContractTests.swift`
- Create: `Packages/PluginAgentLoop/Tests/PluginAgentLoopTests/AgentLoopEventOrderingTests.swift`
- Create: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageStoreFaultInjection.swift`
- Create: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/MessageStoreTransactionContractTests.swift`
- Create: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolManagerContractTests.swift`
- Create: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionEventOrderingTests.swift`
- Create: `Packages/FactoryLumi/Tests/FactoryLumiTests/MessageSenderContractTests.swift`

### Step 1：先写会失败的跨层合同

至少覆盖：

1. durable API 只有在 save 成功后返回；`.inserted` 不能冒充持久化确认。
2. input promotion 的 message + ledger 一次 save，通知只在 save 后。
3. stream final commit 之前不发布 llmResponded/tool submit。
4. ToolJob result durable 与 tool message durable 之前不创建下一 LLM attempt。
5. 同一 command/job/attempt 的重复事件共享结果，旧 revision 被丢弃。
6. PluginToolManager 与 DefaultToolManagerProviding 对同一 fake tool 的结果预算、deadline、错误码一致。
7. Plugin MessageSender 与 DefaultMessageSender 对同一 command 的 accept、FIFO、cancel、重复 submit 行为一致。

两个实现共享合同不等于把所有测试移到 Factory；Store 细节留在本包，跨实现等价测试放 Factory，避免 Provider 测试依赖 Plugin 形成循环。

### Step 2：运行并确认 RED

```bash
swift test --package-path Packages/ProviderAgentLoop --filter AgentTurnContractTests
swift test --package-path Packages/PluginAgentLoop --filter AgentLoopEventOrderingTests
swift test --package-path Packages/PluginMessageManager --filter MessageStoreTransactionContractTests
swift test --package-path Packages/ProviderToolManager --filter ToolManagerContractTests
swift test --package-path Packages/PluginToolManager --filter ToolExecutionEventOrderingTests
swift test --package-path Packages/FactoryLumi --filter MessageSenderContractTests
```

如果前置专项尚未实现，预期因接口不存在而 RED；不要为了让测试编译而写空 fake 代替真实功能。

### Step 3：最小实现故障 seam

- MessageStore 增加 internal `save` fault hook 或 context factory，只在测试注入；生产默认 nil。
- 事件顺序用 actor 记录 `saveStarted/saveFinished/inserted/persisted/dispatch/toolSubmit`，不使用任意 sleep 推断顺序。
- fake clock/deadline 由测试显式推进；真实时钟只用于少量集成 smoke。
- fault hook 必须能在“save 前”和“save 后返回前”触发，不能只支持抛错一种。

### Step 4：运行相关包并确认 GREEN

```bash
swift test --package-path Packages/ProviderAgentLoop
swift test --package-path Packages/PluginAgentLoop
swift test --package-path Packages/PluginMessageManager
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/FactoryLumi
```

### Step 5：独立提交

```bash
git add Packages/ProviderAgentLoop Packages/PluginAgentLoop Packages/PluginMessageManager Packages/ProviderMessageSender Packages/PluginMessageSender Packages/ProviderToolManager Packages/PluginToolManager Packages/FactoryLumi
git diff --cached --check
git commit -m "test(agent): add cross-layer reliability contracts"
```

只暂存实际变更；提交中不应出现功能实现大改，若合同测试暴露 bug，按对应专项单独修复并先提交。

## 4. Task 2：独立进程崩溃 Helper

**Files:**

- Modify: `Packages/PluginMessageManager/Package.swift`
- Create: `Packages/PluginMessageManager/Tests/CrashHelper/main.swift`
- Create: `Packages/PluginMessageManager/Tests/CrashHelper/CrashCommand.swift`
- Create: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ProcessCrashHarness.swift`
- Create: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/ConversationInputProcessCrashTests.swift`
- Create: `Packages/PluginMessageManager/Tests/PluginMessageManagerTests/StreamAttemptProcessCrashTests.swift`

### Step 1：写 parent tests 与 helper 协议

helper 是 test-only executable target，不进入 library product/App。参数使用明确枚举：

```text
--database <temp-dir>
--scenario input-after-lease
--scenario input-after-promotion-save
--scenario stream-after-checkpoint-save
--scenario stream-after-final-save
--command-json <base64-fixture>
```

parent test 先 build helper，再用 `Process` 启动，等待非零/约定 crash exit，随后用新 Store 打开同一临时库并断言恢复事实。

### Step 2：确认当前无法通过

```bash
swift test --package-path Packages/PluginMessageManager --filter ConversationInputProcessCrashTests
swift test --package-path Packages/PluginMessageManager --filter StreamAttemptProcessCrashTests
```

预期 helper 不存在或当前内存路径重启后丢 queued/重复消息。

### Step 3：最小实现

- executable target path 为 `Tests/CrashHelper`，普通 test target 明确排除该目录，避免 overlapping sources。
- parent 通过 `swift build --package-path Packages/PluginMessageManager --target AgentMessageCrashHelper` 和 `swift build --show-bin-path` 定位，不写本机绝对路径。
- helper 在 fault hook 中使用 `_exit` 或 `fatalError` 模拟进程消失；不执行正常 defer 清理来伪装崩溃。
- parent 不杀其他进程，只等待自己创建的 Process；设置 10s watchdog，超时先 terminate 自己 helper 再失败。
- fixture 全为虚构内容，临时目录测试后由 parent 删除。

### Step 4：确认通过并重复运行

```bash
swift test --package-path Packages/PluginMessageManager
for i in {1..10}; do
  swift test --package-path Packages/PluginMessageManager --filter ProcessCrash || exit 1
done
```

预期连续 10 次无 timeout、无遗留 helper、无重复 MessageModel。

### Step 5：独立提交

```bash
git add Packages/PluginMessageManager/Package.swift Packages/PluginMessageManager/Tests
git diff --cached --check
git commit -m "test(PluginMessageManager): add process crash recovery coverage"
```

## 5. Task 3：FactoryLumi 真实装配矩阵

**Files:**

- Create: `Packages/FactoryLumi/Tests/FactoryLumiTests/AgentCapabilityAssemblyTests.swift`
- Create: `Packages/FactoryLumi/Tests/FactoryLumiTests/AgentDefaultFallbackDetectionTests.swift`
- Modify: `Packages/FactoryLumi/Tests/FactoryLumiTests/FreshInstallFirstMessageAssemblyTests.swift`
- Modify: `Packages/FactoryLumi/Sources/FactoryLumi` only if a real composition bug is exposed

### Step 1：写失败装配测试

使用临时数据目录和真实 Kernel/Plugin 生命周期，验证：

- MessageManaging、MessageSendingProviding、AgentLoopProviding、ToolManagerProviding、StreamAttemptAnchoring、ConversationInputManaging 是预期生产实现。
- 同一能力没有重复注册或后被 Default fallback 覆盖。
- MessageSender 与 AgentLoop 引用同一个 MessageManager/Store 能力，不各自 new Store。
- ToolManager 两条路径共享 ArtifactStore/audit policy；生产 Context 不回落到 nil execution。
- 禁用/启用相关 Plugin 后能力变化符合现有生命周期，不残留 observer/task。
- 首次安装第一条消息能完整 accept → dispatch → assistant response（LLM 用本地 fake transport，不访问网络）。

### Step 2：确认失败

```bash
swift test --package-path Packages/FactoryLumi --filter AgentCapabilityAssemblyTests
swift test --package-path Packages/FactoryLumi --filter AgentDefaultFallbackDetectionTests
swift test --package-path Packages/FactoryLumi --filter FreshInstallFirstMessageAssemblyTests
```

### Step 3：最小修复装配

只修改现有 composition root。不要用“测试专用直接 new Plugin”绕过真实工厂；测试要走 App 相同装配入口。若能力无法 introspect，增加只读 snapshot/registration description，而不是暴露可变内部状态。

### Step 4：确认通过

```bash
swift test --package-path Packages/FactoryLumi
```

### Step 5：独立提交

```bash
git add Packages/FactoryLumi
git diff --cached --check
git commit -m "test(FactoryLumi): verify production agent capability assembly"
```

## 6. Task 4：Managed Package 架构规则与全包测试退出码

**Files:**

- Create: `architecture-policy.json`
- Create: `Scripts/check-agent-package-boundaries.py`
- Create: `Scripts/tests/test-agent-package-boundaries.py`
- Create: `Scripts/tests/test-run-all-package-tests.py`
- Modify: `Scripts/run-all-package-tests.sh` to propagate failed package status and optionally invoke the fast policy check

### Step 1：先写策略校验器测试

用临时 fake package graph 覆盖：

1. Kit → Plugin 拒绝。
2. Provider → Plugin 拒绝。
3. managed package 新增未登记 local dependency 拒绝。
4. A ↔ B 循环依赖拒绝并打印完整路径。
5. Factory → Plugin/Provider/Kit 允许。
6. 未登记的非 managed package 不被误伤，但一旦列入 policy 就执行规则。
7. `swift package dump-package` 失败时脚本非零退出，不能把解析失败当成功。
8. 输出不含本机绝对路径，CI 日志可读。
9. `test-run-all-package-tests.py` 把全包脚本复制到临时 repo，构造两个含 Tests 的 fake package，并把 PATH 中的 `swift` 替换为可控 stub：全部成功必须退出 0；任一 `swift test` 返回非零时脚本必须退出非零且 `FAILED.txt` 含该包；某个 rc 文件缺失也必须失败。测试不运行真实 Swift 包、不依赖网络。

### Step 2：运行确认失败

```bash
python3 Scripts/tests/test-agent-package-boundaries.py
python3 Scripts/tests/test-run-all-package-tests.py
python3 Scripts/check-agent-package-boundaries.py
```

预期策略脚本/policy 不存在，测试 RED；全包退出码测试在当前脚本上必须因“失败包仍退出 0”而 RED。

### Step 3：最小实现 policy 与脚本

初始 managed packages 只包括：

```text
KitAgentTool, KitLLM, KitMCP,
ProviderDiagnostics, ProviderMessage, ProviderMessageSender,
ProviderAgentLoop, ProviderToolManager,
PluginMessageManager, PluginMessageSender, PluginAgentLoop,
PluginToolManager, PluginNetworkManager, PluginMCP,
PluginConversationResume, FactoryLumi
```

policy 每项包含 layer、path、allowedLocalDependencies。先登记当前合法依赖和专项计划允许新增依赖，再逐步删除不需要项；不要为了首轮绿灯写 `allowAny=true`。本次至少显式登记 `ProviderMessage → KitAgentTool`（MessageToolResult Artifact 引用）与 `FactoryLumi → KitAgentTool`（注册 ToolArtifactStoring）；Provider/Factory 的方向合法，但不因此省略 allowlist 条目。

脚本使用 Python 标准库 `json/subprocess/pathlib`：

- 对每个 managed manifest 运行 `xcrun swift package --package-path <path> dump-package`（无 xcrun 的 CI 可 `swift`，macOS runner 用 xcrun 不是必须）。
- 只分析 local path dependencies 与 target product dependencies，不下载远程包。
- 校验层方向、allowlist、managed graph cycle。
- 发现规则冲突时列出所有错误后退出 1，便于一次修复。

全包脚本保留现有汇总格式，但在 `cat "$OUT/summary.txt"` 后根据失败计数显式退出：

```bash
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
```

缺失 rc 文件已经由现有逻辑计入失败，不得改为忽略。只有所有包成功才允许退出 0；后续专项与 CI 才可以只依赖退出码。

### Step 4：运行确认通过

```bash
python3 Scripts/tests/test-agent-package-boundaries.py
python3 Scripts/tests/test-run-all-package-tests.py
python3 Scripts/check-agent-package-boundaries.py
Scripts/run-all-package-tests.sh
```

如果现有架构确实有计划外依赖，先保留现状为精确 allowlist 并开后续 Task 收敛，不得在脚本中硬编码忽略所有 Plugin 依赖。

### Step 5：独立提交

```bash
git add architecture-policy.json Scripts/check-agent-package-boundaries.py Scripts/tests/test-agent-package-boundaries.py Scripts/tests/test-run-all-package-tests.py Scripts/run-all-package-tests.sh
git diff --cached --check
git commit -m "chore(architecture): enforce agent package boundaries"
```

## 7. Task 5：独立 CI Workflow 与可重复脚本

**Files:**

- Create: `Scripts/run-agent-reliability-tests.sh`
- Create: `.github/workflows/agent-reliability-tests.yml`
- Modify: `README.md` only if the repository documents CI entry points and needs the new command link

### Step 1：本地脚本先于 CI

脚本接受 `contracts | runtime | integration | all`，从仓库根目录运行，`set -euo pipefail`。命令分组：

```text
contracts:
  ProviderDiagnostics, KitAgentTool, KitLLM, ProviderMessage,
  ProviderMessageSender, ProviderAgentLoop, ProviderToolManager

runtime:
  PluginMessageManager, PluginMessageSender, PluginAgentLoop,
  PluginToolManager, PluginConversationResume

integration:
  KitMCP, PluginMCP, PluginNetworkManager, PluginFileLog,
  PluginMessageRenderer, PluginConversationExport, FactoryLumi
```

每组先运行 `python3 Scripts/tests/test-agent-package-boundaries.py` 与边界检查一次，不重复三次。

### Step 2：本地验证脚本

```bash
Scripts/run-agent-reliability-tests.sh contracts
Scripts/run-agent-reliability-tests.sh runtime
Scripts/run-agent-reliability-tests.sh integration
```

预期每组任一测试失败即非零退出，后续命令不掩盖失败；打印当前 package 名称。

### Step 3：新增 workflow

建议触发：

```yaml
on:
  workflow_dispatch:
  pull_request:
    branches: [dev, main]
    paths:
      - "Packages/**"
      - "Scripts/**"
      - "architecture-policy.json"
      - ".github/workflows/agent-reliability-tests.yml"
```

使用现有 `xcode-27` runner、setup-xcode 的固定 SHA、`contents: read`。三个 matrix group 并行，`fail-fast: false`，每组执行对应脚本。不要修改 `release-build-validation.yml` 的触发条件或 archive 步骤。

若 GitHub 项目组运行器不允许 PR 使用自定义 `xcode-27`，记录为环境阻塞并使用仓库批准的等价 Xcode runner；不能未经评审改成缺少 Swift 6/SwiftData 环境的 Linux。

### Step 4：验证 workflow

- 本地用 YAML parser 或仓库现有 action lint（若有）检查语法。
- 在测试分支/PR 实际运行三组，确认所有步骤与路径过滤正确。
- 人为引入一个非破坏性失败测试验证 job 会红，再单独恢复；不得为让 CI 变绿加 `--skip` 或隐藏退出码。
- release validation 仍独立运行双架构构建。

### Step 5：独立提交

```bash
git add Scripts/run-agent-reliability-tests.sh .github/workflows/agent-reliability-tests.yml
git diff --cached --check
git commit -m "ci(agent): run reliability tests for agent changes"
```

## 8. Task 6：总故障矩阵与稳定性验收

**Files:**

- Create: `Packages/FactoryLumi/Tests/FactoryLumiTests/AgentReliabilityFaultMatrixTests.swift`
- Modify: relevant package tests only for uncovered rows

### Step 1：逐项映射测试名称

建立测试内 checklist（不是另写规划文档）：

| 故障 | 测试位置必须覆盖 |
|---|---|
| accept save failure | PluginMessageManager + UI draft test |
| promotion 前后 crash | ProcessCrash + Sender recovery |
| dispatch outcome unknown | Sender recovery，不自动 replay |
| checkpoint/final save failure | PluginMessageManager + AgentLoop |
| stale stream callback | PluginAgentLoop |
| tool result save failure | ToolManager + AgentLoop |
| tool side effect unknown | PluginToolManager + Resume |
| queued cancel vs promotion | MessageStore CAS |
| duplicate command/job/attempt | 对应合同测试 |
| HTTP/tool/log secret | 各 Store + export |
| production default fallback | FactoryLumi |
| illegal package dependency | policy unit tests + script |

### Step 2：重复运行易并发测试

```bash
for i in {1..20}; do
  swift test --package-path Packages/PluginAgentLoop --filter StreamAttempt || exit 1
  swift test --package-path Packages/ProviderMessageSender --filter ConversationInput || exit 1
  swift test --package-path Packages/PluginToolManager --filter ToolExecution || exit 1
done
```

若出现 flaky，修复同步/时钟/事件顺序，不通过增加 sleep 或重试 CI 掩盖。

### Step 3：全量验证

```bash
Scripts/run-agent-reliability-tests.sh all
Scripts/run-all-package-tests.sh
```

运行现有 release build validation 的本地等价构建或触发既有 workflow，确认未改 release 逻辑且构建通过。

### Step 4：真实 App smoke

执行总路线图的 10 条端到端验收，并记录实际未覆盖项。UI 自动化不可用时必须明确说“未做 UI 自动化”，同时完成真实手工路径，不能声称测试套件证明 UI 正确。

### Step 5：独立提交

```bash
git add Packages/FactoryLumi
git diff --cached --check
git commit -m "test(FactoryLumi): complete agent reliability fault matrix"
```

## 9. 完成定义

- 可靠性测试可在本地通过单脚本按组运行，并在 PR CI 实际执行。
- 至少 input promotion 与 stream final 有独立进程 crash 测试，不只是抛 Swift Error。
- FactoryLumi 使用真实装配验证能力，不会因默认实现/nil 注入而假绿。
- managed package policy 能阻止 Kit/Provider → Plugin、未登记依赖和循环，且不是 allow-any。
- 两个 MessageSender/ToolManager 实现有等价合同测试。
- 并发测试重复运行稳定，未用 sleep/retry 掩盖竞态。
- release archive 流程未被改写，完整 package tests 与 macOS 构建均有实际结果。
