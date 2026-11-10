# TestPlan — PluginConversationTitle

## 包概述

PluginConversationTitle 的实现包，包含 6 个主要类型；当前测试覆盖 60 条用例。

平台: iOS 17+
测试文件: 9 个，用例总数: 60

核心组件（源码目录）:
- `Observers/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationTitlePlugin`
- `ConversationTitleHeaderObserver`
- `TitleService`
- `TitleUpdateTool`
- `ConversationTitleViewModel`
- `HeaderView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AutoTitleRule**（19 条）：由 `appliesWhenNoTitle`、`protectsCustomTitle`、`skipsWhenSameAsCurrent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConversationScopedTitleUpdate**（3 条）：由 `writesToCallingConversationInsteadOfSelection`、`doesNotLeakIntoOtherConversation`、`legacyPathStillUsesSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HeaderTitleObserver**（7 条）：由 `viewModelSkipsDuplicateTitle`、`viewModelStartsEmpty`、`syncsInitialTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（4 条）：由 `normalizeTitle`、`placeholderTitle`、`updateToolUpdatesTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleServiceBackfill**（4 条）：由 `backfillsUntitledConversation`、`skipsTitledConversation`、`skipsConversationWithoutUserMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleServiceFallback**（4 条）：由 `fallsBackWhenLLMThrows`、`fallsBackWhenLLMReturnsEmptyTitle`、`fallbackDoesNotOverwriteCustomTitle` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleService**（11 条）：由 `generatesTitleForFirstUserMessage`、`composesPromptWithFence`、`ignoresNonFirstUserMessage` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TitleUpdateTool**（8 条）：由 `updatesSelectedTitle`、`trimsWhitespace`、`reportsMissingProvider` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AutoTitleRule | shouldApplyGeneratedTitle：无标题时放行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesWhenNoTitle` |
| 2 | AutoTitleRule | shouldApplyGeneratedTitle：保护自定义标题 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `protectsCustomTitle` |
| 3 | AutoTitleRule | shouldApplyGeneratedTitle：生成结果与当前标题相同则跳过 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `skipsWhenSameAsCurrent` |
| 4 | AutoTitleRule | shouldApplyGeneratedTitle：占位标题可被替换 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `replacesPlaceholderTitle` |
| 5 | AutoTitleRule | shouldApplyGeneratedTitle：短消息的占位标题等于原文 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shortMessagePlaceholderEqualsSource` |
| 6 | AutoTitleRule | shouldApplyGeneratedTitle：生成前预检查不比较生成值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `preflightCheckIgnoresGeneratedTitle` |
| 7 | AutoTitleRule | fencedUserMessage：转义闭合标签，阻断标签注入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fencesClosingTag` |
| 8 | AutoTitleRule | fencedUserMessage：普通消息原样包裹 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fencesPlainMessage` |
| 9 | AutoTitleRule | normalizeTitle：空串与纯空白返回空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeEmpty` |
| 10 | AutoTitleRule | normalizeTitle：跳过前置空行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeSkipsLeadingBlankLines` |
| 11 | AutoTitleRule | normalizeTitle：剥离成对引号与书名号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeStripsWrappers` |
| 12 | AutoTitleRule | normalizeTitle：折叠内部空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeCollapsesWhitespace` |
| 13 | AutoTitleRule | normalizeTitle：40 字符边界不截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizeLengthBoundary` |
| 14 | AutoTitleRule | normalizeTitle：截断后清理尾部空白 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizeTrimsAfterTruncation` |
| 15 | AutoTitleRule | placeholderTitle：折叠换行与连续空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderCollapsesWhitespace` |
| 16 | AutoTitleRule | placeholderTitle：恰好 40 字符不追加省略号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderLengthBoundary` |
| 17 | AutoTitleRule | placeholderTitle：纯空白折叠为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderEmpty` |
| 18 | AutoTitleRule | placeholderTitle：去掉开头的 system-reminder 注入块 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderStripsLeadingInjectedReminder` |
| 19 | AutoTitleRule | placeholderTitle：保留消息中间的同名标签 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `placeholderKeepsInnerReminderTag` |
| 20 | ConversationScopedTitleUpdate | 标题写入工具调用所属会话而非当前选中会话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `writesToCallingConversationInsteadOfSelection` |
| 21 | ConversationScopedTitleUpdate | 会话 B 的工具调用不会污染会话 A 的标题 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotLeakIntoOtherConversation` |
| 22 | ConversationScopedTitleUpdate | 无 context 的旧路径仍按当前选中会话更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyPathStillUsesSelection` |
| 23 | HeaderTitleObserver | ViewModel 相同标题重复写入短路 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `viewModelSkipsDuplicateTitle` |
| 24 | HeaderTitleObserver | ViewModel 初始标题为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `viewModelStartsEmpty` |
| 25 | HeaderTitleObserver | Observer 初始化时同步当前标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `syncsInitialTitle` |
| 26 | HeaderTitleObserver | 全部会话事件都触发标题刷新 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `allEventsRefreshTitle` |
| 27 | HeaderTitleObserver | 取消选择后标题回落为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clearsTitleOnDeselection` |
| 28 | HeaderTitleObserver | cancel 后不再响应会话事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsAfterCancel` |
| 29 | HeaderTitleObserver | 重复 cancel 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelIsIdempotent` |
| 30 | 综合 | 标题生成：normalizeTitle 清理引号与换行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeTitle` |
| 31 | 综合 | 占位标题：长消息截断到 40 字符 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `placeholderTitle` |
| 32 | 综合 | 标题更新工具：更新选中会话标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateToolUpdatesTitle` |
| 33 | 综合 | 标题更新工具：缺参数抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateToolMissingArgument` |
| 34 | TitleServiceBackfill | 回填为无标题对话补写占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `backfillsUntitledConversation` |
| 35 | TitleServiceBackfill | 回填跳过已有标题的对话 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `skipsTitledConversation` |
| 36 | TitleServiceBackfill | 回填跳过没有首条用户消息的对话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsConversationWithoutUserMessage` |
| 37 | TitleServiceBackfill | 回填把过长的首条消息截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncatesLongFirstUserMessage` |
| 38 | TitleServiceFallback | 标题生成抛错时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackWhenLLMThrows` |
| 39 | TitleServiceFallback | 标题生成为空时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackWhenLLMReturnsEmptyTitle` |
| 40 | TitleServiceFallback | 兜底不覆盖用户自定义标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallbackDoesNotOverwriteCustomTitle` |
| 41 | TitleServiceFallback | 占位标题取自首条用户消息并截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `placeholderTitleComesFromFirstUserMessage` |
| 42 | TitleService | 首条用户消息生成标题并写库 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `generatesTitleForFirstUserMessage` |
| 43 | TitleService | 生成标题的请求包含 system 指令与包裹后的用户消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `composesPromptWithFence` |
| 44 | TitleService | 非首条用户消息不触发标题生成 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `ignoresNonFirstUserMessage` |
| 45 | TitleService | 非用户角色的消息被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresNonUserRole` |
| 46 | TitleService | 已有自定义标题时不覆盖 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `doesNotOverwriteCustomTitle` |
| 47 | TitleService | LLM 失败时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesFallbackTitleWhenLLMFails` |
| 48 | TitleService | LLM 返回空标题时写入占位标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `appliesFallbackTitleWhenLLMReturnsEmptyTitle` |
| 49 | TitleService | 写库失败时不抛出异常 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toleratesPersistenceFailure` |
| 50 | TitleService | 空内容用户消息被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresBlankMessage` |
| 51 | TitleService | stop 后不再响应消息插入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsObserving` |
| 52 | TitleService | 重复 stop 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopIsIdempotent` |
| 53 | TitleUpdateTool | 更新选中会话标题返回成功文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updatesSelectedTitle` |
| 54 | TitleUpdateTool | 写入前裁剪标题首尾空白 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `trimsWhitespace` |
| 55 | TitleUpdateTool | Provider 缺失时抛出服务不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingProvider` |
| 56 | TitleUpdateTool | 未选中会话时抛出未找到 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsNoSelection` |
| 57 | TitleUpdateTool | 写库失败时抛出更新失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsPersistenceFailure` |
| 58 | TitleUpdateTool | 非法 title 参数抛 ToolExecutionError | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidArguments` |
| 59 | TitleUpdateTool | 工具描述与输入 schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metadata` |
| 60 | TitleUpdateTool | displayDescription 回退与正常展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescription` |

> 说明：全部 **60 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 14 / 14
- P2: 已覆盖 35 / 35
- **合计: 60 / 60**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（35 条）

## 跨平台说明

- Package 声明: iOS 17+
- 60 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationTitle
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
