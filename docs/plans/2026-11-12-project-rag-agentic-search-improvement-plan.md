# Project RAG 改进方案：Agentic Search 为主路径，向量索引降级为语义兜底

日期：2026-11-12
基线：dev @ `eea0bde5d`（核对当日；实施前必须重读目标文件，见 §2）
状态：已实施（2026-11-12，dev 分支逐 Task 独立提交）。决策按推荐默认执行：D1 保留门控自动注入 + 用户开关；D2 探测确认内置 SQLite 无 FTS5，走 2.1b' Swift BM25；D3 工具名 `grep`；D4 语义注入阈值 0.50。TestPlan 218 条场景全绿；§9.3 手工 App 路径中依赖整 App 运行的项未验证（环境限制），其余以真实流/真实库测试覆盖。

**Goal:** 把 Lumi 的代码检索从「每轮自动推送向量检索结果」改造为「模型驱动的实时搜索为主路径 + 向量索引作为可选语义兜底」，对齐终端编码 agent 的行业共识，同时保留既有索引投资，修复注入预算、工具契约、索引期空结果、检索融合与新鲜度问题。

**Architecture:** 不重写 Kernel/Provider/Plugin、AgentLoop、ToolJob 体系。改动集中在 `PluginProjectRAG`（含 `ProjectRAGEngine`）与 `ProviderProjectRAG` 契约；新增一个 `grep` 工具补齐实时内容搜索能力；注入钩子从「宽意图 + 无条件插队」改为「严格意图 + 置信度门槛 + token 预算 + 稳定位置」；检索融合从原始分数排序改为 RRF；索引侧补 FTS5（或 Swift BM25 回退）、边界感知分块、FSEvents 新鲜度与 vec0 表持久化。

**Tech Stack:** Swift 6、Swift Testing、SwiftPM、SQLite（自定义 3.51.3 + sqlite-vec）、ripgrep 15.2.0（已内置）、Apple NLEmbedding、FSEvents、KitAgentTool、ProviderLifecycleHooks。

---

## 1. 调研结论（本方案的依据）

2026-11-12 对 7 个编码 agent 做了源码级验证（克隆仓库逐一检查，闭源产品查官方文档）：

### 1.1 不建代码库索引的阵营（6/6 源码证实）

| Agent | 检索方式 | 关键证据（仓库内路径） |
|---|---|---|
| ZCode | rg WASM + glob + 读文件，严格字节预算（grep 20KB / read 256KB） | `apps/zcode-cli/packages/core`（前次调研已核） |
| Codex CLI（OpenAI） | 无专门 grep 工具，模型经 shell 跑 `rg`；rg 随包内置 | `codex-rs/install-context/src/lib.rs:354`、`codex-rs/core/gpt-5.2-codex_prompt.md:5` |
| Gemini CLI（Google） | Grep 工具 = `rg --json`，vendor 内置全平台 rg；降级 git grep → 系统 grep → 纯 JS | `packages/core/src/tools/ripGrep.ts:443`、`tools/grep.ts:572` |
| Claude Code（Anthropic） | Grep/Glob 逐参数映射 rg；ripgrep Rust 代码静态编译进原生二进制 | npm 包 `sdk-tools.d.ts:915` GrepInput；二进制内 `ripgrep::search` 等字符串 |
| Cline | search_files = ripgrep（借 VS Code 内置 rg）；无 rg 时纯 JS 回退；文件列表仅 15s TTL 内存缓存 | `sdk/packages/core/src/extensions/tools/executors/search.ts:183` |
| opencode（SST） | grep/glob 全走 rg 15.1.0（自动下载 + SHA256 校验），无 JS 回退 | `packages/core/src/tool/plugin/ripgrep.ts:223` |

共性：**全部内置 rg**；sqlite 只存会话历史；tree-sitter 只用于 shell 命令安全解析；没有任何一家对用户代码做 embedding 后自动注入。

### 1.2 例外与中间形态

- **Aider**：持久化**结构索引**——tree-sitter 定义/引用标签存 `.aider.tags.cache.v3`（SQLite diskcache，mtime 失效），PageRank 排序生成 repo map 按 token 预算注入（`aider/repomap.py:35,525`）。**无向量检索**（唯一 embedding 用于自家帮助文档）。
- **Continue**：完整向量索引（tree-sitter 分块 → 本地 all-MiniLM-L6-v2 → LanceDB + FTS5，检索权重 ½ 向量 + ¼ FTS + ¼ 最近编辑，`core/indexing/CodebaseIndexer.ts:146`）。**但当前 agent 模式默认工具是 grep/glob/read 实时搜索**；语义 codebase 工具在 `enableExperimentalTools`（默认 false）之后，另有 `codebaseToolCallingOnly` 实验开关用工具调用替代向量检索（`core/tools/index.ts:29`）。
- **Cursor / Copilot**（闭源 IDE 阵营，官方文档确认）：Cursor 用 Merkle 树增量同步 + tree-sitter AST 分块 + embedding 存云端 Turbopuffer；Copilot 服务端语义索引（初始 ≤60s）。这是「@Codebase 问答」场景的路线，不是终端 agent 路线。

### 1.3 对 Lumi 的三条结论

1. **实时 agentic search 是终端 agent 的行业共识**，Lumi 作为桌面 agent 应以此为主路径。rg 内置已于 `56e8a2abf` 落地，主路径的地基已具备。
2. **向量索引不是落后技术，而是特定场景工具**：模糊自然语言问题（"登录功能是怎么设计的"这类没有精确关键词的提问）与超大仓库定位。保留为兜底，但不再无条件自动推送。
3. **连 Continue 都在把 agent 默认路径切回实时搜索**。Lumi 当前「宽意图门槛 + 每轮自动注入 + 索引期全空」的组合与行业方向相反，是本方案要修正的核心。

---

## 2. 源码事实基线（2026-11-12 逐行核对）

> 实施前先读当前文件。若现状与本节不符，先记录差异，再按本计划的状态语义调整最小实现，不得凭记忆改代码。

### 2.1 请求链路（推模式现状）

```
用户消息
  → ProjectRAGLLMContextHook.apply          (willSendToLLM 钩子)
      → RAGIntentAnalyzer.shouldUseRAG      (宽意图门槛)
      → provider.isIndexing? 是 → 直接放弃
      → CodeNavigationCoordinator.search(topK: 8)
          → 语义: RAGService.retrieve (embed → ANN/词法)
          → 实时: RAGLexicalFileSearcher (rg) + RAGFilePathSearcher
          → deduplicateAndSort (按原始 score 排序)
      → RAGContextBuilder.buildPrompt       (9000 字符上限)
      → messages.insert(system, at: 0)      (破坏前缀缓存)
```

关键事实与问题（文件均相对 `Packages/PluginProjectRAG/Sources/`）：

| # | 事实 | 位置 | 问题 |
|---|---|---|---|
| F1 | 注入忽略 `injectedContentTokenBudget` | `PluginProjectRAG/Hooks/ProjectRAGLLMContextHook.swift:23-87`（全文无预算引用） | 违反预算契约（`ProviderLifecycleHooks/.../LifecycleHooksProviding.swift:37-43` 明确要求钩子自律）；历史占满窗口时注入导致超限，紧急重试带着同样超限内容再失败 |
| F2 | system 消息插在 `at: 0` | 同上 `:74-80` | 每轮内容变化都使整个请求前缀缓存失效 |
| F3 | 意图门槛过宽：中文触发词含「项目/功能/怎么/如何/为什么」等 | `ProjectRAGEngine/Core/RAGIntentAnalyzer.swift:20-23` | 几乎任何中文问句都触发检索与注入 |
| F4 | 无置信度门槛：results 非空即注入 | `ProjectRAGLLMContextHook.swift:51` | 低相关片段污染上下文 |
| F5 | 索引期间整条链路返回空 | `PluginProjectRAG/Navigation/CodeNavigationCoordinator.swift:25-27` | rg 实时搜索本不依赖索引，却被一并拦截；首次索引期间模型拿不到任何代码证据 |
| F6 | 三路结果按原始 score 排序 | `CodeNavigationCoordinator.swift:97-100` | 语义分（0.75×余弦）、lexicalBoost、pathBoost 量纲不同，跨路比较无意义 |
| F7 | 词法/路径搜索的 query = 原始用户消息 | `CodeNavigationCoordinator.swift:34-43` | 「登录功能是怎么设计的」整句进 rg 模式，疑问词全部成为搜索词 |
| F8 | 检索无分数阈值 | `ProjectRAGEngine/Services/RAGRetriever.swift:84-97` | 余弦 0.1 的噪声也会返回 |
| F9 | 分块为 80 行滑窗（20 重叠、4000 字符） | `ProjectRAGEngine/Services/RAGChunker.swift:8` | 函数被拦腰切断，语义单元不完整 |
| F10 | 每次 initialize 都 DROP 重建 vec0 表并全量回灌向量 | `ProjectRAGEngine/Services/RAGSQLiteStore.swift:826-829,831-859`（`detectRuntimeInfo` 在 `:714` 调用 rebuild） | 启动成本随 chunk 数线性增长，纯浪费 |
| F11 | 新鲜度靠 300s stale + 20s 节流，无文件监听 | `ProjectRAGEngine/Services/RAGService.swift:16-17` | 用户改完代码最多 5 分钟后索引才更新 |
| F12 | `search_code` 失败分支返回字符串 | `PluginProjectRAG/Tools/RAGCodeSearchTool.swift:65,74,77,86` | 违反 AGENTS.md「工具失败必须抛出」；`isError == false` 误导模型 |
| F13 | `top_k` 用 `as? Int` | `RAGCodeSearchTool.swift:93` | 违反 AGENTS.md 数字参数解析约定 |
| F14 | 无独立 grep 工具 | `PluginToolManager/.../Tools/` 只有 glob/read_file/list_directory/run_command/edit/write | 模型做精确内容搜索只能靠 search_code（被索引状态牵连）或 run_command 裸跑系统 grep（用户机器未必有 rg） |
| F15 | 索引检索的词法打分是朴素 lexicalBoost，无 BM25/FTS | `RAGRetriever.swift:90`、`RAGLexicalFileSearcher.swift:126` | 长文档词频饱和、无 IDF，排序质量差 |

### 2.2 已有能力，不重建

- **rg 内置与定位**：`ProjectRAGEngine/Utils/RAGRipgrepLocator.swift`（签名副本 `Contents/MacOS/rg` 优先 → `Bundle.module` → PATH），release 归档校验已含 rg（`.github/scripts/verify-release-archive.sh`）。新 grep 工具直接复用，不得另造定位逻辑。
- **rg 执行与 JSON 解析**：`RAGLexicalFileSearcher.searchWithRipgrep`（`--json --no-ignore --max-count 3 --context 3`，退出码 1 = 无匹配，管道 fd 显式回收）。`--no-ignore` 是回归 #1113 的修复，任何新 rg 调用必须保留。
- **增量索引**：`RAGIndexer.indexProjectIncrementally`（mtime + contentHash 双校验，`RAGIndexer.swift:133,146-147`），扫描失败不清旧索引。FSEvents 任务只触发它，不重写索引逻辑。
- **注入去重**：`RAGInjectionDeduplication`（turnKey）+ `ProjectRAGSearchMemory`（自动注入与 search_code 工具去重，`RAGCodeSearchTool.swift:88-91`）。保留。
- **token 估算器**：`ProviderLLMContext/Sources/ProviderLLMContext/LLMContextProviding.swift:145-163` `LLMContextTokenEstimator.estimate(text:) = ceil(utf8Bytes/3)`。预算任务复用它，不另写估算。
- **预算契约参考实现**：`PluginAgentRules/.../AgentRuleInjectionHook.swift:32`（`maxTokens: context.injectedContentTokenBudget`）。
- **后台索引治理**：令牌代次门（`RAGService.swift:578-601`，回归 #1117）、pause/resume、idle 调度器。不动。
- **内置工具**：glob / read_file / list_directory / run_command / edit_file / write_file 已在 `PluginToolManager`。本方案只补 grep，不重复造其余工具。
- **tree-sitter 语法**：`KitTreeSitterGrammars` 仅 vendor 了 JS/Python/YAML 的 C 语法（供 KitMarkdown、PluginCodeEditorLanguages 使用），**没有 Swift 语法，也没有面向 RAG 的解析运行时**。分块改进不依赖它（见 Task 2.2 与 §8 条件性后续）。

### 2.3 硬约束（违反即事故）

1. **NLEmbedding 实例非线程安全**：共享实例并发 `vector(for:)` 会堆损坏崩溃（`docs/plans/2026-10-28-project-rag-embedding-performance-analysis.md` 实测）。任何 embedding 改动不得引入「共享实例 + 并发」；每任务独立实例的现有模式保持。
2. **xcodebuild manifest 沙箱**：Package.swift 里不能用 `FileManager.default.fileExists` 条件编译（KitTreeSitterGrammars 注释里的上游事故）。新增 target/resource 走显式声明。
3. **Hardened Runtime**：rg/vec0 必须优先用签名副本（RAGRipgrepLocator 已处理）；不得新增未签名动态库加载路径。
4. **AGENTS.md 三条工具约定**：失败抛 `ToolExecutionError`、数字走 `toolInt`（`KitAgentTool/Sources/ToolArgumentNumber.swift:69`）、await 后写共享状态前比对身份。闸门脚本 `Scripts/check-tool-failure-strings.py`。
5. **多会话并发**：工作区当前有其他会话的改动（Localizable.xcstrings、PluginLLMContext/PluginMessageManager 新测试文件等）。只按明确路径暂存本 Task 文件，禁止 `git add -A` / `commit -a`；提交前 `git diff --cached --name-only` 核对。
6. **TestPlan 登记制**：`Packages/PluginProjectRAG/Tests/TestPlan.md` 当前 135 例；新增公开 API 先登记用例再实现，`Scripts/verify-testplan.py` 校验方法与登记一致。

---

## 3. 目标架构与不变量

### 3.1 目标链路

```
用户消息
  ├─ 推模式（收窄）: ProjectRAGLLMContextHook
  │    严格意图门槛 + 自动注入开关
  │    → 置信度门槛（分数阈值）
  │    → token 预算内构建 prompt
  │    → 插入「最后一条 user 消息之前」（前缀稳定）
  │
  └─ 拉模式（主路径）: 模型自主选择工具
       grep        → 内置 rg 实时内容搜索（不依赖索引，索引期可用）
       search_code → 混合检索：实时词法/路径 永远可用 + 语义兜底（索引就绪时）
       glob / read_file / list_directory / run_command（既有）
```

### 3.2 不变量

1. **实时搜索永不因索引状态返回空**：索引中、索引失败、vec0 加载失败，grep 与 search_code 的实时部分都必须工作。
2. **注入三条件**：严格意图 ∧ 置信度达标 ∧ 预算允许，缺一不注入；注入失败不阻塞对话。
3. **注入位置稳定**：不得插在索引 0；持久历史前缀逐字节稳定。
4. **跨路融合用排名不用原始分**：RRF 融合，原始分仅用于展示与门槛。
5. **工具失败必抛**：`ToolExecutionError` 透传，真正的空结果才返回字符串。
6. **rg 调用统一**：定位走 RAGRipgrepLocator，参数保留 `--no-ignore`，fd 显式回收，退出码 1 视为无匹配。
7. **embedding 并发模型不变**：不共享 NLEmbedding 实例。
8. **索引数据只增不毁**：vec0 表持久化，DROP 仅发生在维度/模型变更或表损坏；扫描失败不清旧数据。

---

## 4. 决策点（实施前需拍板，未拍板按推荐默认执行）

| # | 决策 | 选项 | 推荐默认 |
|---|---|---|---|
| D1 | 自动注入去留 | A. 完全关闭（纯拉模式，ZCode 路线）；B. 保留但严格门槛 + 开关 | **B**。Lumi 是聊天优先的桌面 App，模糊问题自动给证据有价值；但默认门槛收窄到「高置信才注入」，并留用户开关。若后续数据表明注入命中率低，再切 A |
| D2 | 索引词法检索升级 | A. SQLite FTS5 + bm25()；B. Swift 内存 BM25 | **先探测再定**（Task 2.1a）：自定义 SQLite 3.51.3 若含 FTS5 走 A，否则走 B。不引入新依赖 |
| D3 | grep 工具归属 | A. PluginProjectRAG 注册（复用 rg 资产）；B. 下沉 PluginToolManager | **A**。rg 二进制与定位器在 ProjectRAGEngine，下沉需要拆包迁移，收益不抵成本；工具名 `grep` 与行业一致 |
| D4 | 语义注入阈值初值 | 余弦 0.45 / 0.50 / 0.55 | **0.50** 起步，集中常量 + 日志记录命中分布，两周真实数据后校准（Task 0.3 埋点） |

---

## 5. Phase 0（P0）：注入纪律与工具契约 —— 先止血

阶段门：Phase 0 全部验收前，不得开始 Phase 1 的融合改动（避免在错误分数语义上叠加 RRF）。

### Task 0.1 注入遵守 token 预算

**改动文件**
- `ProjectRAGEngine/Services/RAGContextBuilder.swift`
- `PluginProjectRAG/Hooks/ProjectRAGLLMContextHook.swift`
- `PluginProjectRAG/Package.swift`（PluginProjectRAG target 增加 `ProviderLLMContext` 本地依赖；Engine 不加依赖）

**设计**
- `RAGContextBuilder.buildPrompt` 增加参数 `maxTokens: Int?` 与 `tokenEstimator: ((String) -> Int)?`（默认 nil = 旧行为，Engine 不依赖 ProviderLLMContext）。
- 构建后若 `estimator(prompt) > maxTokens`：从尾部逐个移除片段重建，直到达标或只剩 disclaimer；仍超则返回 nil 语义（调用方跳过注入）。用「移除片段」而非「截断字符」，保证片段完整。
- Hook 传入 `context.injectedContentTokenBudget` 与 `LLMContextTokenEstimator.estimate(text:)`。预算为 nil 时保留 9000 字符旧行为。
- 预算 ≤ 0 直接跳过注入（历史已占满窗口）。

**TDD**
1. 失败测试 `ProjectRAGEngineTests/RAGContextBuilderBudgetTests.swift`：
   - `promptFitsTokenBudget`：10 个片段 + maxTokens 600 + 估算器 `utf8/3`，断言估算 ≤ 600 且保留片段完整（无半截片段）。
   - `nilBudgetKeepsLegacyCharLimit`：nil 预算仍按 9000 字符。
   - `tinyBudgetDropsAllSnippets`：预算 10 → 返回不含任何片段。
2. 失败测试 `PluginProjectRAGTests/ProjectRAGLLMContextHookBudgetTests.swift`：
   - `hookSkipsInjectionWhenBudgetZero`：budget 0 → messages 不变。
   - `hookHonorsInjectedContentBudget`：budget 600 → 注入消息估算 ≤ 600。
3. 最小实现 → 通过 → TestPlan 登记（新增 5 例）。

**验收**：上述测试绿；`swift test --package-path Packages/PluginProjectRAG --skip-update` 全绿。
**提交**：`fix(PluginProjectRAG): honor injected content token budget in RAG context hook`

### Task 0.2 注入位置改为最后一条 user 消息之前

**改动文件**：`PluginProjectRAG/Hooks/ProjectRAGLLMContextHook.swift:73-80`

**设计**：找到 `messages` 中最后一条 `.user` 的下标 `i`，`insert(at: i)`。历史前缀 `[0..<i]` 逐字节不变，供应商前缀缓存命中到注入点之前。不得插 0，不得 append 到 user 消息之后（会改变「最后一条 user」语义，影响后续 turnKey 与意图判断）。

**TDD**
1. 失败测试 `injectionPreservesHistoryPrefix`：`[system, user1, assistant1, user2]` → 注入后 `messages[0..<3]` 与原数组逐元素相等，新 system 位于下标 3。
2. 失败测试 `injectionBeforeLatestUserWhenTrailingSystemExists`：末尾有 system 消息时仍以最后一条 user 为锚。
3. 实现 → 通过 → TestPlan 登记（2 例）。

**验收**：测试绿；手工验证（§9 路径 M1）观察连续两轮请求的公共前缀长度增加。
**提交**：`fix(PluginProjectRAG): inject RAG context before latest user message to preserve prefix cache`

### Task 0.3 严格意图门槛 + 置信度门槛 + 自动注入开关

**改动文件**
- `ProjectRAGEngine/Core/RAGIntentAnalyzer.swift`（新增 `shouldAutoInject`，不动 `shouldUseRAG`——后者仍服务工具侧判断）
- 新文件 `ProjectRAGEngine/Core/RAGInjectionPolicy.swift`（阈值常量集中地）
- `PluginProjectRAG/Hooks/ProjectRAGLLMContextHook.swift`

**设计**
- `shouldAutoInject(for:)` 严格条件（满足其一）：
  a. 含文件/路径引用（复用 `hasFileOrPathReference`）；
  b. 含代码意图标记（复用 `codeIntentMarkers`）；
  c. 问句 ∧ 含具体代码名词（「登录/注册/支付/缓存/路由」类领域词不算通用触发词；实现为：问句 ∧ 含标识符样词 `[A-Za-z_][A-Za-z0-9_]{2,}` 或「实现/设计/架构/调用/依赖」之一）。
  - 「今天天气怎么样」「帮我写周报」类不再触发。现有 `shouldUseRAG` 的宽触发词表保留给工具侧。
- `RAGInjectionPolicy`：`semanticScoreThreshold: Float = 0.50`（D4）、`minLexicalHits = 2`。注入条件：存在 `.semantic` 结果 score ≥ 阈值，或 ≥ 2 条 `.filesystemLexical`/`.indexedLexical` 结果。阈值判断在 Hook 内对 coordinator 返回结果做（matchKind 已有）。
- 开关：`UserDefaults` key `projectRAG.autoInjectEnabled`（默认 true），Hook 读取；设置 UI 属 Phase 4，先留 key。
- 埋点：每次注入决策经 `SuperLog` 记录 `{gate, intentPassed, topScore, matchKind, budget, injected}`（verbose 级），供 D4 校准。不得记录用户消息全文，只记长度与意图判定结果。

**TDD**
1. `RAGIntentAnalyzerAutoInjectTests`：
   - `casualQuestionDoesNotAutoInject`：「今天天气怎么样」→ false；
   - `designQuestionAutoInjects`：「登录功能是怎么设计的」→ true（含「设计」）；
   - `identifierQuestionAutoInjects`：「LoginViewController 在哪初始化」→ true；
   - `broadTriggerStillAllowsToolUse`：「这个项目怎么样」→ shouldUseRAG true 但 shouldAutoInject false。
2. `RAGInjectionPolicyTests`：语义 0.49 单条 → 不注入；0.50 → 注入；两条词法命中 → 注入；单条词法 → 不注入。
3. Hook 测试：开关关闭 → messages 不变。
4. 实现 → 通过 → TestPlan 登记（约 9 例）。

**验收**：测试绿；手工路径 M2 确认闲聊不再触发检索日志。
**提交**：`feat(PluginProjectRAG): gate automatic RAG injection by strict intent and confidence`

### Task 0.4 search_code 工具契约修复

**改动文件**：`PluginProjectRAG/Tools/RAGCodeSearchTool.swift`

**设计**
- `:65`（缺 query）、`:74`（无项目）、`:77`（路径不存在）、`:86`（provider 不可用）改为 `throw ToolExecutionError.executionFailed(toolName: name, reason: ...)`。
- `:100` 的「No indexed code matched ...」是**真空结果**，按 AGENTS.md 例外保留字符串，但文案改为不误导：`No code matched the query. If the project was just opened, indexing may still be in progress; try grep for exact text.`
- `:93` `top_k` 改 `arguments.toolInt("top_k")`，入口 `assert((1...20).contains(...))` + Release 钳制（schema 已声明 min/max，保持一致）。
- searchMemory 去重分支（`:88-91`）保留字符串（它是成功的信息性结果，不是失败）。
- 外层如加 catch：先 `catch let error as ToolExecutionError { throw error }`。

**TDD**
1. `RAGCodeSearchToolContractTests`：
   - `missingQueryThrows`、`missingProjectThrows`、`nonexistentPathThrows`、`unavailableProviderThrows`（断言 `ToolExecutionError`）；
   - `topKClampedToSchemaRange`：top_k = -5 / 999 / "abc" → 不崩、落在 1...20；
   - `emptyResultReturnsInformationalString`：无匹配 → 字符串且不含 "Error"。
2. 实现 → 通过 → `python3 Scripts/check-tool-failure-strings.py` 必须 0 退出 → TestPlan 登记（6 例）。

**验收**：测试绿 + 闸门脚本绿。
**提交**：`fix(PluginProjectRAG): throw tool errors and parse top_k via toolInt in search_code`

---

## 6. Phase 1（P1）：实时搜索成为主路径

阶段门：Task 1.2 验收前不得改 search_code 描述词（避免模型行为在能力就绪前变化）。

### Task 1.1 新增 grep 工具（实时内容搜索，不依赖索引）

**新文件**
- `ProjectRAGEngine/Services/RAGGrepSearcher.swift`
- `PluginProjectRAG/Tools/RAGGrepTool.swift`
**改动文件**：`PluginProjectRAG/ProjectRAGPlugin.swift`（onBoot 注册，onShutdown 移除）

**设计**
- `RAGGrepSearcher`：原始正则 → rg。与 `RAGLexicalFileSearcher` 分离（后者是「查询词提取 + 打分」，grep 工具要忠实执行用户正则）。复用 `RAGRipgrepLocator.executable()`；参数基线：`--json --no-heading --no-ignore --color never --max-filesize 1500K` + `RAGFileScanner.grepExcludeDirPatterns` 排除 + 可选 `--glob` + `-i`；**不加 `--max-count`**（grep 语义要全部命中，用 head_limit 截断输出）；退出码 1 = 无匹配，>1 = 执行错误（抛错）。fd 显式回收照抄现有实现。
- 输出预算：总字节 ≤ 20_000（ZCode 同款量级），超限截断并附 `[truncated: N more matches; narrow the pattern or use glob]`。每行格式 `path:line:content`（相对项目路径）。
- `RAGGrepTool`（工具名 `grep`）schema：
  - `pattern`（string，必填，ripgrep 正则）
  - `path`（string，可选；解析顺序与 search_code 一致：显式 > 会话项目 > UI 当前项目）
  - `glob`（string，可选，映射 `--glob`）
  - `case_insensitive`（boolean，默认 false）
  - `max_results`（integer 1...500，默认 100，`toolInt` 解析）
  - `context_lines`（integer 0...10，默认 0，映射 `-C`）
- `permissionRiskLevel` = .low（只读）。失败（rg 缺失、正则非法、路径不存在）一律抛 `ToolExecutionError`。无匹配返回字符串 `No matches for pattern ...`（真空结果）。
- rg 缺失时**不做静默 JS 回退**：内置 rg 由 release 闸门保证存在，缺失属于安装损坏，应显式报错（与 opencode 一致）。
- 描述词（中英）：明确「精确文本/正则搜索，不需要索引，优先用于符号、错误串、字面量；语义模糊问题用 search_code」。

**TDD**
1. `RAGGrepSearcherTests`（临时目录 fixture）：
   - `findsLiteralAndRegexMatches`：含大小写、正则元字符；
   - `respectsNoIgnore`：gitignore 目录内文件仍命中（回归 #1113 同构）；
   - `globFilterWorks`；`caseInsensitiveFlagWorks`；
   - `invalidRegexThrows`；`missingRipgrepThrows`（注入不存在的 locator 路径）；
   - `outputBudgetTruncatesWithMarker`：构造 >20KB 命中，断言字节上限与标记。
2. `RAGGrepToolTests`：参数解析（max_results 越界钳制）、路径三级回退、无匹配字符串、失败抛错。
3. 实现 → 通过 → TestPlan 登记（约 12 例）。

**验收**：测试绿；手工路径 M3：真实项目里让模型用 grep 找 `RAGRipgrepLocator`，索引关闭/进行中都能命中。
**提交**：`feat(PluginProjectRAG): add grep tool backed by bundled ripgrep`

### Task 1.2 协调器解耦：实时搜索不再被索引状态拦截

**改动文件**：`PluginProjectRAG/Navigation/CodeNavigationCoordinator.swift:16-85`

**设计**
- 删除入口 `guard !isIndexing else return 空`（`:25-27`）。
- 新流程：`async let` 语义检索**仅在** `!isIndexing` 时发起；词法（rg）与路径搜索**无条件**并行执行；合并可用结果。索引中 → 返回纯实时结果（matchKind 为 filesystemLexical/filesystemPath），不再空手。
- `searchProjectRAG` 内部保留「索引就绪才 ensureIndexed + search」的逻辑，但索引中直接返回空语义结果而非抛错。
- 语义检索失败（vec0 未加载等）已有 `try?`/catch 兜底，保持「实时兜底」语义。

**TDD**
1. `CodeNavigationCoordinatorIndexingTests`（mock provider + 临时项目）：
   - `liveSearchWorksWhileIndexing`：isIndexing = true，项目内有匹配文件 → 结果非空且全部为实时 matchKind；
   - `semanticSkippedWhileIndexing`：断言 provider.search 未被调用；
   - `semanticMergedWhenIdle`：索引就绪 → 语义 + 实时都在。
2. 实现 → 通过 → TestPlan 登记（3 例）。

**验收**：测试绿；手工路径 M4：打开全新大项目，索引进行中立即提问，能拿到 grep 证据。
**提交**：`fix(PluginProjectRAG): keep live search available while background indexing runs`

### Task 1.3 查询词提取：自然语言 → 搜索词

**新文件**：`ProjectRAGEngine/Core/RAGQueryAnalyzer.swift`
**改动文件**：`CodeNavigationCoordinator.swift`（词法/路径搜索改用提取后的词；语义 embed 仍用原始 query）

**设计**
- `extractTerms(query:) -> [String]`：
  a. 标识符：`[A-Za-z_][A-Za-z0-9_]{2,}`（保留原大小写，rg 侧已有 `(?i)`）；
  b. 文件名片段：含 `.` 的 token（如 `Package.swift`）；
  c. CJK 内容词：连续汉字段减去停用词表（怎么/为什么/如何/请问/一下/什么/哪些/项目/代码/功能/文件/实现/设计/吗/呢）；「登录功能是怎么设计的」→ 「登录」。
  d. 提取结果为空 → 回退现有 `RAGTextUtils.tokenize`（保持旧行为，不产生空搜索）。
- 词法搜索的 rg 模式用提取词 OR 连接（现有 `ripgrepArguments` 结构不变）；路径搜索同样用提取词。
- 上限 8 个词，超出按「标识符 > 文件名 > CJK」优先级截断（防止 rg 模式爆炸）。

**TDD**
1. `RAGQueryAnalyzerTests`：
   - `chineseDesignQuestionExtractsDomainTerm`：「登录功能是怎么设计的」→ 含「登录」，不含「怎么/功能/设计」；
   - `identifierPreserved`：「Where is LoginViewController defined」→ 含 LoginViewController，不含 where/defined；
   - `fileNamePreserved`；`emptyExtractionFallsBackToTokenize`；`termCapAtEight`。
2. 协调器测试：`lexicalSearchUsesExtractedTerms`（mock 断言传入 searcher 的 query 不含疑问词）。
3. 实现 → 通过 → TestPlan 登记（6 例）。

**验收**：测试绿；手工路径 M2 复测：同一中文问题，rg 日志中的模式不再含「怎么」。
**提交**：`feat(PluginProjectRAG): extract search terms from natural language queries`

### Task 1.4 RRF 融合替代原始分数排序

**改动文件**：`CodeNavigationCoordinator.swift:87-103`（`deduplicateAndSort`）

**设计**
- 三路（语义/词法/路径）各自保持内部排序，作为三个 ranked list 做 Reciprocal Rank Fusion：`rrf(d) = Σ 1/(60 + rank_i(d))`，k=60 标准值。
- 去重键：`source + lineRange`；lineRange 重叠（同文件区间相交）视为同一证据，保留排名最前者。内容完全相同也去重。
- 最终按 rrf 降序取 topK；`ProjectRAGSearchResult.score` 保留该证据的**最佳原始分**（展示用），排序不再依赖它。`ProviderProjectRAG` 契约不加字段（避免破坏面）。
- 文档注释写明：跨路原始分量纲不同，禁止恢复原始分排序。

**TDD**
1. `CodeNavigationFusionTests`：
   - `rrfPrefersCrossSourceConsensus`：一条证据在词法+路径都排第 1，语义第 5；另一条仅语义第 1 → 前者胜出（原始分排序会反过来，构造分数使旧实现失败）；
   - `overlappingLineRangesDeduplicated`；
   - `displayScoreKeepsBestOriginal`。
2. 实现 → 通过 → TestPlan 登记（3 例）。

**验收**：测试绿。
**提交**：`refactor(PluginProjectRAG): fuse search sources with reciprocal rank fusion`

### Task 1.5 search_code 定位更新与输出预算

**改动文件**：`PluginProjectRAG/Tools/RAGCodeSearchTool.swift`（描述词 + 输出构建）

**设计**
- 描述词改为：「混合代码检索：精确文本/符号优先用 grep；本工具用于自然语言语义问题与跨文件定位。索引未就绪时仍返回实时搜索结果。」
- 输出总字节预算 20_000，单片段 ≤ 3000 字符（与 RAGContextBuilder 一致），超限附截断标记与建议（refine query / use grep + read_file）。
- 结果头部加一行证据构成摘要：`semantic: N, live-lexical: M, path: K`（帮助模型判断证据质量）。

**TDD**：`searchCodeOutputBudgetTruncates`、`searchCodeHeaderShowsEvidenceMix`（2 例）。
**验收**：测试绿 + `check-tool-failure-strings.py` 绿。
**提交**：`feat(PluginProjectRAG): position search_code as semantic fallback with output budget`

---

## 7. Phase 2（P1）：语义兜底质量 + Phase 3（P2）：新鲜度与启动成本

### Task 2.1a FTS5 可用性探测（决策 D2 的前置）

**动作**：在 `ProjectRAGEngineTests` 写一个探测测试，用当前 CSQLite 链接的 SQLite 执行 `CREATE VIRTUAL TABLE t USING fts5(x)` 并查询 `PRAGMA compile_options`，记录结果。
- 含 FTS5 → Task 2.1b 走 FTS5；
- 不含 → 走 Task 2.1b' Swift BM25（对 `loadCandidateChunks` 候选在内存算 BM25，k1=1.2 b=0.75，候选上限已有 1000/2500 约束）。
**提交**：`test(PluginProjectRAG): probe FTS5 availability in bundled SQLite`（探测结果写入 TestPlan 备注）

### Task 2.1b 索引词法检索升级（FTS5 路线）

**改动文件**：`RAGSQL.swift`、`RAGSQLiteStore.swift`（migrate + replaceFileChunks/deleteChunks 同步）、`RAGRetriever.swift`

**设计**
- 新表 `rag_chunks_fts`（FTS5，content + filePath，external content 表指向 chunks）；migrate 时一次性回填存量。
- `replaceFileChunks`/`deleteChunks` 事务内同步 FTS 行（与 chunks 同事务，禁止跨事务漂移）。
- 检索：提取词 → FTS MATCH（OR 语义）→ `bm25()` 排序取候选 → 与 ANN 候选做 RRF（复用 Task 1.4 的融合函数，抽到 `ProjectRAGEngine/Utils/RAGRankFusion.swift` 供两处使用）。
- 分词：FTS5 默认 unicode61 对 CJK 不友好 → 建表用 `tokenize='unicode61'` 并在写入侧对 CJK 追加 bigram 影子列（或检索侧 CJK 走 LIKE 候选 + Swift BM25 兜底；实施时二选一，先写失败测试定行为）。
- 旧 `lexicalBoost` 保留为最终打分的展示项，不再决定排序。

**TDD**：`ftsBackfillOnMigrate`、`ftsSyncedOnReplaceAndDelete`（同事务断言：chunks 与 fts 行数一致）、`bm25RanksRareTermHigher`、`cjkQueryReturnsResults`、`rrfFusesAnnAndFts`（5 例）。
**验收**：测试绿；手工路径 M5：同一组查询对比升级前后 top5 命中文件（记录在 TestPlan 备注）。
**提交**：`feat(PluginProjectRAG): add FTS5 BM25 retrieval fused with vector search`

### Task 2.1b' Swift BM25 回退路线（仅当探测无 FTS5）

对 `loadCandidateChunks` 返回候选计算 BM25（df 在候选集内统计），替代 lexicalBoost 排序；其余融合逻辑与 2.1b 相同。测试同构（4 例）。
**提交**：`feat(PluginProjectRAG): rank indexed lexical candidates with BM25`

### Task 2.2 边界感知分块

**改动文件**：`ProjectRAGEngine/Services/RAGChunker.swift`

**设计**
- 保持 80 行/4000 字符上限与 20 行重叠；在窗口内选择切点时优先：空行 > 顶层声明起始行（正则启发式：Swift `func/class/struct/enum/protocol/extension/import`，JS/TS `function/class/export/const ... =`，Python `def/class`，行首无缩进）。
- 单个声明 ≤ maxChars 时尽量整块保留；超长声明退回现有字符窗口切分。
- 行号语义不变（CRLF 单字符处理，回归 #1114 的既有测试必须继续通过）。
- **不引入 tree-sitter 依赖**（KitTreeSitterGrammars 无 Swift 语法；见 §8）。

**TDD**：`chunkBoundaryPrefersBlankLine`、`smallFunctionKeptWhole`、`declarationStartPreferredOverMidBody`、`oversizedDeclarationFallsBackToCharWindow`、既有 CRLF/行号测试全绿（新增 4 例）。
**验收**：测试绿；对 Lumi 自身仓库重建索引，抽样 10 个 Swift 文件确认函数不再被拦腰切断（人工记录）。
**提交**：`feat(PluginProjectRAG): prefer declaration boundaries when chunking code`

### Task 2.3 语义结果阈值

**改动文件**：`RAGRetriever.swift:84-97`、`RAGInjectionPolicy.swift`（阈值集中）

**设计**：语义候选最终分低于 `semanticResultThreshold`（初值 0.30，低于注入门槛 0.50——工具侧宽松、注入侧严格）直接丢弃；全部被丢弃时走现有词法兜底。日志记录丢弃数。
**TDD**：`lowScoreSemanticCandidatesDropped`、`allDroppedFallsBackToLexical`（2 例）。
**提交**：`feat(PluginProjectRAG): drop below-threshold semantic results`

### Task 3.1 vec0 表持久化（启动成本）

**改动文件**：`RAGSQLiteStore.swift:826-859`、`RAGSQL.swift`

**设计**
- `ensureVectorTable`：先查 sqlite_master 是否已有 `rag_vec_chunks`；存在则读取维度元数据（新增 `rag_meta` 表存 dimension/model）——维度一致 → **不 DROP、不回灌**；不一致或表缺失 → DROP + 重建 + 回灌。
- 完整性哨兵：vec 行数与 chunks 行数不一致时触发回灌（覆盖上次崩溃在半途的场景）。
- `detectRuntimeInfo` 的加载扩展流程不变，仅 rebuild 调用改为条件触发。

**TDD**：`secondInitializeKeepsVectorRows`（两次 configure，断言 vec rowid 稳定/未重建）、`dimensionChangeForcesRebuild`、`rowCountMismatchTriggersRebuild`（3 例）。
**验收**：测试绿；手工：对已索引项目重启 App，日志不再出现全量回灌，initialize 耗时下降（记录前后数值）。
**提交**：`perf(PluginProjectRAG): persist vec0 table across launches`

### Task 3.2 FSEvents 新鲜度

**新文件**：`ProjectRAGEngine/Services/RAGProjectWatcher.swift`
**改动文件**：`ProjectRAGPlugin.swift`（装配）、`ProjectRAGProvider.swift`（项目切换联动）

**设计**
- FSEventStream 监听**当前项目**目录（`kFSEventStreamCreateFlagFileEvents`），debounce 2s 合并事件，回调只投递路径集合。
- 触发 `service.ensureIndexedBackground`（增量索引已有 mtime/contentHash 校验，天然只处理变更文件）。
- 身份校验（AGENTS.md）：回调携带发起时的 projectPath，写回/触发前比对当前项目，不一致直接丢弃；项目切换时停旧流起新流。
- `indexingPaused` 时不触发；onShutdown 必须 invalidate stream（不得泄漏）。
- 300s stale 兜底保留（监听失败时仍有退路）。

**TDD**：`debounceCoalescesEvents`（注入时钟）、`staleProjectEventDropped`（旧项目事件晚到）、`pausedWatcherDoesNotTrigger`（3 例；FSEvents 真实流用临时目录集成测试，标注运行环境要求）。
**验收**：测试绿；手工路径 M6：改一个 Swift 文件保存，5s 内 search_code 能命中新内容（日志可见增量索引只处理该文件）。
**提交**：`feat(PluginProjectRAG): watch project files for near-real-time index freshness`

---

## 8. Phase 4：产品面与收尾

### Task 4.1 自动注入设置开关 UI
在既有插件设置面暴露 `projectRAG.autoInjectEnabled`（Task 0.3 已留 key）与索引暂停开关（已有 `setIndexingPaused`）。文案说明「关闭后仍可用 grep/search_code 工具」。
**验收**：手工切换开关，行为与 Task 0.3 测试一致。

### Task 4.2 文档与 TestPlan 收尾
- TestPlan 全量同步（预计新增 ~55 例，135 → ~190），`Scripts/verify-testplan.py` 绿。
- 更新 `docs/plans/2026-08-30-project-rag-code-navigation-gap-analysis.md` 顶部加一行指向本方案（旧文档的「RAG 未接入生产链路」结论已过时）。

### 条件性后续（不在本方案实施，触发才立项）

| 项 | 触发条件 | 参考 |
|---|---|---|
| tree-sitter 语义分块（JS/Py/YAML 先行，Swift 需 vendor 新语法） | 边界启发式分块被证明检索质量不足（有查询集数据） | Continue `core/indexing/chunk/code.ts`；Aider tags 查询 |
| Aider 式 repo map（结构概览注入） | 模型在陌生项目反复 ls/glob 打转的日志证据 | `aider/repomap.py` PageRank + token 预算 |
| 轻量 rerank | 阈值 + RRF 后 top5 命中率仍不达标 | Continue RerankerRetrievalPipeline |
| 完全关闭自动注入（D1 切 A） | 埋点显示注入命中率低 / 用户关闭率高 | ZCode、Codex 纯拉模式 |
| embedding 输入摘要化（路径+签名代替全文） | 索引耗时或语义质量数据支持；须 A/B 验证 | 2026-10-28 性能分析（长文本逐词推理瓶颈） |

---

## 9. 验证矩阵

### 9.1 每个 Task 必跑

```bash
cd /Volumes/Data/Code/Coffic/Lumi
swift test --package-path Packages/PluginProjectRAG --skip-update
python3 Scripts/verify-testplan.py
python3 Scripts/check-tool-failure-strings.py
```

> `--skip-update` 原因：LumiProviders 远端克隆偶发 SSL 断流，使用已有 `.build/checkouts`。若 checkouts 缺失先单独 resolve，不得把网络失败当测试通过。

### 9.2 阶段收尾加跑

```bash
swift test --package-path Packages/ProviderProjectRAG --skip-update
swift test --package-path Packages/PluginToolManager --skip-update   # grep 注册不破坏内置工具
swift test --package-path Packages/FactoryLumi --skip-update          # 真实装配
```

### 9.3 手工真实 App 路径（不得以测试全绿替代）

| # | 路径 | 期望 |
|---|---|---|
| M1 | 连续两轮代码提问，抓请求 payload | 第二轮公共前缀 ⊇ 第一轮历史；注入消息位于最后一条 user 之前 |
| M2 | 闲聊「今天天气怎么样」 vs 「登录功能是怎么设计的」 | 前者无检索日志；后者 rg 模式不含疑问词 |
| M3 | 索引暂停时让模型 grep 一个已知符号 | 命中；search_code 也返回实时证据 |
| M4 | 全新打开大项目，索引进行中提问 | 立即拿到实时结果，不空手 |
| M5 | 固定 10 条查询（含中文设计类/符号类/错误串类）对比升级前后 top5 | 记录命中文件，不允许明显回退 |
| M6 | 修改文件保存后 5s 内搜索新内容 | 命中；增量日志只含该文件 |
| M7 | 重启已索引项目 | 无全量向量回灌日志 |

### 9.4 完成证据要求

每个 Task 的汇报包含：实际测试命令与结果、TestPlan 新增行号、手工路径结论、未覆盖限制。禁止「理论上可行」。

---

## 10. 实施纪律

1. 每个 Task 按「失败测试 → 最小实现 → 通过 → TestPlan 登记 → 独立提交」执行；不跨 Task 合并提交。
2. 开工前 `git status --short --branch` + `git diff -- <目标文件>`；发现其他会话改动，保留并在其基础上改，禁止 checkout/restore/reset 覆盖。
3. 只按明确路径暂存；提交前 `git diff --cached --name-only` 核对；禁止 `git add -A` / `commit -a`。
4. 提交信息用英文 Conventional Commit（各 Task 已给出）；**不自动 push**，提交与推送分别听用户当次指令。
5. 不提交 `.build`、DerivedData、临时数据库、真实密钥；测试 fixture 用临时目录 + 明显虚构值。
6. 阶段门：Phase 0 未验收不进 Phase 1 融合改动；Task 2.1a 探测未出结果不写 2.1b/b'。
7. 环境无法运行的测试明确标「未验证」，不得以编译通过替代。

## 11. 非目标

- 不删除向量索引与 sqlite-vec（语义兜底保留，D1 只讨论注入去留）。
- 不引入远程 embedding / 新模型依赖（隐私与离线能力不变）。
- 不重写 AgentLoop、ToolJob、压缩体系、idle 调度器。
- 不改变 NLEmbedding 并发模型（每任务独立实例）。
- 不在本方案 vendor Swift tree-sitter 语法或建 repo map（见 §8 触发条件）。
- 不把 ZCode/Continue 的 TypeScript 实现翻译成 Swift 平行运行时；借鉴的是不变量与边界。