# TestPlan — PluginAgentRules

## 包概述

PluginAgentRules 的实现包，包含 14 个主要类型；当前测试覆盖 34 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 34

核心组件（源码目录）:
- `Hooks/`
- `Models/`
- `Observers/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AgentRulesPlugin`
- `AgentRuleInjectionHook`
- `AgentRule`
- `AgentRulesProjectObserver`
- `AgentRulesToolbarProjectObserver`
- `AgentRulePromptBuilder`
- `AgentRulesPluginLocalStore`
- `AgentRulesRuntime`
- `AgentRulesService`
- `CreateAgentRuleTool`
- `ListAgentRulesTool`
- `AgentRulesToolbarViewModel`
- `AgentRulesViewModel`
- `AgentRuleRowView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AgentRulePromptBuilder**（4 条）：由 `projectRulesTakePrecedence`、`emptyRulesProduceNoPrompt`、`oversizedRulesAreTrimmedToBudget` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentRuleInjectionBudget**（1 条）：由 `hookHonorsInjectedContentBudget` 锁定；规则在上下文预算之后注入，必须按剩余输入预算截断，否则请求会超出模型窗口。
- **AgentRulesPlugin**（17 条）：由 `packageLoads`、`pluginHasRequiredMetadata`、`localStoreQuarantinesInvalidSettingsFileAndRecovers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentRulesRuntimeDirectory**（2 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentRulesConversationScope**（3 条）：由 `listToolUsesConversationProject`、`createToolWritesIntoConversationProject`、`explicitProjectPathBeatsConversationProject` 锁定；工具必须按调用所属会话的项目读写，显式参数优先。
- **AgentRulesViewModel**（2 条）：由 `removingLastProjectClearsLoadedRules`、`removingLastProjectClearsErrorMessage` 锁定；项目列表变化后，若已无选中项目必须立即清空 `rules` 与 `errorMessage`，不能保留已移除项目的状态。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AgentRulePromptBuilder | 项目规则优先于同 ID 的插件规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectRulesTakePrecedence` |
| 2 | AgentRulePromptBuilder | 没有规则时不生成空 system prompt | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyRulesProduceNoPrompt` |
| 3 | AgentRulesPlugin | packageLoads | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `packageLoads` |
| 4 | AgentRulesPlugin | pluginHasRequiredMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginHasRequiredMetadata` |
| 5 | AgentRulesPlugin | localStoreQuarantinesInvalidSettingsFileAndRecovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `localStoreQuarantinesInvalidSettingsFileAndRecovers` |
| 6 | AgentRulesPlugin | localStoreReportsFailureWhenSettingsDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localStoreReportsFailureWhenSettingsDirectoryIsBlocked` |
| 7 | AgentRulesPlugin | listRulesReadsUTF16MarkdownMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listRulesReadsUTF16MarkdownMetadata` |
| 8 | AgentRulesPlugin | readRuleReturnsUTF16MarkdownContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readRuleReturnsUTF16MarkdownContent` |
| 9 | AgentRulesPlugin | normalizedLimitCoercesAndClamps | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizedLimitCoercesAndClamps` |
| 10 | AgentRulesPlugin | Plugin toolbar is registered and removed with its project observer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginOwnsToolbarLifecycle` |
| 11 | AgentRulesPlugin | Current project changes replace toolbar rules and closing clears them | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectObserverUpdatesToolbarViewModel` |
| 12 | AgentRulesPlugin | Rule details load from the project that owns the selected rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedRuleUsesViewModelProjectPath` |
| 13 | AgentRulesPlugin | A late rule-list response cannot replace the newly selected project | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleProjectLoadIsIgnored` |
| 14 | AgentRulesRuntimeDirectory | 注入目录后 settingsDirectory 返回该目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 15 | AgentRulesRuntimeDirectory | 重置后清空注入目录，不再回退到真实数据目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetClearsInjectedDirectory` |
| 16 | AgentRulesConversationScope | list_agent_rules 读取会话绑定项目而非 UI 当前项目 | 会话绑定项目 A，UI 当前为 B | 调用 `executeResult(context:arguments:)` | 只返回项目 A 的规则 | P0 | ✅ 已覆盖 | `listToolUsesConversationProject` |
| 17 | AgentRulesConversationScope | create_agent_rule 写入会话绑定项目而非 UI 当前项目 | 会话绑定项目 A，UI 当前为 B | 调用 `executeResult(context:arguments:)` | 规则落在 A 的 `.lumi/rules`，B 无文件 | P0 | ✅ 已覆盖 | `createToolWritesIntoConversationProject` |
| 18 | AgentRulesConversationScope | 显式 project_path 优先于会话绑定项目 | 会话绑定 A，显式传 B | 调用 `executeResult(context:arguments:)` | 规则落在 B 的 `.lumi/rules`，A 无文件 | P1 | ✅ 已覆盖 | `explicitProjectPathBeatsConversationProject` |
| 19 | AgentRulesPlugin | `.lumi/rules` 被普通文件占住时抛错 | `.agent/rules` 有可用规则，`.lumi/rules` 是普通文件 | 调用 `listRules` | 抛出 `AgentRulesError`，不返回不完整列表 | P0 | ✅ 已覆盖 | `listRulesThrowsWhenRulesPathIsNotADirectory` |
| 20 | AgentRulesPlugin | 目录不可枚举时抛错 | `.lumi/rules` 权限为 000 | 调用 `listRules` | 抛出 `AgentRulesError`，不返回 count=0 | P0 | ✅ 已覆盖 | `listRulesThrowsWhenRulesDirectoryIsUnreadable` |
| 21 | AgentRulesPlugin | createRuleWritesIntoLumiDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createRuleWritesIntoLumiDirectory` |
| 22 | AgentRulesPlugin | listRulesStillReadsLegacyAgentDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listRulesStillReadsLegacyAgentDirectory` |
| 23 | AgentRulesPlugin | listRulesMergesBothDirectoriesAndPrefersLumi | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listRulesMergesBothDirectoriesAndPrefersLumi` |
| 24 | AgentRulesPlugin | readRuleFallsBackToLegacyAgentDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readRuleFallsBackToLegacyAgentDirectory` |
| 25 | AgentRulesToolbar | 规则变化通知只刷新当前项目的工具栏 | 当前项目 A，先通知 B 再通知 A | 发送 `agentRulesDidChange` 通知 | B 的通知不触发加载；A 的通知触发第二次加载 | P0 | ✅ 已覆盖 | `rulesChangeNotificationRefreshesMatchingProject` |
| 26 | AgentRulesPlugin | create_agent_rule 成功后发出规则变化通知 | 临时项目目录 | 调用 `CreateAgentRuleTool.execute` | 收到携带该项目路径的 `agentRulesDidChange` 通知、规则文件已落盘 | P0 | ✅ 已覆盖 | `createRuleToolPostsChangeNotification` |
| 27 | AgentRulesPlugin | 规则 ID 只去掉最后一个扩展名，保留文件名内部的 .md | 先后创建 `foo.md` 与 `foo.md.md` | 创建结果、`listRules`、`readRule` | 两条 ID 分别为 `foo` 与 `foo.md`，列表无重复 ID | P0 | ✅ 已覆盖 | `ruleIdKeepsInnerMarkdownExtensions` |
| 28 | AgentRulesPlugin | 以 .md 结尾的子目录不会让列表整体失败 | 规则目录内含 `style.md` 与 `archive.md/` 子目录 | 调用 `listRules` | 返回 `style.md`，不读取目录、不抛错 | P0 | ✅ 已覆盖 | `listRulesSkipsMarkdownDirectories` |
| 29 | AgentRulesPlugin | 创建结果标题与落盘内容及后续列表一致 | content 自带一级标题 / 普通正文 | `createRule` 后调用 `listRules` | 自带标题时创建与列表都返回 `Embedded Title`；普通正文仍用参数标题 | P1 | ✅ 已覆盖 | `createRuleTitleMatchesWrittenContent` |
| 30 | AgentRulePromptBuilder | 规则超过注入预算时被截断 | 超长规则 + `maxTokens: 500` | 调用 `buildPrompt` | 保留标题、出现截断提示，估算不超过 500 token | P0 | ✅ 已覆盖 | `oversizedRulesAreTrimmedToBudget` |
| 31 | AgentRulePromptBuilder | 规则在预算内时保持完整 | 短规则 + 充足 `maxTokens` | 调用 `buildPrompt` | 规则内容完整且没有截断提示 | P1 | ✅ 已覆盖 | `rulesWithinBudgetAreKeptIntact` |
| 32 | AgentRuleInjectionBudget | 钩子注入的规则不会超出剩余输入预算 | 超长插件规则 + `injectedContentTokenBudget: 600` | 执行 `AgentRuleInjectionHook.apply(to:)` | 注入的 system 消息估算不超过 600 token 且带截断提示 | P1 | ✅ 已覆盖 | `hookHonorsInjectedContentBudget` |
| 33 | AgentRulesViewModel | 移除最后一个项目后清空已加载规则与选中路径 | 项目含 1 条规则，设置页 ViewModel 已加载 | 调用 `updateProjects([])` | 选中路径为 nil、规则清空、错误为 nil（**回归** #899） | P1 | ✅ 已覆盖 | `removingLastProjectClearsLoadedRules` |
| 34 | AgentRulesViewModel | 移除最后一个项目后清空加载错误 | 规则目录不可读，ViewModel 已记录错误 | 调用 `updateProjects([])` | 错误与规则均清空（**回归** #899） | P1 | ✅ 已覆盖 | `removingLastProjectClearsErrorMessage` |

> 说明：全部 **34 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 23 / 23
- P2: 已覆盖 1 / 1
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 34 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAgentRules
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
