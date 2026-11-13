# TestPlan — KitLLM

## 包概述

KitLLM 的实现包，包含 14 个主要类型；当前测试覆盖 319 条用例。

平台: macOS 14+, iOS 17+
测试文件: 29 个，用例总数: 319

核心组件（源码目录）:
- `Adapters/`
- `Base/`
- `Contracts/`
- `Core/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AnthropicCompatibleProviderAdapter`
- `AnthropicCompatibleProviderConfiguration`
- `AnthropicCompatibleProviderError`
- `AnthropicCompatibleErrorResponse`
- `LLMModelCapabilities`
- `HTTPRetryAfter`
- `LLMConfig`
- `OpenAICompatibleGenerationOptionsApplier`
- `LLMServiceError`
- `LLMToolNameSanitizer`
- `LLMToolSchemaProviding`
- `MessageImage`
- `NormalizedSchemaProviding`
- `OpenAICompatibleProviderAdapter`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **APIKeyMemoryCache**（5 条）：由 `freshWithinTTL`、`negativeEntry`、`lastKnownIgnoresTTL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicAdapter**（54 条）：由 `buildsRequestHeaders`、`buildsRequestBody`、`systemMessagesOverridePrompt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicToolUseNullArguments**（4 条）：由 `topLevelNullStaysNull`、`nestedNullStaysNull`、`arrayNullStaysNull` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicUnpairedToolCallRepair**（3 条）：由 `unpairedToolUseIsRepairedWhenFollowedByUserMessage`、`completedToolUseIsNotDuplicated`、`trailingAssistantIsStillRepaired` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicWholeJSONFallbackMetadata**（5 条）：由 `fallbackCarriesTokenUsage`、`fallbackCarriesCacheUsage`、`fallbackCarriesResponseIDAndStopReason` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicWholeJSONFallbackRedactedThinking**（7 条）：由 `fallbackPreservesSingleRedactedBlock`、`fallbackPreservesMultipleRedactedBlocks`、`fallbackProducesRedactedThinkingInFinalResponse` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ImageBase64Cache**（10 条）：由 `cachedResultMatchesDirectEncoding`、`distinctInstancesWithSameContentReuseEntry`、`differentContentDoesNotCollide` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（46 条）：由 `messageCreation`、`requestCreation`、`providerInfo` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAIChatCompletionsResponseMetadata**（5 条）：由 `nonStreamingKeepsResponseID`、`nonStreamingKeepsStopReason`、`missingMetadataStaysNil` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAICompatibleStreamParsing**（9 条）：由 `reasoningAndToolCallsCoexist`、`contentAndToolCallsCoexist`、`usageSurvivesToolCallFrame` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAIRefusalParsing**（6 条）：由 `nonStreamingRefusalIsPreserved`、`nonStreamingPrefersContentOverRefusal`、`nonStreamingContentUnaffected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAIStreamParallelToolCall**（3 条）：由 `parallelToolCallsInOneDeltaAreAccumulatedSeparately`、`parallelToolCallArgumentsStreamByIndexAcrossDeltas`、`gatewayWithoutIndexStillAssignsDistinctSlotsAcrossDeltas` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAIStreamToolCallIdentity**（4 条）：由 `identitySplitAcrossDeltasIsMerged`、`nameFirstThenArgumentsIsMerged`、`identityInSameDeltaStillWorks` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAIUnpairedToolCallRepair**（3 条）：由 `unpairedToolCallIsRemovedFromRequest`、`fullyPairedToolCallsAreKept`、`completedToolResultIsStillSent` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenRouterImageResponse**（5 条）：由 `nonStreamingImagesAreDecoded`、`nonStreamingImageMimeTypeParsed`、`nonDataURLImagesAreSkipped` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenRouterReasoningField**（5 条）：由 `nonStreamingReasoningIsPreserved`、`reasoningContentStillWorks`、`streamingReasoningProducesThinkingDelta` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderErrorAndContract**（45 条）：由 `parsesOpenAIErrorBody`、`parsesAnthropicErrorBody`、`fallsBackToGenericJSON` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ReasoningOffRequest**（6 条）：由 `offDegradesToLowestEffort`、`offDisablesThinkingParameter`、`offOnUndisableableModelSendsNothing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RequestBodyBuilder**（8 条）：由 `openAIStreamingBodyBuildsOffMainThread`、`openAIBodyBuildsOffMainThread`、`anthropicBodyBuildsOffMainThread` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResponsesFailedStatus**（3 条）：由 `failedStatusThrowsProviderError`、`failedStatusWithPartialTextIsNotSuccess`、`completedStatusReturnsNormally` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResponsesRefusalBlock**（3 条）：由 `refusalTextIsPreserved`、`refusalAndTextCoexist`、`regularTextUnaffected` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResponsesResponseID**（2 条）：由 `responsesKeepsResponseID`、`missingResponseIDStaysNil` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RetryAfterAndBackoff**（21 条）：由 `parsesDelaySeconds`、`headerLookupIsCaseInsensitive`、`parsesHTTPDate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ThinkingDeltaChunk**（2 条）：由 `thinkingDeltaChunkDoesNotCarryContent`、`textDeltaChunkDoesNotCarryReasoning` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolCallArgumentsParser**（16 条）：由 `parsesValidJSONObject`、`rejectsInvalidJSON`、`rejectsNonObjectJSON` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorAPIService**（9 条）：由 `retriesOnServerError`、`givesUpAfterMaxAttempts`、`doesNotRetryOnClientError` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorLLMProvider**（1 条）：由 `staticProviderBehavior` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorProvider**（19 条）：由 `openAICompletionParsesResponse`、`fallsBackToDefaultModel`、`toolNamesAreSanitizedAndRestored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VisionMessageContentBuilderCache**（10 条）：由 `anthropicBlocksMatchDirectEncoding`、`anthropicBlocksAreStableAcrossCalls`、`anthropicBlocksWithoutImages` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | APIKeyMemoryCache | TTL 内命中，过期后视为未命中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freshWithinTTL` |
| 2 | APIKeyMemoryCache | 负缓存条目区分「确认不存在」与「未命中」 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `negativeEntry` |
| 3 | APIKeyMemoryCache | lastKnownEntry 不校验新鲜度，供 stale-if-error 回退 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lastKnownIgnoresTTL` |
| 4 | APIKeyMemoryCache | remove 立即清空条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeClears` |
| 5 | APIKeyMemoryCache | remember 覆盖同 key 的旧条目（含负缓存） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rememberOverwrites` |
| 6 | AnthropicAdapter | HTTP 请求带认证头与协议版本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsRequestHeaders` |
| 7 | AnthropicAdapter | 请求体包含模型、最大输出与 system 兜底 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsRequestBody` |
| 8 | AnthropicAdapter | 多条 system 消息优先于 systemPrompt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `systemMessagesOverridePrompt` |
| 9 | AnthropicAdapter | 只含空格的 system 消息不会被过滤掉 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `whitespaceOnlySystemMessageIsKept` |
| 10 | AnthropicAdapter | 工具定义使用转义后的名字与 input_schema | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsTools` |
| 11 | AnthropicAdapter | 非法工具参数在构建请求体时就被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidToolArguments` |
| 12 | AnthropicAdapter | 流式请求体带 stream 标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsStreamingBody` |
| 13 | AnthropicAdapter | 带 config 的流式请求体套用生成参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesGenerationOptions` |
| 14 | AnthropicAdapter | 推理档位映射成 thinking 预算并抬高 max_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesThinkingBudget` |
| 15 | AnthropicAdapter | 不支持 extended thinking 的 Claude 模型省略 thinking 且不抬高 max_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omitsThinkingForUnsupportedClaudeModels` |
| 16 | AnthropicAdapter | Claude 3.7 与 4 及非 Claude 兼容模型仍保留 thinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsThinkingForSupportedModels` |
| 17 | AnthropicAdapter | 输出上限 4096 的 Claude 3 模型默认 max_tokens 被限幅 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `clampsDefaultMaxTokensForClaude3Models` |
| 18 | AnthropicAdapter | 用户显式超过模型上限的 max_tokens 同样被限幅 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clampsExplicitMaxTokensAboveModelCap` |
| 19 | AnthropicAdapter | 输出上限更高的模型不会被统一降低 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsHigherMaxTokensForCapableModels` |
| 20 | AnthropicAdapter | 开启缓存时最后一条文本块带缓存边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsPromptCacheBoundary` |
| 21 | AnthropicAdapter | 关闭缓存时不写缓存边界 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `omitsPromptCacheBoundaryByDefault` |
| 22 | AnthropicAdapter | 文本内容被拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextContent` |
| 23 | AnthropicAdapter | 工具调用被解析成结构化参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesToolUseBlock` |
| 24 | AnthropicAdapter | 工具名按反查映射还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresToolNameFromReverseMap` |
| 25 | AnthropicAdapter | 错误响应体被转成 apiError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsAPIError` |
| 26 | AnthropicAdapter | message_start 事件带输入 token 与消息 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageStart` |
| 27 | AnthropicAdapter | message_delta 事件带输出 token 与结束原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageDelta` |
| 28 | AnthropicAdapter | message_stop 事件标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageStop` |
| 29 | AnthropicAdapter | 文本内容块开始事件带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextContentBlockStart` |
| 30 | AnthropicAdapter | 工具内容块开始事件带工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesToolContentBlockStart` |
| 31 | AnthropicAdapter | 思考内容块开始事件不带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesThinkingContentBlockStart` |
| 32 | AnthropicAdapter | redacted_thinking 内容块开始事件带 opaque data | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesRedactedThinkingContentBlockStart` |
| 33 | AnthropicAdapter | 文本增量事件带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextDelta` |
| 34 | AnthropicAdapter | 思考增量事件被标记为 thinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesThinkingDelta` |
| 35 | AnthropicAdapter | 工具参数增量事件带 partial_json | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesInputJSONDelta` |
| 36 | AnthropicAdapter | 签名增量事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesSignatureDelta` |
| 37 | AnthropicAdapter | 内容块停止事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesContentBlockStop` |
| 38 | AnthropicAdapter | ping 事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesPing` |
| 39 | AnthropicAdapter | 错误事件带错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesErrorEvent` |
| 40 | AnthropicAdapter | [DONE] 标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesDoneMarker` |
| 41 | AnthropicAdapter | 没有 data 行的块被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresBlockWithoutData` |
| 42 | AnthropicAdapter | 网关返回整段 JSON 时按整体响应解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesWholeJSONBody` |
| 43 | AnthropicAdapter | 普通文本消息原样转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsPlainText` |
| 44 | AnthropicAdapter | 工具结果消息转成 tool_result 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsToolResult` |
| 45 | AnthropicAdapter | 回归 #955：失败工具结果携带 is_error，成功结果不带 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolResultCarriesErrorFlagOnlyOnFailure` |
| 46 | AnthropicAdapter | 带工具调用的 assistant 消息转成 tool_use 块且名字被转义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsAssistantToolCalls` |
| 47 | AnthropicAdapter | redacted thinking 在工具调用消息里按原样回传且位于 tool_use 之前 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsRedactedThinkingBeforeToolUse` |
| 48 | AnthropicAdapter | 带思考内容的 assistant 消息生成 thinking 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsReasoningContent` |
| 49 | AnthropicAdapter | 带图片的消息转成 base64 图片块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsImages` |
| 50 | AnthropicAdapter | 工具定义被转成 Anthropic 形态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsToolSchema` |
| 51 | AnthropicAdapter | 官方语义下总输入就是 input_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `officialSemanticsUseInputTokens` |
| 52 | AnthropicAdapter | 兼容层语义下总输入是三段之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compatibleSemanticsSumAllParts` |
| 53 | AnthropicAdapter | 缺少 input_tokens 时退回到缓存字段之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToCacheFields` |
| 54 | AnthropicAdapter | 完全没有任何计数时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutAnyCount` |
| 55 | AnthropicAdapter | 缓存读取字段兼容多种命名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsCacheReadTokens` |
| 56 | AnthropicAdapter | 缓存写入字段兼容多种命名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsCacheWriteTokens` |
| 57 | AnthropicAdapter | 5xx 可重试，4xx 不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `classifiesStatusCodes` |
| 58 | AnthropicAdapter | 尝试次数用尽后不再重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopsAfterMaxAttempts` |
| 59 | AnthropicAdapter | 取消类错误不重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryCancelled` |
| 60 | AnthropicToolUseNullArguments | 顶层 null 参数保持为 JSON null | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `topLevelNullStaysNull` |
| 61 | AnthropicToolUseNullArguments | 嵌套字典里的 null 保持为 JSON null | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedNullStaysNull` |
| 62 | AnthropicToolUseNullArguments | 数组里的 null 保持为 JSON null | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `arrayNullStaysNull` |
| 63 | AnthropicToolUseNullArguments | 非空值不受影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `regularValuesUnchanged` |
| 64 | AnthropicUnpairedToolCallRepair | assistant 之后还有 user 消息时，未配对的调用被补上错误结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unpairedToolUseIsRepairedWhenFollowedByUserMessage` |
| 65 | AnthropicUnpairedToolCallRepair | 已完成的调用不被重复补结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `completedToolUseIsNotDuplicated` |
| 66 | AnthropicUnpairedToolCallRepair | assistant 是最后一条消息时仍然修复 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trailingAssistantIsStillRepaired` |
| 67 | AnthropicWholeJSONFallbackMetadata | 整段 JSON 回退带上 token 用量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackCarriesTokenUsage` |
| 68 | AnthropicWholeJSONFallbackMetadata | 整段 JSON 回退带上缓存用量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackCarriesCacheUsage` |
| 69 | AnthropicWholeJSONFallbackMetadata | 整段 JSON 回退带上响应 ID 与停止原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackCarriesResponseIDAndStopReason` |
| 70 | AnthropicWholeJSONFallbackMetadata | 整段 JSON 回退仍保留正文与结束标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackStillCarriesContent` |
| 71 | AnthropicWholeJSONFallbackMetadata | SSE 事件与整段 JSON 回退的元数据一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sseAndFallbackAgreeOnMetadata` |
| 72 | AnthropicWholeJSONFallbackRedactedThinking | 整段 JSON 回退保留单个 redacted_thinking 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackPreservesSingleRedactedBlock` |
| 73 | AnthropicWholeJSONFallbackRedactedThinking | 整段 JSON 回退保留多个 redacted_thinking 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackPreservesMultipleRedactedBlocks` |
| 74 | AnthropicWholeJSONFallbackRedactedThinking | 整段 JSON 回退经累积器后最终响应含 redactedThinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackProducesRedactedThinkingInFinalResponse` |
| 75 | AnthropicWholeJSONFallbackRedactedThinking | 整段 JSON 与等价 SSE 的最终 redactedThinking 一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackAndSSEAgreeOnRedactedThinking` |
| 76 | AnthropicWholeJSONFallbackRedactedThinking | 仅含 redacted_thinking 的整段 JSON 仍产生 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `redactedOnlyResponseStillProducesChunk` |
| 77 | AnthropicWholeJSONFallbackRedactedThinking | 非流式 parseResponse 同样返回 redactedThinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parseResponseReturnsRedactedThinking` |
| 78 | AnthropicWholeJSONFallbackRedactedThinking | 无 redacted_thinking 时字段为空，不引入额外块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noRedactedBlocksWhenAbsent` |
| 79 | ImageBase64Cache | 缓存命中返回与直接编码完全一致的 Base64 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedResultMatchesDirectEncoding` |
| 80 | ImageBase64Cache | 内容相同的不同 Data 实例命中同一条缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `distinctInstancesWithSameContentReuseEntry` |
| 81 | ImageBase64Cache | 不同内容的图片不会互相污染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentContentDoesNotCollide` |
| 82 | ImageBase64Cache | 空图片直接编码且不占用缓存条目 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDataIsEncodedDirectly` |
| 83 | ImageBase64Cache | 单字节与极小图片同样得到正确结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tinyDataProducesCorrectEncoding` |
| 84 | ImageBase64Cache | 条目数超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenEntryLimitExceeded` |
| 85 | ImageBase64Cache | 累计字符数超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenCharacterLimitExceeded` |
| 86 | ImageBase64Cache | 淘汰后缓存仍然返回正确结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `evictedEntriesStillEncodeCorrectly` |
| 87 | ImageBase64Cache | 清空缓存后统计归零 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeAllResetsStatistics` |
| 88 | ImageBase64Cache | 重复编码同一张图片的耗时显著低于首次编码 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedEncodingIsCheaperThanFirstEncoding` |
| 89 | 综合 | LLMMessage 构造和字段访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageCreation` |
| 90 | 综合 | LLMRequest 构造 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestCreation` |
| 91 | 综合 | LLMProviderInfo 元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerInfo` |
| 92 | 综合 | 本地供应商自动推导类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localProviderTypeIsInferred` |
| 93 | 综合 | 供应商类型支持中转站 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relayProviderTypeCanBeDeclared` |
| 94 | 综合 | 基础档位对所有 OpenAI 兼容供应商都透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsBaseReasoningEffort` |
| 95 | 综合 | 未声明的额外档位不下发，避免上游返回 400 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterDropsUndeclaredReasoningEffort` |
| 96 | 综合 | 供应商声明的额外档位正常下发（MiniMax 支持 xhigh / max） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsDeclaredExtraReasoningEffort` |
| 97 | 综合 | 非推理模型不下发 reasoning_effort，避免 400（回归 #985） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterDropsReasoningEffortForNonReasoningModels` |
| 98 | 综合 | 推理模型仍正常下发 reasoning_effort | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsReasoningEffortForReasoningModels` |
| 99 | 综合 | 档位归一化忽略大小写与空白，并拒绝 auto | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `reasoningEffortNormalization` |
| 100 | 综合 | 额外档位声明在构造时归一化为小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `additionalReasoningEffortsAreNormalized` |
| 101 | 综合 | VendorAPIError 错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 102 | 综合 | LLMToolNameSanitizer 转义规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNameSanitizer` |
| 103 | 综合 | redacted thinking 块按到达顺序进入最终响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `redactedThinkingIsKeptInResponse` |
| 104 | 综合 | 超长工具名截断到 64 字符且稳定不撞名 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `longToolNameIsTruncatedToProtocolLimit` |
| 105 | 综合 | OpenAI adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterBuildsBody` |
| 106 | 综合 | OpenAI adapter 拒绝非法工具参数，避免把坏历史发送给供应商 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `openAIAdapterRejectsInvalidToolArguments` |
| 107 | 综合 | LLM 响应在落库前拒绝非法工具参数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `responseRejectsInvalidToolArguments` |
| 108 | 综合 | OpenAI 兼容流式解析器兼容 input/output token 字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesUsageAliases` |
| 109 | 综合 | OpenAI 兼容流式解析器识别 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesFinishReason` |
| 110 | 综合 | DeepSeek 最终结束块保留 usage 和缓存命中字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDeepSeekFinalUsageChunk` |
| 111 | 综合 | 同一 delta 同时含思考与正文时两者都保留，不丢弃正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWhenInterleavedWithReasoning` |
| 112 | 综合 | interleaved thinking 累积后正文非空，思考与正文各自完整 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterAccumulatorPreservesInterleavedContent` |
| 113 | 综合 | 仅思考无正文时仍产出思考事件，且不伪造正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterEmitsThinkingOnlyChunk` |
| 114 | 综合 | 正文与工具调用同 delta 时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsTextAndToolCallsInSameDelta` |
| 115 | 综合 | 带正文与 finish_reason 的 delta 同时保留正文与结束信号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWithFinishReason` |
| 116 | 综合 | 无任何增量的空 delta 不产出 chunk | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterSkipsEmptyDelta` |
| 117 | 综合 | 返回空 chunk 的网关配置保持既有行为 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterKeepsEmptyChunkFallback` |
| 118 | 综合 | 工具调用事件仍产出可累积的 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterStillParsesToolCallDeltas` |
| 119 | 综合 | [DONE] 事件产出终止 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDoneMarker` |
| 120 | 综合 | OpenAI 兼容请求过滤授权占位并去重旧工具结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterRepairsDuplicateToolResults` |
| 121 | 综合 | OpenAI 兼容请求不会把工具图片放进 assistant 内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterMovesToolImagesToSyntheticUserMessage` |
| 122 | 综合 | OpenAI 兼容请求将迟到的交互工具结果移到 assistant 后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRepairsOutOfOrderToolResult` |
| 123 | 综合 | OpenAI 兼容请求移除无结果的孤立工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRemovesOrphanToolCalls` |
| 124 | 综合 | 未收到流式终止信号时拒绝不完整响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `incompleteStreamingResponseFails` |
| 125 | 综合 | Anthropic adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterBuildsBody` |
| 126 | 综合 | Anthropic 缓存配置在最后文本块添加显式边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterAddsPromptCacheBoundaryWhenEnabled` |
| 127 | 综合 | Anthropic usage 兼容阿里云缓存读取和创建字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterParsesCacheUsage` |
| 128 | 综合 | VendorAPIKeyTools set/get/remove | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyTools` |
| 129 | 综合 | 测试进程忘记隔离 service 时重定向，不写生产 Keychain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProcessRedirectsProductionService` |
| 130 | 综合 | 完整 Keychain 查询遇到一次 not-found 后会重试并恢复 Key | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `apiKeyReadRetriesCompleteMissingLookup` |
| 131 | 综合 | 连续完整查询均 not-found 后才认定 API Key 缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyReadConfirmsMissingAcrossRetries` |
| 132 | 综合 | 网络中断可重试但认证失败不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryPolicyClassifiesTransientErrors` |
| 133 | 综合 | 流式计时器记录首个输出和流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingRecorder` |
| 134 | 综合 | 没有输出时不伪造流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingWithoutOutput` |
| 135 | OpenAIChatCompletionsResponseMetadata | 非流式响应保留顶层 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingKeepsResponseID` |
| 136 | OpenAIChatCompletionsResponseMetadata | 非流式响应保留 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingKeepsStopReason` |
| 137 | OpenAIChatCompletionsResponseMetadata | 没有 id 与 finish_reason 时保持 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingMetadataStaysNil` |
| 138 | OpenAIChatCompletionsResponseMetadata | 流式响应保留顶层 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingKeepsResponseID` |
| 139 | OpenAIChatCompletionsResponseMetadata | 流式响应保留 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingKeepsStopReason` |
| 140 | OpenAICompatibleStreamParsing | 同一 delta 内 reasoning_content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningAndToolCallsCoexist` |
| 141 | OpenAICompatibleStreamParsing | 同一 delta 内 content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentAndToolCallsCoexist` |
| 142 | OpenAICompatibleStreamParsing | 带 tool_calls 的末帧仍透传 usage 与 stop_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageSurvivesToolCallFrame` |
| 143 | OpenAICompatibleStreamParsing | 纯 finish_reason 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pureStopReasonFrame` |
| 144 | OpenAICompatibleStreamParsing | usage-only 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageOnlyFrame` |
| 145 | OpenAICompatibleStreamParsing | [DONE] 事件标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doneEvent` |
| 146 | OpenAICompatibleStreamParsing | DeepSeek 形态的总输入就是 prompt_tokens，不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deepSeekCacheTotalIsPromptTokens` |
| 147 | OpenAICompatibleStreamParsing | OpenAI 形态的总量不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAICacheTotalIsPromptTokens` |
| 148 | OpenAICompatibleStreamParsing | 思考增量与正文增量携带相同的总输入口径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinkingAndTextChunksShareCacheTotal` |
| 149 | OpenAIRefusalParsing | 非流式的 message.refusal 被保留为正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingRefusalIsPreserved` |
| 150 | OpenAIRefusalParsing | 非流式同时有正文与拒答时优先保留正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingPrefersContentOverRefusal` |
| 151 | OpenAIRefusalParsing | 非流式有正文时不受拒答字段影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingContentUnaffected` |
| 152 | OpenAIRefusalParsing | 流式的 delta.refusal 被产出为正文增量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRefusalProducesTextDelta` |
| 153 | OpenAIRefusalParsing | 流式拒答与正文并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRefusalAndContentCoexist` |
| 154 | OpenAIRefusalParsing | 流式拒答帧仍透传 usage 与 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingRefusalKeepsUsage` |
| 155 | OpenAIStreamParallelToolCall | 同一 delta 内的两个并行调用累积成两个独立调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parallelToolCallsInOneDeltaAreAccumulatedSeparately` |
| 156 | OpenAIStreamParallelToolCall | 并行调用的 arguments 分片跨 delta 按 index 各自拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parallelToolCallArgumentsStreamByIndexAcrossDeltas` |
| 157 | OpenAIStreamParallelToolCall | 不带 index 的网关跨 delta 仍逐个分配独立槽位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gatewayWithoutIndexStillAssignsDistinctSlotsAcrossDeltas` |
| 158 | OpenAIStreamToolCallIdentity | id 与 name 分到不同 delta 时能合并成完整的调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `identitySplitAcrossDeltasIsMerged` |
| 159 | OpenAIStreamToolCallIdentity | name 先到、arguments 后到时也能合并 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nameFirstThenArgumentsIsMerged` |
| 160 | OpenAIStreamToolCallIdentity | id 与 name 在同一个 delta 时行为不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `identityInSameDeltaStillWorks` |
| 161 | OpenAIStreamToolCallIdentity | 没有工具调用时不产出调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noToolCallsProducesNothing` |
| 162 | OpenAIUnpairedToolCallRepair | 未配对的 tool_call 被移出请求，已完成的保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unpairedToolCallIsRemovedFromRequest` |
| 163 | OpenAIUnpairedToolCallRepair | 全部配对时 tool_calls 完整保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullyPairedToolCallsAreKept` |
| 164 | OpenAIUnpairedToolCallRepair | 已完成的 tool 结果仍然发送 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedToolResultIsStillSent` |
| 165 | OpenRouterImageResponse | 非流式的 message.images 被解码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingImagesAreDecoded` |
| 166 | OpenRouterImageResponse | 非流式的图片 mime 类型从 data URL 解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingImageMimeTypeParsed` |
| 167 | OpenRouterImageResponse | 非 data URL 的图片被跳过而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nonDataURLImagesAreSkipped` |
| 168 | OpenRouterImageResponse | 没有图片时图片列表为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noImagesYieldsEmptyList` |
| 169 | OpenRouterImageResponse | 流式的 delta.images 产出图片 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingImagesProduceChunk` |
| 170 | OpenRouterReasoningField | 非流式的 message.reasoning 被保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonStreamingReasoningIsPreserved` |
| 171 | OpenRouterReasoningField | reasoning_content 仍然被支持 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningContentStillWorks` |
| 172 | OpenRouterReasoningField | 流式的 delta.reasoning 产出思考增量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingReasoningProducesThinkingDelta` |
| 173 | OpenRouterReasoningField | 流式的 reasoning 与 reasoning_content 都能被识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingReasoningContentStillWorks` |
| 174 | OpenRouterReasoningField | 流式的 reasoning 与正文并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingReasoningAndContentCoexist` |
| 175 | ProviderErrorAndContract | OpenAI 形态的错误体解析出 message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesOpenAIErrorBody` |
| 176 | ProviderErrorAndContract | Anthropic 形态的错误体解析出 message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesAnthropicErrorBody` |
| 177 | ProviderErrorAndContract | 未知形态回落到通用 JSON 解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToGenericJSON` |
| 178 | ProviderErrorAndContract | 通用 JSON 优先取 error.message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `genericJSONPrefersNestedErrorMessage` |
| 179 | ProviderErrorAndContract | 没有可识别字段时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForUnrecognisedBody` |
| 180 | ProviderErrorAndContract | 非 JSON 与空响应返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForNonJSONBody` |
| 181 | ProviderErrorAndContract | 仅 429 与 5xx 被视为可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableStatusCodes` |
| 182 | ProviderErrorAndContract | 优先读取实现 LLMHTTPErrorProviding 的错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersHTTPErrorProtocol` |
| 183 | ProviderErrorAndContract | 回落到 NSError userInfo 中的 statusCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToNSErrorUserInfo` |
| 184 | ProviderErrorAndContract | 没有状态码时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutStatusCode` |
| 185 | ProviderErrorAndContract | 配置类错误不可重试，请求失败可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryabilityClassification` |
| 186 | ProviderErrorAndContract | 错误描述覆盖全部用例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 187 | ProviderErrorAndContract | 错误描述覆盖全部用例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 188 | ProviderErrorAndContract | HTTP 错误便捷构造不带退避建议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpStatusConvenienceOverload` |
| 189 | ProviderErrorAndContract | 缺失与读取失败两类错误带专属渲染类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderKindClassification` |
| 190 | ProviderErrorAndContract | 原始错误详情只在两类 Key 错误上提供 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rawErrorDetail` |
| 191 | ProviderErrorAndContract | Anthropic 适配器错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicErrorDescriptions` |
| 192 | ProviderErrorAndContract | OpenAI 适配器错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIErrorDescriptions` |
| 193 | ProviderErrorAndContract | 合法配置通过校验 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsValidConfig` |
| 194 | ProviderErrorAndContract | 缺省温度与 token 上限视为合法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsNilOptionals` |
| 195 | ProviderErrorAndContract | 模型名为空被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyModel` |
| 196 | ProviderErrorAndContract | 供应商 ID 为空被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyProviderID` |
| 197 | ProviderErrorAndContract | 温度超出 0...2 被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOutOfRangeTemperature` |
| 198 | ProviderErrorAndContract | 非正的最大 token 数被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsNonPositiveMaxTokens` |
| 199 | ProviderErrorAndContract | 默认配置指向 Anthropic | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultConfigTargetsAnthropic` |
| 200 | ProviderErrorAndContract | provider 与 model 都非空才可构造 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyComponents` |
| 201 | ProviderErrorAndContract | 原始值带固定前缀并可逆解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rawValueRoundTrips` |
| 202 | ProviderErrorAndContract | 分隔符等特殊字符被百分号编码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesSpecialCharacters` |
| 203 | ProviderErrorAndContract | 非法原始值返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidRawValues` |
| 204 | ProviderErrorAndContract | 可编码解码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTrip` |
| 205 | ProviderErrorAndContract | 非法值解码抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decodingRejectsInvalidRawValue` |
| 206 | ProviderErrorAndContract | 模型 id 列表与包含判定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelIDHelpers` |
| 207 | ProviderErrorAndContract | 供应商类型按是否本地推导 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerTypeIsInferred` |
| 208 | ProviderErrorAndContract | 显式声明的供应商类型优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitProviderTypeWins` |
| 209 | ProviderErrorAndContract | 缺省协议为 OpenAI 兼容 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultAPIFormatIsOpenAI` |
| 210 | ProviderErrorAndContract | 供应商类型的展示名与图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerTypePresentation` |
| 211 | ProviderErrorAndContract | 模型元数据的缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `modelInfoDefaults` |
| 212 | ProviderErrorAndContract | 退役标记可显式设置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelInfoRetiredFlag` |
| 213 | ProviderErrorAndContract | 进度缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `progressDefaults` |
| 214 | ProviderErrorAndContract | 状态缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stateDefaults` |
| 215 | ProviderErrorAndContract | 失败状态携带原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedStatusCarriesReason` |
| 216 | ProviderErrorAndContract | 映射建立 sanitize 名到原始名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsReverseMap` |
| 217 | ProviderErrorAndContract | 同名冲突时先注册者优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRegistrationWins` |
| 218 | ProviderErrorAndContract | 首字符非字母时补 tool_ 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsToolPrefixWhenFirstCharacterIsNotLetter` |
| 219 | ProviderErrorAndContract | 空列表得到空映射 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyToolListYieldsEmptyMap` |
| 220 | ReasoningOffRequest | 关闭思考在强制思考的模型上降为最低档位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offDegradesToLowestEffort` |
| 221 | ReasoningOffRequest | 关闭思考在支持关闭的模型上下发关闭参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offDisablesThinkingParameter` |
| 222 | ReasoningOffRequest | 关不掉思考的模型不下发任何推理参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offOnUndisableableModelSendsNothing` |
| 223 | ReasoningOffRequest | 模型未声明能力时关闭不下发参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `offWithoutCapabilitySendsNothing` |
| 224 | ReasoningOffRequest | 档位超出模型声明范围时不下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `effortOutsideDeclaredRangeIsDropped` |
| 225 | ReasoningOffRequest | 模型声明支持的额外档位仍可下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `extraEffortIsForwarded` |
| 226 | RequestBodyBuilder | OpenAI 流式请求体不在主线程上构建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIStreamingBodyBuildsOffMainThread` |
| 227 | RequestBodyBuilder | OpenAI 非流式请求体不在主线程上构建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIBodyBuildsOffMainThread` |
| 228 | RequestBodyBuilder | Anthropic 请求体不在主线程上构建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicBodyBuildsOffMainThread` |
| 229 | RequestBodyBuilder | Anthropic 流式请求体不在主线程上构建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicStreamingBodyBuildsOffMainThread` |
| 230 | RequestBodyBuilder | 请求体内容与适配器直接构建的结果一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyMatchesAdapterDirectBuild` |
| 231 | RequestBodyBuilder | 图片消息的请求体内容不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyWithImagesIsUnchanged` |
| 232 | RequestBodyBuilder | 工具调用的请求体内容不变 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bodyWithToolCallsIsUnchanged` |
| 233 | RequestBodyBuilder | 非法工具参数仍然抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidToolArgumentsStillThrow` |
| 234 | ResponsesFailedStatus | failed 状态抛出供应商错误而不是返回空响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedStatusThrowsProviderError` |
| 235 | ResponsesFailedStatus | failed 状态带部分文本时也不得当成成功 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `failedStatusWithPartialTextIsNotSuccess` |
| 236 | ResponsesFailedStatus | completed 状态正常返回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completedStatusReturnsNormally` |
| 237 | ResponsesRefusalBlock | 拒答块的文本被保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refusalTextIsPreserved` |
| 238 | ResponsesRefusalBlock | 拒答块与正文块并存时都被保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refusalAndTextCoexist` |
| 239 | ResponsesRefusalBlock | 普通文本响应不受影响 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `regularTextUnaffected` |
| 240 | ResponsesResponseID | Responses 响应保留顶层 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesKeepsResponseID` |
| 241 | ResponsesResponseID | 没有 id 时保持 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingResponseIDStaysNil` |
| 242 | RetryAfterAndBackoff | delay-seconds 形式被解析为秒数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesDelaySeconds` |
| 243 | RetryAfterAndBackoff | 响应头键大小写不敏感 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `headerLookupIsCaseInsensitive` |
| 244 | RetryAfterAndBackoff | HTTP-date 形式按基准时间换算为等待秒数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesHTTPDate` |
| 245 | RetryAfterAndBackoff | 指向过去的 HTTP-date 视为无有效建议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pastHTTPDateYieldsNoAdvice` |
| 246 | RetryAfterAndBackoff | 缺失、空白与非法值均视为无建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidValuesYieldNoAdvice` |
| 247 | RetryAfterAndBackoff | 超过上限的等待时间被截断，避免回合被无限期阻塞 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `capsExcessiveWait` |
| 248 | RetryAfterAndBackoff | 超出整数范围的秒数仍被识别为秒数并截断，而不是被当成非法格式 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `capsExcessiveWaitBeyondIntegerRange` |
| 249 | RetryAfterAndBackoff | 指数退避上限随失败次数翻倍 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exponentialCap` |
| 250 | RetryAfterAndBackoff | 等抖动退避落在 [cap/2, cap) 区间内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalJitterStaysInRange` |
| 251 | RetryAfterAndBackoff | 退避带随机性：不同随机值产生不同等待，避免客户端同步重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `jitterProducesDistinctDelays` |
| 252 | RetryAfterAndBackoff | 策略采纳服务端给出的 Retry-After 作为等待时长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `policyUsesServerProvidedDelay` |
| 253 | RetryAfterAndBackoff | 无服务端建议时策略不给出固定等待，交由本地抖动退避决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `policyLeavesDelayToLocalBackoffWhenNoAdvice` |
| 254 | RetryAfterAndBackoff | 认证失败仍不可重试，且不因携带 Retry-After 而被放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `unauthorizedIsNeverRetried` |
| 255 | RetryAfterAndBackoff | 非 429/5xx 的状态码即使带 Retry-After 也不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryAfterDoesNotExpandRetryableStatusSet` |
| 256 | RetryAfterAndBackoff | 429 与 5xx 仍是可重试的，且 Retry-After 决定等待时长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableStatusesKeepWorking` |
| 257 | RetryAfterAndBackoff | 超过 maxAttempts 后不再重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `attemptsAreBounded` |
| 258 | RetryAfterAndBackoff | VendorAPIError 携带服务端退避建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `vendorErrorCarriesRetryAfter` |
| 259 | RetryAfterAndBackoff | 便捷构造的 HTTP 错误没有退避建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `convenienceFactoryHasNoRetryAfter` |
| 260 | RetryAfterAndBackoff | 无 Retry-After 时按带抖动的指数退避等待 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `localBackoffIsJittered` |
| 261 | RetryAfterAndBackoff | 服务端给出 Retry-After 时精确遵守，不叠加抖动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `honorsServerRetryAfterExactly` |
| 262 | RetryAfterAndBackoff | 流式路径同样遵守 Retry-After | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingPathHonorsRetryAfter` |
| 263 | ThinkingDeltaChunk | 回归：思考增量只带 reasoningContent，不伪造正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinkingDeltaChunkDoesNotCarryContent` |
| 264 | ThinkingDeltaChunk | 回归：正文增量只带 content | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `textDeltaChunkDoesNotCarryReasoning` |
| 265 | ToolCallArgumentsParser | 合法 JSON 对象被解析为有效结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesValidJSONObject` |
| 266 | ToolCallArgumentsParser | 非法 JSON 被标记为无效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidJSON` |
| 267 | ToolCallArgumentsParser | 合法 JSON 但不是对象（如数组）同样无效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsNonObjectJSON` |
| 268 | ToolCallArgumentsParser | 空字符串参数无效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyArguments` |
| 269 | ToolCallArgumentsParser | 缓存命中返回等价的解析结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedParseReturnsEquivalentResult` |
| 270 | ToolCallArgumentsParser | 同一 ID 的参数被改动后重新解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reparsesWhenArgumentsChange` |
| 271 | ToolCallArgumentsParser | 同一 ID 的参数被改成非法值时不再复用旧结果 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidatesStaleResultWhenArgumentsChange` |
| 272 | ToolCallArgumentsParser | 不同 ID 各占一条缓存 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `distinctIDsGetDistinctEntries` |
| 273 | ToolCallArgumentsParser | 校验合法参数不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validationPassesForValidArguments` |
| 274 | ToolCallArgumentsParser | 校验非法参数抛出与 LLMToolCall.validateArguments 相同的错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validationThrowsSameErrorAsDirectValidation` |
| 275 | ToolCallArgumentsParser | 缓存命中后的校验结果与首次一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `validationIsStableAcrossCacheHits` |
| 276 | ToolCallArgumentsParser | 条目数超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenEntryLimitExceeded` |
| 277 | ToolCallArgumentsParser | 源字符串总长度超过上限时被淘汰 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `evictsWhenSourceLengthLimitExceeded` |
| 278 | ToolCallArgumentsParser | 清空缓存后条目归零 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeAllResetsEntries` |
| 279 | ToolCallArgumentsParser | 淘汰后重新解析仍得到正确结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `evictedEntriesStillParseCorrectly` |
| 280 | ToolCallArgumentsParser | 重复解析同一批参数的耗时显著低于每次重新解析 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedParseIsCheaperThanReparsing` |
| 281 | VendorAPIService | 5xx 会重试并在成功后返回数据 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retriesOnServerError` |
| 282 | VendorAPIService | 达到最大尝试次数后抛出状态码错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `givesUpAfterMaxAttempts` |
| 283 | VendorAPIService | 4xx 不触发重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryOnClientError` |
| 284 | VendorAPIService | 网络超时属于瞬态错误会被重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retriesOnTimeout` |
| 285 | VendorAPIService | 无 body 的 GET 请求同样走网络替身 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsRequestWithoutBody` |
| 286 | VendorAPIService | JSON 请求体按键排序序列化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsJSONBody` |
| 287 | VendorAPIService | SSE 事件被逐个转发给回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsStreamEvents` |
| 288 | VendorAPIService | 回调返回 false 时提前终止读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsWhenCallbackReturnsFalse` |
| 289 | VendorAPIService | 已经收到事件后失败不重试，避免重复投递 token | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryAfterPartialStream` |
| 290 | VendorLLMProvider | 静态供应商:usesRemoteModelList==false, availableModels==静态列表, refresh 无害 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticProviderBehavior` |
| 291 | VendorProvider | OpenAI 兼容协议返回正文与 token 统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAICompletionParsesResponse` |
| 292 | VendorProvider | 未指定模型时回落到供应商默认模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackToDefaultModel` |
| 293 | VendorProvider | 工具名被转义并在响应中还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNamesAreSanitizedAndRestored` |
| 294 | VendorProvider | Anthropic 兼容协议返回正文与 token 统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicCompletionParsesResponse` |
| 295 | VendorProvider | 多条 system 消息被合并进顶层 system 字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergesSystemMessages` |
| 296 | VendorProvider | Responses 协议读取 output_text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesProtocolReadsOutputText` |
| 297 | VendorProvider | Responses 协议回落到 output 数组里的文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesProtocolFallsBackToOutputArray` |
| 298 | VendorProvider | Responses 协议在没有任何文本时返回空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `responsesProtocolReturnsEmptyText` |
| 299 | VendorProvider | 缺少端点配置时抛出未配置错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenEndpointIsMissing` |
| 300 | VendorProvider | HTTP 错误状态被转成 httpStatus 错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `surfacesHTTPStatusError` |
| 301 | VendorProvider | OpenAI 兼容流式响应累积正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIStreamAccumulatesContent` |
| 302 | VendorProvider | OpenAI 兼容流式拒答累积为正文而非空响应 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIStreamAccumulatesRefusal` |
| 303 | VendorProvider | Anthropic 兼容流式响应累积正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicStreamAccumulatesContent` |
| 304 | VendorProvider | Responses 协议没有流式实现时回落到非流式请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesStreamFallsBackToCompletion` |
| 305 | VendorProvider | 没有收到结束信号时拒绝不完整响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsIncompleteStream` |
| 306 | VendorProvider | 供应商标识与元数据一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerIDMatchesInfo` |
| 307 | VendorProvider | 工具 schema 转成适配器可用的形态并带回查映射 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemasBuildReverseMap` |
| 308 | VendorProvider | 没有工具时返回空的可选值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolSchemasAreNilWhenEmpty` |
| 309 | VendorProvider | 推理档位归一化并拒绝未知取值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizesReasoningEffort` |
| 310 | VisionMessageContentBuilderCache | Anthropic 图片块内容与直接编码一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicBlocksMatchDirectEncoding` |
| 311 | VisionMessageContentBuilderCache | Anthropic 重复构建返回完全相同的内容块 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `anthropicBlocksAreStableAcrossCalls` |
| 312 | VisionMessageContentBuilderCache | Anthropic 无图片时只产出文本块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicBlocksWithoutImages` |
| 313 | VisionMessageContentBuilderCache | Anthropic 空文本时不产出空文本块 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `anthropicBlocksSkipEmptyText` |
| 314 | VisionMessageContentBuilderCache | OpenAI 图片 data URL 与直接编码一致 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIContentMatchesDirectEncoding` |
| 315 | VisionMessageContentBuilderCache | OpenAI 无图片时直接返回文本 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIContentWithoutImagesReturnsText` |
| 316 | VisionMessageContentBuilderCache | OpenAI 重复构建返回完全相同的 data URL | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `openAIContentIsStableAcrossCalls` |
| 317 | VisionMessageContentBuilderCache | 不同图片产生不同的 data URL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `differentImagesProduceDifferentURLs` |
| 318 | VisionMessageContentBuilderCache | 重复构建同一批图片的耗时显著低于每次重新编码 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedBuildIsCheaperThanFirstBuild` |
| 319 | VisionMessageContentBuilderCache | 统计编码长度不得使用 O(n) 的 String.count | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `encodedLengthUsesConstantTimeCount` |

> 说明：全部 **319 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 58 / 58
- P1: 已覆盖 240 / 240
- P2: 已覆盖 21 / 21
- **合计: 319 / 319**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（58 条）
- **P1**: 其余功能性用例（240 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（21 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 319 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitLLM
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
