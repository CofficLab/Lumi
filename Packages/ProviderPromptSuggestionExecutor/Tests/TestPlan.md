# TestPlan — ProviderPromptSuggestionExecutor

## 包概述

ProviderPromptSuggestionExecutor 是提示建议的**执行器实现包**，把 `PromptSuggestion` 的
动作落到内核已注册的 Provider 上（启用插件、激活活动栏 / 侧边栏 tab、跳转设置页、发送消息）。

契约与内存实现（`PromptSuggestionProviding` / `PromptSuggestionExecuting` /
`DefaultPromptSuggestionProvider`）已上提到共享包 `LumiProviders` 的
`ProviderPromptSuggestion` target，本包只保留依赖 `ProviderMessageSender` 的执行器。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 4

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultPromptSuggestionExecutor`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **PromptSuggestionExecutor**（4 条）：由 `localizesPluginEnabledToastStrings`、`forwardsProjectFolderSelection`、`publishesOpenSettingsNotification` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | PromptSuggestionExecutor | 插件启用 Toast 支持中文本地化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizesPluginEnabledToastStrings` |
| 2 | PromptSuggestionExecutor | 文件夹选择动作委托给 UI 回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsProjectFolderSelection` |
| 3 | PromptSuggestionExecutor | 打开设置动作发布设置通知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publishesOpenSettingsNotification` |
| 4 | PromptSuggestionExecutor | 插件入口动作同时激活 ActivityBar 和 Rail tab | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatesPluginEntryAndRailTab` |

> 说明：全部 **4 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 4 / 4
- P2: 已覆盖 0 / 0
- **合计: 4 / 4**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（4 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 4 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderPromptSuggestionExecutor
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
