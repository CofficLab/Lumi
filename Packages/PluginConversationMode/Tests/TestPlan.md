# TestPlan — PluginConversationMode

## 包概述

PluginConversationMode 的实现包，包含 3 个主要类型；当前测试覆盖 7 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 7

核心组件（源码目录）:
- `Observers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AutomationLevelToolbarView`
- `ConversationModePlugin`
- `ConversationManagerObservationBox`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ConversationModePlugin**（3 条）：由 `pluginLifecycle`、`automationLevelRoundTrip`、`conversationObservationBoxUsesTypedEvents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **本地化**（2 条）：`automationLevelTextUsesInjectedLocalization` 锁定名称/说明必须经过插件本地化解析；`automationLevelStringsHaveTranslationsInCompiledBundle` 锁定 6 个词条在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 均有译文（#919）。改动 `AutomationLevelToolbarView`、`Support/` 或 `Resources/Localizable.xcstrings` 时须保持成立。
- **自动化级别工具栏**（2 条）：`existingConversationModeSwitchDoesNotChangeGlobalDefault` 锁定「已有会话里切换只改该会话，不得污染全局默认（新建会话的初始模式）」；`noSelectionLevelSwitchUpdatesGlobalDefault` 锁定「无选中会话时切换写全局」。改动 `AutomationLevelToolbarView.updateAutomationLevel` 时须保持成立（#608）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ConversationModePlugin | 插件 onBoot/onShutdown 不抛错且 Provider 保持可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginLifecycle` |
| 2 | ConversationModePlugin | 全局自动化级别通过 ConversationManaging 读写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `automationLevelRoundTrip` |
| 3 | ConversationModePlugin | 会话观察盒通过类型化事件刷新并支持取消 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationObservationBoxUsesTypedEvents` |
| 4 | 本地化 | 自动化等级名称与说明经过注入的本地化解析（**回归 #919**） | — | 对三档等级调用名称/说明解析并注入替身解析器 | 文案取自注入解析器，而非 `AutomationLevel` 中写死的中文 | P1 | ✅ 已覆盖 | `automationLevelTextUsesInjectedLocalization` |
| 5 | 本地化 | 自动化等级词条在所有规范语言下都有译文（**回归 #919**） | — | 读取编译产物中每种语言的 `Localizable.strings` | 6 个词条在 en / zh-Hans / zh-Hant / zh-HK / zh-TW 均有对应译文 | P1 | ✅ 已覆盖 | `automationLevelStringsHaveTranslationsInCompiledBundle` |
| 6 | 自动化级别工具栏 | 切换已有会话的自动化级别不得改写全局默认（**回归 #608**） | 全局 Build + 创建并自动选中会话 A | 工具栏切到 Chat 后再新建会话 B | A 变为 Chat；全局默认仍为 Build；B 继承 Build 而非 Chat | P0 | ✅ 已覆盖 | `existingConversationModeSwitchDoesNotChangeGlobalDefault` |
| 7 | 自动化级别工具栏 | 无选中会话时切换自动化级别写入全局默认（**回归 #608**） | 全局 Build + 无选中会话 | 工具栏切到 Autonomous | 全局默认与 `automationLevel(for: nil)` 均为 Autonomous | P1 | ✅ 已覆盖 | `noSelectionLevelSwitchUpdatesGlobalDefault` |

> 说明：全部 **7 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> **#608 变异验证**（两处独立变异分别 RED，恢复后 GREEN）：M1 把
> `updateAutomationLevel` 的全局写入改回无条件执行（去掉 else）→ ID 6 RED
> （全局默认被临时切换污染，新建会话 B 继承 Chat），ID 7 仍 GREEN；M2 去掉
> else 分支里的 `setGlobalAutomationLevel`（无选中会话时也不写全局）→ ID 7 RED
> （全局默认不更新），ID 6 仍 GREEN。两处变异分别锁定「已有会话不得写全局」
> 与「无选中会话必须写全局」两条互斥分支。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 6 / 6
- P2: 已覆盖 0 / 0
- **合计: 7 / 7**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 7 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationMode
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
