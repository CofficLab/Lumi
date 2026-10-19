# TestPlan — KitHttp

## 包概述

KitHttp 可复用的 HTTP 传输工具包。提供 JSON 请求编码、响应校验、类型化传输错误、请求元数据与 SSE 事件分帧，供上层领域服务或宿主应用复用。 `KitHttp` 刻意保持在领域层之下，不包含业务请求构建或响应解析逻辑。

平台: macOS 14+, iOS 17+
测试文件: 10 个，用例总数: 85

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `HTTPClient`
- `HTTPClientError`
- `HTTPRequestMetadata`
- `KitHttpLocalization`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **FDLeakReproduction**（2 条）：由 `repeatedClientCreationDoesNotLeakConnections`、`reusedClientKeepsConnectionCountLow` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTTPClientCoverage**（6 条）：由 `sendJSONRequestEncodesBodyAndParsesResponse`、`streamingCallsOnResponseReceivedOnSuccess`、`streamingCallsOnResponseReceivedOnError` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTTPClientError**（5 条）：由 `jsonSerializationFailed`、`requestFailed`、`decodingFailed` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTTPClientStreaming**（24 条）：由 `streamingCallsOnRequestStart`、`streamingCallsOnEvent`、`streamingStopsOnFalseReturn` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTTPClient**（14 条）：由 `validateResponseSuccess`、`validateResponse201`、`validateResponse299` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTTPRequestMetadata**（11 条）：由 `formatsBytes`、`formatsKilobytes`、`formatsMegabytes` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（3 条）：由 `formatsRequestBodySizes`、`sanitizesSensitiveHeaders`、`masksSensitiveValues` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MockURLProtocol**（20 条）：由 `sendJSONRequestSuccess`、`sendJSONRequestWithResponseSuccess`、`sendJSONRequestWithResponse404` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | FDLeakReproduction | 反复新建 HTTPClient 不应遗留大量连接 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedClientCreationDoesNotLeakConnections` |
| 2 | FDLeakReproduction | 复用同一 HTTPClient 只保留少量连接（对照组） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reusedClientKeepsConnectionCountLow` |
| 3 | HTTPClientCoverage | sendJSONRequest 正确编码并解析响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestEncodesBodyAndParsesResponse` |
| 4 | HTTPClientCoverage | sendStreamingJSONRequest 在 2xx 时回调 onResponseReceived | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCallsOnResponseReceivedOnSuccess` |
| 5 | HTTPClientCoverage | sendStreamingJSONRequest 在非 2xx 时仍回调 onResponseReceived | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCallsOnResponseReceivedOnError` |
| 6 | HTTPClientCoverage | 流式请求自动带上 Accept: text/event-stream | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSetsEventStreamAcceptHeader` |
| 7 | HTTPClientCoverage | sendStreamingRequest 行模式遇网络错误包装为 requestFailed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLineNetworkError` |
| 8 | HTTPClientCoverage | KitHttpLocalization 未命中时回退 key | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationFallbackToKey` |
| 9 | HTTPClientError | jsonSerializationFailed returns correct description | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jsonSerializationFailed` |
| 10 | HTTPClientError | requestFailed returns correct description | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestFailed` |
| 11 | HTTPClientError | decodingFailed returns correct description | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodingFailed` |
| 12 | HTTPClientError | invalidResponse returns correct description | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidResponse` |
| 13 | HTTPClientError | httpError returns correct description with status code and message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpError` |
| 14 | HTTPClientStreaming | sendStreamingJSONRequest calls onRequestStart with metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCallsOnRequestStart` |
| 15 | HTTPClientStreaming | sendStreamingJSONRequest calls onEvent with SSE data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCallsOnEvent` |
| 16 | HTTPClientStreaming | sendStreamingJSONRequest stops when onEvent returns false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingStopsOnFalseReturn` |
| 17 | HTTPClientStreaming | sendStreamingJSONRequest throws httpError for non-2xx response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingThrowsForNon2xx` |
| 18 | HTTPClientStreaming | sendStreamingJSONRequest throws requestFailed for network error | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingThrowsForNetworkError` |
| 19 | HTTPClientStreaming | sendStreamingJSONRequest handles CRLF delimiters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingHandlesCRLF` |
| 20 | HTTPClientStreaming | sendStreamingJSONRequest handles CR-only delimiters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingHandlesCROnlyDelimiters` |
| 21 | HTTPClientStreaming | sendStreamingJSONRequest handles trailing data without delimiter | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingHandlesTrailingData` |
| 22 | HTTPClientStreaming | sendStreamingJSONRequest skips empty events between delimiters | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamingSkipsEmptyEvents` |
| 23 | HTTPClientStreaming | sendStreamingJSONRequest handles multiple events across separate chunks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingMultipleChunks` |
| 24 | HTTPClientStreaming | sendStreamingJSONRequest wraps CancellationError from URLProtocol as requestFailed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCancellationError` |
| 25 | HTTPClientStreaming | sendStreamingRequest onLine receives individual lines including empty lines | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamingLineByLine` |
| 26 | HTTPClientStreaming | sendStreamingRequest onLine preserves UTF-8 text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLineByLinePreservesUTF8Text` |
| 27 | HTTPClientStreaming | sendStreamingRequest onLine accepts CR-only line endings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLineByLineAcceptsCROnlyLineEndings` |
| 28 | HTTPClientStreaming | sendStreamingRequest onLine stops when callback returns false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLineStopsOnFalse` |
| 29 | HTTPClientStreaming | sendStreamingRequest throws httpError for non-2xx (line mode) | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingLineNon2xx` |
| 30 | HTTPClientStreaming | sendStreamingRequest onEvent parses SSE events | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEEvents` |
| 31 | HTTPClientStreaming | sendStreamingRequest onEvent handles multi-line data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEMultiLineData` |
| 32 | HTTPClientStreaming | sendStreamingRequest onEvent preserves UTF-8 data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEPreservesUTF8Data` |
| 33 | HTTPClientStreaming | sendStreamingRequest onEvent accepts CR-only event delimiters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEAcceptsCROnlyEventDelimiters` |
| 34 | HTTPClientStreaming | sendStreamingRequest onEvent handles event id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEEventId` |
| 35 | HTTPClientStreaming | sendStreamingRequest onEvent skips comment lines | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSECommentLines` |
| 36 | HTTPClientStreaming | sendStreamingRequest onEvent stops when callback returns false | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSEStopOnFalse` |
| 37 | HTTPClientStreaming | sendStreamingRequest onEvent handles trailing event without final newline | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingSSETrailingEvent` |
| 38 | HTTPClient | validateResponse succeeds for 2xx status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponseSuccess` |
| 39 | HTTPClient | validateResponse succeeds for 201 status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponse201` |
| 40 | HTTPClient | validateResponse succeeds for 299 status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponse299` |
| 41 | HTTPClient | validateResponse throws invalidResponse for non-HTTPURLResponse | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validateResponseInvalidResponse` |
| 42 | HTTPClient | validateResponse throws httpError for 400 status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponse400` |
| 43 | HTTPClient | validateResponse throws httpError for 500 status | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponse500` |
| 44 | HTTPClient | validateResponse error message is raw response body | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validateResponseErrorMessageFormat` |
| 45 | HTTPClient | validateResponse handles non-UTF8 error body gracefully | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `validateResponseNonUTF8Body` |
| 46 | HTTPClient | sanitizeHeaders masks authorization headers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sanitizeHeadersMasksAuthorization` |
| 47 | HTTPClient | sanitizeHeaders returns empty for empty input | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sanitizeHeadersEmpty` |
| 48 | HTTPClient | maskSensitiveValue masks long sensitive values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maskSensitiveLongValue` |
| 49 | HTTPClient | maskSensitiveValue masks short sensitive values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maskSensitiveShortValue` |
| 50 | HTTPClient | maskSensitiveValue returns plain value for non-sensitive keys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `maskSensitiveNonSensitive` |
| 51 | HTTPClient | init accepts custom configuration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initCustomConfiguration` |
| 52 | HTTPRequestMetadata | formats bytes when size < 1 KB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsBytes` |
| 53 | HTTPRequestMetadata | formats KB when size >= 1 KB and < 1 MB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsKilobytes` |
| 54 | HTTPRequestMetadata | formats MB when size >= 1 MB and < 1 GB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsMegabytes` |
| 55 | HTTPRequestMetadata | formats GB when size >= 1 GB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsGigabytes` |
| 56 | HTTPRequestMetadata | formats zero bytes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsZeroBytes` |
| 57 | HTTPRequestMetadata | isSuccess is true when no error | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isSuccessTrue` |
| 58 | HTTPRequestMetadata | formattedResponseBodySize is placeholder when response size is nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `responseSizeNil` |
| 59 | HTTPRequestMetadata | formats response bytes when size < 1 KB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseBytes` |
| 60 | HTTPRequestMetadata | formats response KB / MB / GB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseUnits` |
| 61 | HTTPRequestMetadata | isSuccess is false when error is set | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isSuccessFalse` |
| 62 | HTTPRequestMetadata | initializer sets all properties correctly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initializerSetsProperties` |
| 63 | 综合 | formats request body sizes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsRequestBodySizes` |
| 64 | 综合 | sanitizes sensitive headers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sanitizesSensitiveHeaders` |
| 65 | 综合 | masks sensitive values | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `masksSensitiveValues` |
| 66 | MockURLProtocol | sendJSONRequest returns data for successful response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestSuccess` |
| 67 | MockURLProtocol | sendJSONRequestWithResponse returns data and response for 200 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponseSuccess` |
| 68 | MockURLProtocol | sendJSONRequestWithResponse throws httpError for 404 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponse404` |
| 69 | MockURLProtocol | sendJSONRequestWithResponse throws httpError for 500 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponse500` |
| 70 | MockURLProtocol | sendJSONRequestWithResponse rethrows HTTPClientError from validateResponse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponseRethrowsHTTPClientError` |
| 71 | MockURLProtocol | sendJSONRequestWithResponse throws requestFailed for network error | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponseNetworkError` |
| 72 | MockURLProtocol | sendJSONRequest wraps CancellationError from URLProtocol as requestFailed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestCancellation` |
| 73 | MockURLProtocol | sendJSONRequestWithResponse wraps CancellationError from URLProtocol as requestFailed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONRequestWithResponseCancellation` |
| 74 | MockURLProtocol | sendRequest returns data for successful GET | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendRequestSuccess` |
| 75 | MockURLProtocol | sendRequestWithResponse returns data and HTTPURLResponse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendRequestWithResponseSuccess` |
| 76 | MockURLProtocol | sendRequest throws httpError for 404 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendRequest404` |
| 77 | MockURLProtocol | sendRequest throws requestFailed for network error | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendRequestNetworkError` |
| 78 | MockURLProtocol | sendEncodableRequest encodes body and returns data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendEncodableSuccess` |
| 79 | MockURLProtocol | sendEncodableRequestWithResponse returns response metadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendEncodableWithResponse` |
| 80 | MockURLProtocol | sendDecodableRequest decodes GET response into typed object | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendDecodableSuccess` |
| 81 | MockURLProtocol | sendDecodableRequest throws decodingFailed for invalid JSON | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sendDecodableFailure` |
| 82 | MockURLProtocol | sendJSONDecodableRequest sends JSON body and decodes response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendJSONDecodableSuccess` |
| 83 | MockURLProtocol | sendEncodableDecodableRequest encodes body and decodes response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendEncodableDecodableSuccess` |
| 84 | MockURLProtocol | sendDataRequestWithResponse sends raw body and returns response | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendDataSuccess` |
| 85 | MockURLProtocol | sendDataRequestWithResponse throws httpError for 500 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendDataError` |

> 说明：全部 **85 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 76 / 76
- P2: 已覆盖 4 / 4
- **合计: 85 / 85**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（76 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 85 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitHttp
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
