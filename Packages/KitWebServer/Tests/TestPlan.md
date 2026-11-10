# TestPlan — KitWebServer

## 包概述

KitWebServer 的实现包，包含 2 个主要类型；当前测试覆盖 44 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 44

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LumiWebServerError`
- `RouteMatcher`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **LumiWebServer**（12 条）：由 `testLiveRouteEchoAndParams`、`testNotFound`、`testAuthToken` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RouteMatcher**（7 条）：由 `testLiteralExactMatch`、`testParameterCapture`、`testMultipleParameters` 等用例锁定；改动该模块时优先跑对应测试文件。

- **LumiWebServerEndToEndTests**（1 条）：由 `testDeclaredRoutesAreReachableOverHTTP` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Payload**（1 条）：由 `testDiscoveryEndpointListsRegisteredRoutes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RouteInfo**（1 条）：由 `testUnregisteredRoutesBecomeUnreachable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LumiWebServerPipelineTests**（8 条）：由 `testAuthRejectsBeforeRouteMatching`、`testAuthErrorBodyIsUnified`、`testCrossOriginWriteRejectedBeforeRoute` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Body**（14 条）：由 `testAnonymousAccessAllowed`、`testResponseCarriesRequestID` 等用例锁定；改动该模块时优先跑对应测试文件。

### 跨源写保护契约

写方法（POST/PUT/PATCH/DELETE）在鉴权之后、路由匹配之前校验来源：`Origin` 命中 CORS 白名单放行；`Sec-Fetch-Site` 为 `cross-site`/`same-site` 拒绝；`Origin` 与 `Host` 不同源拒绝。无 `Origin` 的非浏览器客户端保持兼容。拒绝时返回 403 与统一错误信封，且处理器不得执行。

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
| 19 | LumiWebServer | testStopDuringStartClosesListenerAndAllowsRestart | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testStopDuringStartClosesListenerAndAllowsRestart` |
| 20 | LumiWebServerEndToEndTests | testDeclaredRoutesAreReachableOverHTTP | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDeclaredRoutesAreReachableOverHTTP` |
| 21 | Payload | testDiscoveryEndpointListsRegisteredRoutes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDiscoveryEndpointListsRegisteredRoutes` |
| 22 | RouteInfo | testUnregisteredRoutesBecomeUnreachable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnregisteredRoutesBecomeUnreachable` |
| 23 | LumiWebServerPipelineTests | testAuthRejectsBeforeRouteMatching | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testAuthRejectsBeforeRouteMatching` |
| 24 | LumiWebServerPipelineTests | testAuthErrorBodyIsUnified | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAuthErrorBodyIsUnified` |
| 25 | Body | testAnonymousAccessAllowed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAnonymousAccessAllowed` |
| 26 | Body | testResponseCarriesRequestID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testResponseCarriesRequestID` |
| 27 | Body | testRequestIDIsPassedThrough | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestIDIsPassedThrough` |
| 28 | Body | testAPIErrorMapsToStatusCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAPIErrorMapsToStatusCode` |
| 29 | Body | testUnknownErrorBecomesGenericInternalError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnknownErrorBecomesGenericInternalError` |
| 30 | Body | testMethodMismatchReturns405 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMethodMismatchReturns405` |
| 31 | Body | testNotFoundReturnsUnifiedError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNotFoundReturnsUnifiedError` |
| 32 | Body | testRequestLogRecordsRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestLogRecordsRequest` |
| 33 | Body | testRequestLogRecordsFailures | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRequestLogRecordsFailures` |
| 34 | Body | testRequestLogDoesNotLeakBody | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRequestLogDoesNotLeakBody` |
| 35 | Body | testCORSPreflightResponse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCORSPreflightResponse` |
| 36 | Body | testCORSRejectsUnlistedOrigin | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCORSRejectsUnlistedOrigin` |
| 37 | Body | testUptimeReflectsRunningState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUptimeReflectsRunningState` |
| 38 | Body | testRegisteredRouteSummaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRegisteredRouteSummaries` |
| 39 | LumiWebServerPipelineTests | testCrossOriginWriteRejectedBeforeRoute | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCrossOriginWriteRejectedBeforeRoute` |
| 40 | LumiWebServerPipelineTests | testCrossSiteFetchMetadataRejected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCrossSiteFetchMetadataRejected` |
| 41 | LumiWebServerPipelineTests | testSameOriginWriteIsAllowed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSameOriginWriteIsAllowed` |
| 42 | LumiWebServerPipelineTests | testWriteWithoutOriginIsAllowed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testWriteWithoutOriginIsAllowed` |
| 43 | LumiWebServerPipelineTests | testCORSAllowlistedOriginWriteIsAllowed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCORSAllowlistedOriginWriteIsAllowed` |
| 44 | LumiWebServerPipelineTests | testCrossOriginReadIsAllowed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testCrossOriginReadIsAllowed` |

> 说明：全部 **44 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 37 / 37
- P2: 已覆盖 3 / 3
- **合计: 44 / 44**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（37 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 44 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
