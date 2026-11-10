# TestPlan — ProviderWebServer

## 包概述

ProviderWebServer 的实现包，包含 5 个主要类型；当前测试覆盖 12 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 58

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultWebServerProviding`
- `HTTPMethod`
- `WebRequestActivity`
- `WebRouteRequest`
- `WebServerEvent`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultWebServerProviding**（6 条）：由 `emitsServerEvents`、`emitsActivityAfterHandlingRoute`、`registerReplaceUnregister` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（6 条）：由 `requestActivityClassification`、`httpMethodRawValues`、`requestDecodesBody` 等用例锁定；改动该模块时优先跑对应测试文件。

- **WebAPIError**（5 条）：由 `mapsToStatusCodes`、`hasStableCodes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebAuthPolicy**（11 条）：由 `rejectsMissingCredentials`、`allowsAnonymous` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebPagination**（9 条）：由 `defaults`、`parsesQuery` 等用例锁定；改动该模块时优先跑对应测试文件。
- **请求日志**（3 条）：由 `recordsNewestFirst`、`trimsOldest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebCORSPolicy**（4 条）：由 `allowsAnyOrigin`、`echoesMatchingOrigin` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebRouteBuilder**（4 条）：由 `buildsRoutes`、`generatesStableIDs` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebRouteRequest**（1 条）：由 `decodesBody` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Payload**（5 条）：由 `throwsBadRequestOnInvalidJSON`、`throwsBadRequestOnEmptyBody` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebRouteRegistry**（4 条）：由 `registersAndUnregisters`、`replacesOnSecondRegistration` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultWebServerProviding | 运行状态和路由变化会发出语义事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitsServerEvents` |
| 2 | DefaultWebServerProviding | 命中路由后发出包含归属插件的活动事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitsActivityAfterHandlingRoute` |
| 3 | DefaultWebServerProviding | 按插件注册/替换/注销路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerReplaceUnregister` |
| 4 | DefaultWebServerProviding | 匹配 :param 占位符并区分 404/405 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `routeMatching` |
| 5 | DefaultWebServerProviding | start/stop 状态切换且可重复调用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `startStop` |
| 6 | DefaultWebServerProviding | 可作为 any WebServerProviding 使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerAsExistential` |
| 7 | 综合 | 请求活动区分写操作与成功状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestActivityClassification` |
| 8 | 综合 | HTTPMethod rawValue 与 HTTP 方法一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpMethodRawValues` |
| 9 | 综合 | WebRouteRequest 可构造并解码 JSON body | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestDecodesBody` |
| 10 | 综合 | WebRouteResponse 工厂方法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseFactories` |
| 11 | 综合 | WebRoute 可创建并携带描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `webRouteConstruction` |
| 12 | 综合 | WebServerProviding 可注册实现并通过协议访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerAccessibleThroughProtocol` |
| 13 | WebAPIError | 每个错误映射到约定的状态码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mapsToStatusCodes` |
| 14 | WebAPIError | 错误码是稳定的机器可读字符串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `hasStableCodes` |
| 15 | WebAPIError | 只有 badRequest 携带字段名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fieldOnlyOnBadRequest` |
| 16 | WebAPIError | 错误体编码为统一形状 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesErrorBody` |
| 17 | WebAPIError | 成功信封携带 data 与版本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesEnvelope` |
| 18 | WebAuthPolicy | 强制鉴权时缺少凭证被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsMissingCredentials` |
| 19 | WebAuthPolicy | 允许匿名时缺少凭证通过 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowsAnonymous` |
| 20 | WebAuthPolicy | Bearer 凭证被正确提取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractsBearerToken` |
| 21 | WebAuthPolicy | 兼容不带 Bearer 前缀的裸 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsBareToken` |
| 22 | WebAuthPolicy | API Key 从 X-API-Key 头提取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extractsAPIKey` |
| 23 | WebAuthPolicy | 允许匿名时错误凭证仍被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsWrongCredentialsEvenWhenAnonymousAllowed` |
| 24 | WebAuthPolicy | 没有校验器时任何凭证都不通过 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsWithoutVerifier` |
| 25 | WebAuthPolicy | 策略相等性只看方案与匿名标志 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalityIgnoresVerifier` |
| 26 | WebAuthPolicy | 凭证存储支持多把 key 轮换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportsMultipleCredentials` |
| 27 | WebAuthPolicy | 移除凭证后立即失效 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removesCredentials` |
| 28 | WebAuthPolicy | API Key 方案也可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supportsAPIKeyScheme` |
| 29 | WebPagination | 默认分页参数 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaults` |
| 30 | WebPagination | 从查询参数解析 offset 与 limit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesQuery` |
| 31 | WebPagination | 支持 page 与 pageSize 风格 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesPageStyle` |
| 32 | WebPagination | 非法参数回退到默认值而非报错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallsBackOnInvalidInput` |
| 33 | WebPagination | 超出上限的 limit 被截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `clampsLimit` |
| 34 | WebPagination | 分页返回正确切片 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pagesItems` |
| 35 | WebPagination | 偏移越界返回空数组 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `returnsEmptyWhenOutOfRange` |
| 36 | WebPagination | 分页结果携带总数与是否还有下一页 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsPageResult` |
| 37 | WebPagination | 最后一页没有更多数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsNoMorePages` |
| 38 | 请求日志 | 内存日志按最新在前记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordsNewestFirst` |
| 39 | 请求日志 | 超出容量时丢弃最旧记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsOldest` |
| 40 | 请求日志 | 清空后无记录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearsLogs` |
| 41 | WebCORSPolicy | 通配来源允许任意 origin | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allowsAnyOrigin` |
| 42 | WebCORSPolicy | 指定来源时只回显匹配的那个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `echoesMatchingOrigin` |
| 43 | WebCORSPolicy | 缺少 Origin 头时不返回来源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requiresOriginHeader` |
| 44 | WebCORSPolicy | 允许凭据时回显具体来源而非通配 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `echoesConcreteOriginWithCredentials` |
| 45 | WebRouteBuilder | 构建出声明的路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsRoutes` |
| 46 | WebRouteBuilder | 生成的路由 id 稳定且含方法与路径 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `generatesStableIDs` |
| 47 | WebRouteBuilder | 相同声明生成相同 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isDeterministic` |
| 48 | WebRouteBuilder | 空前缀回退到默认名 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackToDefaultPrefix` |
| 49 | WebRouteRequest | 解码 JSON 请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesBody` |
| 50 | Payload | 非法 JSON 抛出统一的 badRequest | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `throwsBadRequestOnInvalidJSON` |
| 51 | Payload | 空请求体抛出 badRequest | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `throwsBadRequestOnEmptyBody` |
| 52 | Payload | 缺少必需路径参数抛出 badRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsBadRequestOnMissingPathParameter` |
| 53 | Payload | 缺少必需查询参数抛出 badRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsBadRequestOnMissingQueryParameter` |
| 54 | Payload | 从查询参数解析分页 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exposesPagination` |
| 55 | WebRouteRegistry | 注册与注销路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersAndUnregisters` |
| 56 | WebRouteRegistry | 同一插件重复注册整体替换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replacesOnSecondRegistration` |
| 57 | WebRouteRegistry | 注册空数组等效于注销 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyRegistrationUnregisters` |
| 58 | WebRouteRegistry | 摘要包含归属插件与方法路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsSummaries` |

> 说明：全部 **58 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 43 / 43
- P2: 已覆盖 8 / 8
- **合计: 58 / 58**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（43 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 58 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderWebServer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
