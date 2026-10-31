# TestPlan — PluginAgentRules

## 包概述

PluginAgentRules 的实现包，包含 14 个主要类型；当前测试覆盖 15 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 15

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

- **AgentRulePromptBuilder**（2 条）：由 `projectRulesTakePrecedence`、`emptyRulesProduceNoPrompt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentRulesPlugin**（11 条）：由 `packageLoads`、`pluginHasRequiredMetadata`、`localStoreQuarantinesInvalidSettingsFileAndRecovers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AgentRulesRuntimeDirectory**（2 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。

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

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 13 / 13
- P2: 已覆盖 1 / 1
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
