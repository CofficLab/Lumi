# TestPlan — KitWebServer

## 包概述

KitWebServer 的实现包，包含 2 个主要类型；当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 18

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LumiWebServerError`
- `RouteMatcher`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **LumiWebServer**（11 条）：由 `testLiveRouteEchoAndParams`、`testNotFound`、`testAuthToken` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RouteMatcher**（7 条）：由 `testLiteralExactMatch`、`testParameterCapture`、`testMultipleParameters` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | LumiWebServer | testLiveRouteEchoAndParams | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLiveRouteEchoAndParams` |
| 2 | LumiWebServer | testNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNotFound` |
| 3 | LumiWebServer | testAuthToken | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAuthToken` |
| 4 | LumiWebServer | testDiscoveryEndpoint | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDiscoveryEndpoint` |
| 5 | LumiWebServer | testDiscoveryRequiresAuthWhenEnabled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDiscoveryRequiresAuthWhenEnabled` |
| 6 | LumiWebServer | testOnActivityReportsRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testOnActivityReportsRequest` |
| 7 | LumiWebServer | testNilAndEmptyQueryReturnEmptyDictionary | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testNilAndEmptyQueryReturnEmptyDictionary` |
| 8 | LumiWebServer | testParsesMultipleKeyValuePairs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testParsesMultipleKeyValuePairs` |
| 9 | LumiWebServer | testPairWithoutEqualsSignGetsEmptyValue | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testPairWithoutEqualsSignGetsEmptyValue` |
| 10 | LumiWebServer | testPercentDecodesKeysAndValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPercentDecodesKeysAndValues` |
| 11 | LumiWebServer | testEqualsSignInsideValueIsPreserved | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEqualsSignInsideValueIsPreserved` |
| 12 | RouteMatcher | testLiteralExactMatch | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLiteralExactMatch` |
| 13 | RouteMatcher | testParameterCapture | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testParameterCapture` |
| 14 | RouteMatcher | testMultipleParameters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMultipleParameters` |
| 15 | RouteMatcher | testSingleWildcard | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSingleWildcard` |
| 16 | RouteMatcher | testDoubleWildcardRest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDoubleWildcardRest` |
| 17 | RouteMatcher | testLeadingTrailingSlashesIgnored | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLeadingTrailingSlashesIgnored` |
| 18 | RouteMatcher | testEmptyAndRoot | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testEmptyAndRoot` |

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 15 / 15
- P2: 已覆盖 3 / 3
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitWebServer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
