# TestPlan — PluginConversationBehavior

## 包概述

PluginConversationBehavior 的实现包，包含 5 个主要类型；当前测试覆盖 13 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 13

核心组件（源码目录）:
- `Hooks/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationLanguagePlugin`
- `ConversationReasoningPlugin`
- `ToolbarMetrics`
- `ConversationLanguageHook`
- `ConversationBehaviorToast`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（9 条）：由 `reasoningRegisters`、`reasoningRoundTrip`、`languageHookInjectsPreferenceAndPreservesHistory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **本地化**（4 条）：`reasoningEffortNamesUseInjectedLocalization` 锁定档位名称必须经过插件本地化解析；`reasoningEffortStringsHaveTranslationsInCompiledBundle` 锁定 5 个词条在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 均有译文（#918）；`reasoningChipOffUsesLocalizedKey` 锁定关闭态 chip 走 `Off` 词条而非 `OFF` 字面量，`offStringHasTranslationsInCompiledBundle` 锁定该词条的译文（#917）。改动 `ConversationReasoningPlugin`、`Support/` 或 `Resources/Localizable.xcstrings` 时须保持成立。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | Reasoning 插件注册 ActionBar 按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningRegisters` |
| 2 | 综合 | Reasoning 档位经 ConversationManaging 读写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningRoundTrip` |
| 3 | 综合 | Language hook prepends localized transient system instruction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageHookInjectsPreferenceAndPreservesHistory` |
| 4 | 综合 | Language hook leaves context unchanged after manager deallocation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageHookWithoutManagerIsNoop` |
| 5 | 综合 | Language plugin registers and cancels its toolbar and lifecycle hook | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languagePluginLifecycle` |
| 6 | 综合 | 选中会话时切换语言只影响该会话，不改全局默认 | 全局默认 `.chinese`，已选中会话 | 选择 `.english` | 会话语言变化，全局默认仍为 `.chinese` | P1 | ✅ 已覆盖 | `languageSelectionDoesNotChangeGlobalDefault` |
| 7 | 综合 | Language selection without a selected conversation updates global preference | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `languageSelectionWithoutConversationUpdatesGlobalPreference` |
| 8 | 综合 | 选中会话时调整 Reasoning 只影响该会话，不改全局默认 | 全局默认 `.medium`，已选中会话 | apply `.low`、再 apply `.off` | 会话档位变化，全局默认始终为 `.medium` | P1 | ✅ 已覆盖 | `reasoningSelectionDoesNotChangeGlobalDefault` |
| 9 | 综合 | New Chat（无选中会话）调整 Reasoning 才更新全局默认 | 未选中任何会话 | apply `.high`、再 apply `.off` | 全局默认依次变为 `.high`、`nil` | P1 | ✅ 已覆盖 | `reasoningSelectionWithoutConversationUpdatesGlobalDefault` |
| 10 | 本地化 | 推理档位名称经过注入的本地化解析（**回归 #918**） | — | 对五个档位调用名称解析并注入替身解析器 | 名称取自注入解析器，而非 `ReasoningEffort` 中写死的中文 | P1 | ✅ 已覆盖 | `reasoningEffortNamesUseInjectedLocalization` |
| 11 | 本地化 | 推理档位词条在所有规范语言下都有译文（**回归 #918**） | — | 读取编译产物中每种语言的 `Localizable.strings` | 5 个词条在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 均有对应译文 | P1 | ✅ 已覆盖 | `reasoningEffortStringsHaveTranslationsInCompiledBundle` |
| 12 | 本地化 | 关闭态的 chip 文案使用 Off 本地化词条（**回归 #917**） | — | 以 nil 档位与 `.high` 调用 chip 文案解析并注入替身解析器 | nil 档位返回注入解析器的 `Off` 结果，非 nil 返回档位代码 | P1 | ✅ 已覆盖 | `reasoningChipOffUsesLocalizedKey` |
| 13 | 本地化 | Off 词条在所有规范语言下都有译文（**回归 #917**） | — | 读取编译产物中每种语言的 `Localizable.strings` | `Off` 在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 均有对应译文 | P1 | ✅ 已覆盖 | `offStringHasTranslationsInCompiledBundle` |

> 说明：全部 **13 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 13 / 13
- P2: 已覆盖 0 / 0
- **合计: 13 / 13**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（13 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 13 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationBehavior
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
