# TestPlan — ProviderACP

## 包概述

ProviderACP 的实现包，包含 10 个主要类型；当前测试覆盖 40 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 40

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ACPImplementationInfo`
- `ACPError`
- `ACPReadTextFileParams`
- `ACPMessage`
- `ACPVersion`
- `ACPRequestPermissionParams`
- `ACPSessionId`
- `ACPTransport`
- `ContentBlock`
- `JSONValue`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ACPMessage**（8 条）：由 `testDecodeRequest`、`testEncodeRequestRoundTrip`、`testDecodeResponseWithResult` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPMethods**（14 条）：由 `testDecodeInitializeResult`、`testDecodeMinimalAgentCapabilities`、`testDecodeSessionCapabilities` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ACPTypes**（15 条）：由 `testDecodeTextContent`、`testDecodeImageContent`、`testDecodeAudioContent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **JSONValue**（3 条）：由 `testDecodeAllKinds`、`testRoundTrip`、`testStringifyAndDecoded` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ACPMessage | testDecodeRequest | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeRequest` |
| 2 | ACPMessage | testEncodeRequestRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEncodeRequestRoundTrip` |
| 3 | ACPMessage | testDecodeResponseWithResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeResponseWithResult` |
| 4 | ACPMessage | testDecodeNullResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeNullResult` |
| 5 | ACPMessage | testDecodeErrorResponse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeErrorResponse` |
| 6 | ACPMessage | testDecodeNotification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeNotification` |
| 7 | ACPMessage | testRejectNonV2Envelope | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRejectNonV2Envelope` |
| 8 | ACPMessage | testRejectBareMessage | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testRejectBareMessage` |
| 9 | ACPMethods | testDecodeInitializeResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeInitializeResult` |
| 10 | ACPMethods | testDecodeMinimalAgentCapabilities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeMinimalAgentCapabilities` |
| 11 | ACPMethods | testDecodeSessionCapabilities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeSessionCapabilities` |
| 12 | ACPMethods | testDecodeSessionNewParamsWithStdioMCPServer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeSessionNewParamsWithStdioMCPServer` |
| 13 | ACPMethods | testDecodeSessionNewParamsWithHTTPMCPServer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeSessionNewParamsWithHTTPMCPServer` |
| 14 | ACPMethods | testDecodePromptParams | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodePromptParams` |
| 15 | ACPMethods | testEncodePromptResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEncodePromptResult` |
| 16 | ACPMethods | testDecodeCancelNotification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeCancelNotification` |
| 17 | ACPMethods | testDecodeRequestPermission | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeRequestPermission` |
| 18 | ACPMethods | testDecodePermissionResponseSelected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodePermissionResponseSelected` |
| 19 | ACPMethods | testDecodePermissionResponseCancelled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodePermissionResponseCancelled` |
| 20 | ACPMethods | testDecodeReadTextFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeReadTextFile` |
| 21 | ACPMethods | testDecodeWriteTextFile | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeWriteTextFile` |
| 22 | ACPMethods | testEncodeReadTextFileResponse | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEncodeReadTextFileResponse` |
| 23 | ACPTypes | testDecodeTextContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeTextContent` |
| 24 | ACPTypes | testDecodeImageContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeImageContent` |
| 25 | ACPTypes | testDecodeAudioContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeAudioContent` |
| 26 | ACPTypes | testDecodeResourceContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeResourceContent` |
| 27 | ACPTypes | testDecodeResourceLink | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeResourceLink` |
| 28 | ACPTypes | testContentBlockRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContentBlockRoundTrip` |
| 29 | ACPTypes | testDecodePlanUpdate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodePlanUpdate` |
| 30 | ACPTypes | testDecodeToolCall | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeToolCall` |
| 31 | ACPTypes | testDecodeToolCallUpdateWithDiff | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeToolCallUpdateWithDiff` |
| 32 | ACPTypes | testDecodeDiffContent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeDiffContent` |
| 33 | ACPTypes | testToolKindEnums | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToolKindEnums` |
| 34 | ACPTypes | testDecodeCurrentModeUpdate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeCurrentModeUpdate` |
| 35 | ACPTypes | testDecodeUserMessageChunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeUserMessageChunk` |
| 36 | ACPTypes | testSessionUpdateRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionUpdateRoundTrip` |
| 37 | ACPTypes | testStopReasonRawValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStopReasonRawValues` |
| 38 | JSONValue | testDecodeAllKinds | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDecodeAllKinds` |
| 39 | JSONValue | testRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRoundTrip` |
| 40 | JSONValue | testStringifyAndDecoded | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStringifyAndDecoded` |

> 说明：全部 **40 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 38 / 38
- P2: 已覆盖 0 / 0
- **合计: 40 / 40**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（38 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 40 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderACP
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
