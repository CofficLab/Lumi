# TestPlan — KitWebServer

## 包概述

KitWebServer 的实现包，包含 2 个主要类型；当前测试覆盖 58 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 58

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
- **StartGate**（4 条）：由 `testEarlySuccessIsDeliveredWhenArmed`、`testEarlyFailureIsDeliveredWhenArmed`、`testOnlyFirstTerminalStateIsDelivered`、`testSuccessAfterArmIsDelivered` 锁定（**回归 #201**）：启动终态（绑定成功/失败）可能早于 `arm` 到达，`StartGate` 必须缓存早到的终态并在 `arm` 时立即投递，且只投递首个终态，否则 `start()` 永久挂起。改动 `StartGate` 的 arm/succeed/fail 时优先跑对应测试文件。
- **HostValidation**（10 条）：由 `testReboundHostReadIsRejected`、`testReboundHostSameOriginWriteIsRejected`、`testLoopbackHostFormsAreAllowed` 等用例锁定（**回归 #1162**）：`Host` 不在回环白名单内时必须在鉴权/CORS/路由之前 403。改动 `dispatch` 的前置校验或 `isLoopbackHost` 时优先跑对应测试文件。

### 跨源写保护契约

写方法（POST/PUT/PATCH/DELETE）在鉴权之后、路由匹配之前校验来源：`Origin` 命中 CORS 白名单放行；`Sec-Fetch-Site` 为 `cross-site`/`same-site` 拒绝；`Origin` 与 `Host` 不同源拒绝。无 `Origin` 的非浏览器客户端保持兼容。拒绝时返回 403 与统一错误信封，且处理器不得执行。

### 回环 Host 校验契约（回归 #1162）

回环监听不是信任边界：DNS rebinding 之后浏览器把攻击者域名解析到 `127.0.0.1`，`Origin` 与 `Host` 两边都成了攻击者可控值，上面的跨源写保护因此失效，GET 更是完全不进那条检查。因此 `dispatch` 必须在**方法解析、CORS 预检、鉴权、路由匹配之前**校验 `Host`：只有直接指向回环（`127.0.0.1` / `localhost` / `::1`，可带监听端口）的值放行，其余一律 403 与统一错误信封，且不附带任何 CORS 允许头、不记录归属插件。

`Host` 的读取位置是契约的一部分：NIOHTTPTypesHTTP1 把**第一个** `Host` 提升成 `:authority` 伪头，它不在 `request.headers` 里，必须读 `request.head.authority`；重复的 `Host` 仍留在普通字段中，两者都要校验，任一非回环即拒绝。缺失或空 `Host` 放行（HTTP/1.0 与部分原生客户端），浏览器一定带 `Host`，rebinding 无法借此绕过。

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

### StartGate 早到终态投递（回归 #201）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 45 | StartGate | 早于 arm 到达的成功终态必须在 arm 时立即投递，不得挂起（回归 #201） | runTask 先于 arm 发出 succeed | succeed(port) 后再 arm | arm 立即返回该端口，start 不挂起 | P0 | ✅ 已覆盖 | `testEarlySuccessIsDeliveredWhenArmed` |
| 46 | StartGate | 早于 arm 到达的失败终态必须在 arm 时立即抛出（回归 #201） | runTask 先于 arm 发出 fail | fail(error) 后再 arm | arm 立即抛出该错误，而非超时挂起 | P0 | ✅ 已覆盖 | `testEarlyFailureIsDeliveredWhenArmed` |
| 47 | StartGate | 只投递首个终态，后续终态被忽略（回归 #201） | 先后发出 succeed 与 fail | succeed 后 fail 再 arm | 仅投递首个成功端口，第二个终态被忽略 | P0 | ✅ 已覆盖 | `testOnlyFirstTerminalStateIsDelivered` |
| 48 | StartGate | arm 之后到达的成功终态正常投递 | arm 先安装 continuation | arm 后 succeed(port) | 等待者收到该端口 | P1 | ✅ 已覆盖 | `testSuccessAfterArmIsDelivered` |

### 回环 Host 校验（回归 #1162）

用例通过 POSIX socket 发送原始 HTTP/1.1 请求：URLSession 会按 URL 自行改写 `Host`，用它无法构造「连到回环、但 Host 是攻击者域名」的 rebinding 请求。

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 49 | HostValidation | rebinding 域名的读请求必须在进入路由前被拒绝（回归 #1162） | 匿名服务器 + `GET /ping` | 原始 socket 发 Host 为攻击者域名的 GET | 403 `forbidden`，处理器不执行，日志无归属插件 | P0 | ✅ 已覆盖 | `testReboundHostReadIsRejected` |
| 50 | HostValidation | rebinding 域名不得借发现端点枚举路由（回归 #1162） | 匿名服务器 | 原始 socket 发 Host 为攻击者域名的 `GET /api/v1/routes` | 403，不返回任何路由清单 | P0 | ✅ 已覆盖 | `testReboundHostDiscoveryIsRejected` |
| 51 | HostValidation | Host/Origin/Sec-Fetch-Site 全为攻击者域名时写请求仍被拒绝（回归 #1162） | 匿名服务器 + `POST /state` | 三者同时伪造成 same-origin 的攻击者域名 | 403，跨源写保护不被 rebinding 绕过 | P0 | ✅ 已覆盖 | `testReboundHostSameOriginWriteIsRejected` |
| 52 | HostValidation | Host 校验早于鉴权，正确凭证也不能放行 rebinding（回归 #1162） | 开启 authToken 的服务器 | 带合法 Bearer + 攻击者域名 Host | 403 而非 200/401 | P0 | ✅ 已覆盖 | `testReboundHostRejectedBeforeAuthentication` |
| 53 | HostValidation | Host 校验早于 CORS 预检，拒绝响应不带允许头（回归 #1162） | 配置 CORS 白名单的服务器 | 攻击者域名 Host + Origin 的 OPTIONS | 403，且无 `Access-Control-Allow-Origin` | P0 | ✅ 已覆盖 | `testReboundHostPreflightIsRejected` |
| 54 | HostValidation | 重复 Host 头只要有一个非回环就拒绝（回归 #1162） | 匿名服务器 | 先发回环 Host 再发攻击者域名 Host | 403，不留「取第一个还是最后一个」的歧义 | P0 | ✅ 已覆盖 | `testDuplicateHostWithNonLoopbackIsRejected` |
| 55 | HostValidation | 回环 Host 的各种合法写法保持可用 | 匿名服务器 | 分别用 `127.0.0.1:p`、`localhost:p`、`[::1]:p`、`LOCALHOST:p` | 全部 200 | P1 | ✅ 已覆盖 | `testLoopbackHostFormsAreAllowed` |
| 56 | HostValidation | 回环同源写请求不受新校验影响 | 匿名服务器 + `POST /state` | Host 与 Origin 均为 `127.0.0.1:p` | 200，处理器执行 | P1 | ✅ 已覆盖 | `testLoopbackSameOriginWriteStillAllowed` |
| 57 | HostValidation | 不带 Host 的非浏览器调用方保持兼容 | 匿名服务器 | 原始请求省略 Host 头 | 200 | P1 | ✅ 已覆盖 | `testRequestWithoutHostIsAllowed` |
| 58 | HostValidation | 回环白名单按裸地址与监听端口精确比对 | 纯函数 `isLoopbackHost` | 表驱动覆盖合法/混淆/非回环写法 | 仅回环且端口匹配（或缺省）返回 true | P1 | ✅ 已覆盖 | `testLoopbackHostAllowlist` |

> 说明：全部 **58 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 13 / 13
- P1: 已覆盖 42 / 42
- P2: 已覆盖 3 / 3
- **合计: 58 / 58**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（13 条）
- **P1**: 其余功能性用例（42 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 58 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
