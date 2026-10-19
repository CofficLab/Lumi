# TestPlan — PluginTextActions

## 包概述

PluginTextActions 的实现包，包含 6 个主要类型；当前测试覆盖 14 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 14

核心组件（源码目录）:
- `Observers/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `TextSelectionReadPolicy`
- `TextActionsManualView`
- `TextActionsPlugin`
- `TextActionsSettings`
- `TextSelectionObserver`
- `TextActionsAboutView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **TextActionsPlugin**（14 条）：由 `pluginMetadata`、`textActionCatalogIsComplete`、`searchURLEncodesQueryItems` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | TextActionsPlugin | pluginMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | TextActionsPlugin | textActionCatalogIsComplete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textActionCatalogIsComplete` |
| 3 | TextActionsPlugin | searchURLEncodesQueryItems | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchURLEncodesQueryItems` |
| 4 | TextActionsPlugin | translationRequestUsesSelectedTextAndTranslationInstruction | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `translationRequestUsesSelectedTextAndTranslationInstruction` |
| 5 | TextActionsPlugin | v2TranslationRequestPreservesPromptAndText | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2TranslationRequestPreservesPromptAndText` |
| 6 | TextActionsPlugin | v2PluginPreservesIdentityAndOptInPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesIdentityAndOptInPolicy` |
| 7 | TextActionsPlugin | copyActionWritesToPasteboard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `copyActionWritesToPasteboard` |
| 8 | TextActionsPlugin | emptySelectionDoesNotPresentMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptySelectionDoesNotPresentMenu` |
| 9 | TextActionsPlugin | nonEmptySelectionPresentsMenu | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonEmptySelectionPresentsMenu` |
| 10 | TextActionsPlugin | menuLayoutClampsToScreenEdges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `menuLayoutClampsToScreenEdges` |
| 11 | TextActionsPlugin | selectionManagerStartsOnlyOnceAndStopsMonitoring | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerStartsOnlyOnceAndStopsMonitoring` |
| 12 | TextActionsPlugin | selectionManagerDoesNotMonitorWithoutAccessibilityPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerDoesNotMonitorWithoutAccessibilityPermission` |
| 13 | TextActionsPlugin | selectionManagerCanStartAfterPermissionIsGranted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionManagerCanStartAfterPermissionIsGranted` |
| 14 | TextActionsPlugin | selectedTextProviderCanSimulateAXRetrySequence | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectedTextProviderCanSimulateAXRetrySequence` |

> 说明：全部 **14 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 11 / 11
- P2: 已覆盖 2 / 2
- **合计: 14 / 14**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（11 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 14 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginTextActions
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
