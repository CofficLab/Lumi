# TestPlan — ProviderPerformanceMetrics

## 包概述

ProviderPerformanceMetrics Lumi 编辑器 Provider。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 9

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PerformanceTrace`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **PerformanceMetricsObservation**（4 条）：由 `recordFiresDidRecordForEachEvent`、`clearFiresDidClear`、`cancelledHandleStopsReceiving` 等用例锁定；改动该模块时优先跑对应测试文件。
- **PerformanceMetricsProvider**（5 条）：由 `reportAggregatesEvents`、`retentionIsBounded`、`traceRecordsStages` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | PerformanceMetricsObservation | recordFiresDidRecordForEachEvent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordFiresDidRecordForEachEvent` |
| 2 | PerformanceMetricsObservation | clearFiresDidClear | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearFiresDidClear` |
| 3 | PerformanceMetricsObservation | cancelledHandleStopsReceiving | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledHandleStopsReceiving` |
| 4 | PerformanceMetricsObservation | observerCanReenterProviderWithoutDeadlock | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerCanReenterProviderWithoutDeadlock` |
| 5 | PerformanceMetricsProvider | aggregates percentiles and total events | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportAggregatesEvents` |
| 6 | PerformanceMetricsProvider | retains only the configured event window | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retentionIsBounded` |
| 7 | PerformanceMetricsProvider | trace records cumulative checkpoints and total | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `traceRecordsStages` |
| 8 | PerformanceMetricsProvider | clear removes in-memory metrics and persisted metrics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearRemovesMetrics` |
| 9 | PerformanceMetricsProvider | persists a bounded snapshot for the next provider instance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistsAcrossInstances` |

> 说明：全部 **9 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 8 / 8
- P2: 已覆盖 0 / 0
- **合计: 9 / 9**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（8 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 9 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderPerformanceMetrics
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
