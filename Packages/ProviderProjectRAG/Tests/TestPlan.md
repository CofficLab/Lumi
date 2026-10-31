# TestPlan — ProviderProjectRAG

## 包概述

ProviderProjectRAG 的实现包，包含 1 个主要类型；当前测试覆盖 20 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 20

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectRAGEvent`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ProjectRAGProviding**（20 条）：由 `responseIsSendableValue`、`lineRangeClampsEndBelowStart`、`searchResultConvenienceDefaults` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ProjectRAGProviding | response keeps query and result order | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseIsSendableValue` |
| 2 | ProjectRAGProviding | line range clamps end to at least start | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineRangeClampsEndBelowStart` |
| 3 | ProjectRAGProviding | search result defaults to semantic kind and no range | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `searchResultConvenienceDefaults` |
| 4 | ProjectRAGProviding | match kind exposes all four kinds with expected raw values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchKindRawValues` |
| 5 | ProjectRAGProviding | match kinds compare by case | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchKindEquality` |
| 6 | ProjectRAGProviding | line range with equal start and end is valid | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineRangeSingleLine` |
| 7 | ProjectRAGProviding | line range equality compares both ends | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lineRangeEquality` |
| 8 | ProjectRAGProviding | search result carries explicit line range | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchResultWithLineRange` |
| 9 | ProjectRAGProviding | search result equality compares all fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchResultEquality` |
| 10 | ProjectRAGProviding | response preserves result order | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsePreservesOrder` |
| 11 | ProjectRAGProviding | response accepts empty result list | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `responseAcceptsEmptyResults` |
| 12 | ProjectRAGProviding | index status preserves all metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `indexStatusPreservesFields` |
| 13 | ProjectRAGProviding | index status equality compares all fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `indexStatusEquality` |
| 14 | ProjectRAGProviding | events with associated values compare by content | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eventEquality` |
| 15 | ProjectRAGProviding | default isIndexing returns false | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultIsIndexingIsFalse` |
| 16 | ProjectRAGProviding | default observer handle cancel is a safe no-op | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultObserverHandleCancelIsSafe` |
| 17 | ProjectRAGProviding | search convenience overload forwards nil projectPath and topK 8 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `searchConvenienceForwardsDefaults` |
| 18 | ProjectRAGProviding | search explicit overload forwards supplied values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchExplicitForwardsValues` |
| 19 | ProjectRAGProviding | ensureIndexed convenience overload forwards force=false background=false | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `ensureIndexedConvenienceForwardsDefaults` |
| 20 | ProjectRAGProviding | NoopProjectRAGObserverHandle cancels without side effects | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noopHandleCancelIsSafe` |

> 说明：全部 **20 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 14 / 14
- P2: 已覆盖 6 / 6
- **合计: 20 / 20**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 20 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderProjectRAG
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
