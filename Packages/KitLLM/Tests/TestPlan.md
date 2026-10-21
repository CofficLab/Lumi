# TestPlan — KitLLM

## 包概述

KitLLM 的实现包，包含 14 个主要类型；当前测试覆盖 195 条用例。

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 195

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
- `OpenAICompatibleProviderAdapter`
- `OpenAICompatibleProviderConfiguration`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **APIKeyMemoryCache**（5 条）：由 `freshWithinTTL`、`negativeEntry`、`lastKnownIgnoresTTL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AnthropicAdapter**（46 条）：由 `buildsRequestHeaders`、`buildsRequestBody`、`systemMessagesOverridePrompt` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（42 条）：由 `messageCreation`、`requestCreation`、`providerInfo` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAICompatibleStreamParsing**（9 条）：由 `reasoningAndToolCallsCoexist`、`contentAndToolCallsCoexist`、`usageSurvivesToolCallFrame` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderErrorAndContract**（44 条）：由 `parsesOpenAIErrorBody`、`parsesAnthropicErrorBody`、`fallsBackToGenericJSON` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RetryAfterAndBackoff**（21 条）：由 `parsesDelaySeconds`、`headerLookupIsCaseInsensitive`、`parsesHTTPDate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorAPIService**（9 条）：由 `retriesOnServerError`、`givesUpAfterMaxAttempts`、`doesNotRetryOnClientError` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorLLMProvider**（1 条）：由 `staticProviderBehavior` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorProvider**（18 条）：由 `openAICompletionParsesResponse`、`fallsBackToDefaultModel`、`toolNamesAreSanitizedAndRestored` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 15 | AnthropicAdapter | 开启缓存时最后一条文本块带缓存边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsPromptCacheBoundary` |
| 16 | AnthropicAdapter | 关闭缓存时不写缓存边界 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `omitsPromptCacheBoundaryByDefault` |
| 17 | AnthropicAdapter | 文本内容被拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextContent` |
| 18 | AnthropicAdapter | 工具调用被解析成结构化参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesToolUseBlock` |
| 19 | AnthropicAdapter | 工具名按反查映射还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoresToolNameFromReverseMap` |
| 20 | AnthropicAdapter | 错误响应体被转成 apiError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsAPIError` |
| 21 | AnthropicAdapter | message_start 事件带输入 token 与消息 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageStart` |
| 22 | AnthropicAdapter | message_delta 事件带输出 token 与结束原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageDelta` |
| 23 | AnthropicAdapter | message_stop 事件标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesMessageStop` |
| 24 | AnthropicAdapter | 文本内容块开始事件带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextContentBlockStart` |
| 25 | AnthropicAdapter | 工具内容块开始事件带工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesToolContentBlockStart` |
| 26 | AnthropicAdapter | 思考内容块开始事件不带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesThinkingContentBlockStart` |
| 27 | AnthropicAdapter | 文本增量事件带正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesTextDelta` |
| 28 | AnthropicAdapter | 思考增量事件被标记为 thinking | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesThinkingDelta` |
| 29 | AnthropicAdapter | 工具参数增量事件带 partial_json | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesInputJSONDelta` |
| 30 | AnthropicAdapter | 签名增量事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesSignatureDelta` |
| 31 | AnthropicAdapter | 内容块停止事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesContentBlockStop` |
| 32 | AnthropicAdapter | ping 事件被单独标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesPing` |
| 33 | AnthropicAdapter | 错误事件带错误信息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesErrorEvent` |
| 34 | AnthropicAdapter | [DONE] 标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesDoneMarker` |
| 35 | AnthropicAdapter | 没有 data 行的块被忽略 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresBlockWithoutData` |
| 36 | AnthropicAdapter | 网关返回整段 JSON 时按整体响应解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesWholeJSONBody` |
| 37 | AnthropicAdapter | 普通文本消息原样转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsPlainText` |
| 38 | AnthropicAdapter | 工具结果消息转成 tool_result 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsToolResult` |
| 39 | AnthropicAdapter | 带工具调用的 assistant 消息转成 tool_use 块且名字被转义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsAssistantToolCalls` |
| 40 | AnthropicAdapter | 带思考内容的 assistant 消息生成 thinking 块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsReasoningContent` |
| 41 | AnthropicAdapter | 带图片的消息转成 base64 图片块 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transformsImages` |
| 42 | AnthropicAdapter | 工具定义被转成 Anthropic 形态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsToolSchema` |
| 43 | AnthropicAdapter | 官方语义下总输入就是 input_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `officialSemanticsUseInputTokens` |
| 44 | AnthropicAdapter | 兼容层语义下总输入是三段之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compatibleSemanticsSumAllParts` |
| 45 | AnthropicAdapter | 缺少 input_tokens 时退回到缓存字段之和 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToCacheFields` |
| 46 | AnthropicAdapter | 完全没有任何计数时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutAnyCount` |
| 47 | AnthropicAdapter | 缓存读取字段兼容多种命名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsCacheReadTokens` |
| 48 | AnthropicAdapter | 缓存写入字段兼容多种命名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsCacheWriteTokens` |
| 49 | AnthropicAdapter | 5xx 可重试，4xx 不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `classifiesStatusCodes` |
| 50 | AnthropicAdapter | 尝试次数用尽后不再重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopsAfterMaxAttempts` |
| 51 | AnthropicAdapter | 取消类错误不重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryCancelled` |
| 52 | 综合 | LLMMessage 构造和字段访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageCreation` |
| 53 | 综合 | LLMRequest 构造 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestCreation` |
| 54 | 综合 | LLMProviderInfo 元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerInfo` |
| 55 | 综合 | 本地供应商自动推导类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localProviderTypeIsInferred` |
| 56 | 综合 | 供应商类型支持中转站 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relayProviderTypeCanBeDeclared` |
| 57 | 综合 | 基础档位对所有 OpenAI 兼容供应商都透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsBaseReasoningEffort` |
| 58 | 综合 | 未声明的额外档位不下发，避免上游返回 400 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterDropsUndeclaredReasoningEffort` |
| 59 | 综合 | 供应商声明的额外档位正常下发（MiniMax 支持 xhigh / max） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsDeclaredExtraReasoningEffort` |
| 60 | 综合 | 档位归一化忽略大小写与空白，并拒绝 auto | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `reasoningEffortNormalization` |
| 61 | 综合 | 额外档位声明在构造时归一化为小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `additionalReasoningEffortsAreNormalized` |
| 62 | 综合 | VendorAPIError 错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 63 | 综合 | LLMToolNameSanitizer 转义规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNameSanitizer` |
| 64 | 综合 | OpenAI adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterBuildsBody` |
| 65 | 综合 | OpenAI adapter 拒绝非法工具参数，避免把坏历史发送给供应商 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `openAIAdapterRejectsInvalidToolArguments` |
| 66 | 综合 | LLM 响应在落库前拒绝非法工具参数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `responseRejectsInvalidToolArguments` |
| 67 | 综合 | OpenAI 兼容流式解析器兼容 input/output token 字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesUsageAliases` |
| 68 | 综合 | OpenAI 兼容流式解析器识别 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesFinishReason` |
| 69 | 综合 | DeepSeek 最终结束块保留 usage 和缓存命中字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDeepSeekFinalUsageChunk` |
| 70 | 综合 | 同一 delta 同时含思考与正文时两者都保留，不丢弃正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWhenInterleavedWithReasoning` |
| 71 | 综合 | interleaved thinking 累积后正文非空，思考与正文各自完整 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterAccumulatorPreservesInterleavedContent` |
| 72 | 综合 | 仅思考无正文时仍产出思考事件，且不伪造正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterEmitsThinkingOnlyChunk` |
| 73 | 综合 | 正文与工具调用同 delta 时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsTextAndToolCallsInSameDelta` |
| 74 | 综合 | 带正文与 finish_reason 的 delta 同时保留正文与结束信号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWithFinishReason` |
| 75 | 综合 | 无任何增量的空 delta 不产出 chunk | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterSkipsEmptyDelta` |
| 76 | 综合 | 返回空 chunk 的网关配置保持既有行为 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterKeepsEmptyChunkFallback` |
| 77 | 综合 | 工具调用事件仍产出可累积的 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterStillParsesToolCallDeltas` |
| 78 | 综合 | [DONE] 事件产出终止 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDoneMarker` |
| 79 | 综合 | OpenAI 兼容请求过滤授权占位并去重旧工具结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterRepairsDuplicateToolResults` |
| 80 | 综合 | OpenAI 兼容请求不会把工具图片放进 assistant 内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterMovesToolImagesToSyntheticUserMessage` |
| 81 | 综合 | OpenAI 兼容请求将迟到的交互工具结果移到 assistant 后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRepairsOutOfOrderToolResult` |
| 82 | 综合 | OpenAI 兼容请求移除无结果的孤立工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRemovesOrphanToolCalls` |
| 83 | 综合 | 未收到流式终止信号时拒绝不完整响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `incompleteStreamingResponseFails` |
| 84 | 综合 | Anthropic adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterBuildsBody` |
| 85 | 综合 | Anthropic 缓存配置在最后文本块添加显式边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterAddsPromptCacheBoundaryWhenEnabled` |
| 86 | 综合 | Anthropic usage 兼容阿里云缓存读取和创建字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterParsesCacheUsage` |
| 87 | 综合 | VendorAPIKeyTools set/get/remove | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyTools` |
| 88 | 综合 | 测试进程忘记隔离 service 时重定向，不写生产 Keychain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProcessRedirectsProductionService` |
| 89 | 综合 | 完整 Keychain 查询遇到一次 not-found 后会重试并恢复 Key | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `apiKeyReadRetriesCompleteMissingLookup` |
| 90 | 综合 | 连续完整查询均 not-found 后才认定 API Key 缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyReadConfirmsMissingAcrossRetries` |
| 91 | 综合 | 网络中断可重试但认证失败不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryPolicyClassifiesTransientErrors` |
| 92 | 综合 | 流式计时器记录首个输出和流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingRecorder` |
| 93 | 综合 | 没有输出时不伪造流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingWithoutOutput` |
| 94 | OpenAICompatibleStreamParsing | 同一 delta 内 reasoning_content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningAndToolCallsCoexist` |
| 95 | OpenAICompatibleStreamParsing | 同一 delta 内 content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentAndToolCallsCoexist` |
| 96 | OpenAICompatibleStreamParsing | 带 tool_calls 的末帧仍透传 usage 与 stop_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageSurvivesToolCallFrame` |
| 97 | OpenAICompatibleStreamParsing | 纯 finish_reason 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pureStopReasonFrame` |
| 98 | OpenAICompatibleStreamParsing | usage-only 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageOnlyFrame` |
| 99 | OpenAICompatibleStreamParsing | [DONE] 事件标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doneEvent` |
| 100 | OpenAICompatibleStreamParsing | DeepSeek 形态的总输入就是 prompt_tokens，不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deepSeekCacheTotalIsPromptTokens` |
| 101 | OpenAICompatibleStreamParsing | OpenAI 形态的总量不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAICacheTotalIsPromptTokens` |
| 102 | OpenAICompatibleStreamParsing | 思考增量与正文增量携带相同的总输入口径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinkingAndTextChunksShareCacheTotal` |
| 103 | ProviderErrorAndContract | OpenAI 形态的错误体解析出 message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesOpenAIErrorBody` |
| 104 | ProviderErrorAndContract | Anthropic 形态的错误体解析出 message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesAnthropicErrorBody` |
| 105 | ProviderErrorAndContract | 未知形态回落到通用 JSON 解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToGenericJSON` |
| 106 | ProviderErrorAndContract | 通用 JSON 优先取 error.message | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `genericJSONPrefersNestedErrorMessage` |
| 107 | ProviderErrorAndContract | 没有可识别字段时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForUnrecognisedBody` |
| 108 | ProviderErrorAndContract | 非 JSON 与空响应返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForNonJSONBody` |
| 109 | ProviderErrorAndContract | 仅 429 与 5xx 被视为可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableStatusCodes` |
| 110 | ProviderErrorAndContract | 优先读取实现 LLMHTTPErrorProviding 的错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersHTTPErrorProtocol` |
| 111 | ProviderErrorAndContract | 回落到 NSError userInfo 中的 statusCode | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToNSErrorUserInfo` |
| 112 | ProviderErrorAndContract | 没有状态码时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutStatusCode` |
| 113 | ProviderErrorAndContract | 配置类错误不可重试，请求失败可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryabilityClassification` |
| 114 | ProviderErrorAndContract | 错误描述覆盖全部用例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 115 | ProviderErrorAndContract | 错误描述覆盖全部用例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 116 | ProviderErrorAndContract | HTTP 错误便捷构造不带退避建议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpStatusConvenienceOverload` |
| 117 | ProviderErrorAndContract | 缺失与读取失败两类错误带专属渲染类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderKindClassification` |
| 118 | ProviderErrorAndContract | 原始错误详情只在两类 Key 错误上提供 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rawErrorDetail` |
| 119 | ProviderErrorAndContract | Anthropic 适配器错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicErrorDescriptions` |
| 120 | ProviderErrorAndContract | OpenAI 适配器错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIErrorDescriptions` |
| 121 | ProviderErrorAndContract | 合法配置通过校验 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsValidConfig` |
| 122 | ProviderErrorAndContract | 缺省温度与 token 上限视为合法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsNilOptionals` |
| 123 | ProviderErrorAndContract | 模型名为空被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyModel` |
| 124 | ProviderErrorAndContract | 供应商 ID 为空被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyProviderID` |
| 125 | ProviderErrorAndContract | 温度超出 0...2 被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOutOfRangeTemperature` |
| 126 | ProviderErrorAndContract | 非正的最大 token 数被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsNonPositiveMaxTokens` |
| 127 | ProviderErrorAndContract | 默认配置指向 Anthropic | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultConfigTargetsAnthropic` |
| 128 | ProviderErrorAndContract | provider 与 model 都非空才可构造 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsEmptyComponents` |
| 129 | ProviderErrorAndContract | 原始值带固定前缀并可逆解析 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rawValueRoundTrips` |
| 130 | ProviderErrorAndContract | 分隔符等特殊字符被百分号编码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodesSpecialCharacters` |
| 131 | ProviderErrorAndContract | 非法原始值返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidRawValues` |
| 132 | ProviderErrorAndContract | 可编码解码 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTrip` |
| 133 | ProviderErrorAndContract | 非法值解码抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decodingRejectsInvalidRawValue` |
| 134 | ProviderErrorAndContract | 模型 id 列表与包含判定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelIDHelpers` |
| 135 | ProviderErrorAndContract | 供应商类型按是否本地推导 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerTypeIsInferred` |
| 136 | ProviderErrorAndContract | 显式声明的供应商类型优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitProviderTypeWins` |
| 137 | ProviderErrorAndContract | 缺省协议为 OpenAI 兼容 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultAPIFormatIsOpenAI` |
| 138 | ProviderErrorAndContract | 供应商类型的展示名与图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `providerTypePresentation` |
| 139 | ProviderErrorAndContract | 模型元数据的缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `modelInfoDefaults` |
| 140 | ProviderErrorAndContract | 进度缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `progressDefaults` |
| 141 | ProviderErrorAndContract | 状态缺省值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stateDefaults` |
| 142 | ProviderErrorAndContract | 失败状态携带原因 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `failedStatusCarriesReason` |
| 143 | ProviderErrorAndContract | 映射建立 sanitize 名到原始名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsReverseMap` |
| 144 | ProviderErrorAndContract | 同名冲突时先注册者优先 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRegistrationWins` |
| 145 | ProviderErrorAndContract | 首字符非字母时补 tool_ 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addsToolPrefixWhenFirstCharacterIsNotLetter` |
| 146 | ProviderErrorAndContract | 空列表得到空映射 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyToolListYieldsEmptyMap` |
| 147 | RetryAfterAndBackoff | delay-seconds 形式被解析为秒数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesDelaySeconds` |
| 148 | RetryAfterAndBackoff | 响应头键大小写不敏感 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `headerLookupIsCaseInsensitive` |
| 149 | RetryAfterAndBackoff | HTTP-date 形式按基准时间换算为等待秒数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesHTTPDate` |
| 150 | RetryAfterAndBackoff | 指向过去的 HTTP-date 视为无有效建议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pastHTTPDateYieldsNoAdvice` |
| 151 | RetryAfterAndBackoff | 缺失、空白与非法值均视为无建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidValuesYieldNoAdvice` |
| 152 | RetryAfterAndBackoff | 超过上限的等待时间被截断，避免回合被无限期阻塞 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `capsExcessiveWait` |
| 153 | RetryAfterAndBackoff | 超出整数范围的秒数仍被识别为秒数并截断，而不是被当成非法格式 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `capsExcessiveWaitBeyondIntegerRange` |
| 154 | RetryAfterAndBackoff | 指数退避上限随失败次数翻倍 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exponentialCap` |
| 155 | RetryAfterAndBackoff | 等抖动退避落在 [cap/2, cap) 区间内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `equalJitterStaysInRange` |
| 156 | RetryAfterAndBackoff | 退避带随机性：不同随机值产生不同等待，避免客户端同步重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `jitterProducesDistinctDelays` |
| 157 | RetryAfterAndBackoff | 策略采纳服务端给出的 Retry-After 作为等待时长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `policyUsesServerProvidedDelay` |
| 158 | RetryAfterAndBackoff | 无服务端建议时策略不给出固定等待，交由本地抖动退避决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `policyLeavesDelayToLocalBackoffWhenNoAdvice` |
| 159 | RetryAfterAndBackoff | 认证失败仍不可重试，且不因携带 Retry-After 而被放行 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `unauthorizedIsNeverRetried` |
| 160 | RetryAfterAndBackoff | 非 429/5xx 的状态码即使带 Retry-After 也不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryAfterDoesNotExpandRetryableStatusSet` |
| 161 | RetryAfterAndBackoff | 429 与 5xx 仍是可重试的，且 Retry-After 决定等待时长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryableStatusesKeepWorking` |
| 162 | RetryAfterAndBackoff | 超过 maxAttempts 后不再重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `attemptsAreBounded` |
| 163 | RetryAfterAndBackoff | VendorAPIError 携带服务端退避建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `vendorErrorCarriesRetryAfter` |
| 164 | RetryAfterAndBackoff | 便捷构造的 HTTP 错误没有退避建议 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `convenienceFactoryHasNoRetryAfter` |
| 165 | RetryAfterAndBackoff | 无 Retry-After 时按带抖动的指数退避等待 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `localBackoffIsJittered` |
| 166 | RetryAfterAndBackoff | 服务端给出 Retry-After 时精确遵守，不叠加抖动 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `honorsServerRetryAfterExactly` |
| 167 | RetryAfterAndBackoff | 流式路径同样遵守 Retry-After | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingPathHonorsRetryAfter` |
| 168 | VendorAPIService | 5xx 会重试并在成功后返回数据 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retriesOnServerError` |
| 169 | VendorAPIService | 达到最大尝试次数后抛出状态码错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `givesUpAfterMaxAttempts` |
| 170 | VendorAPIService | 4xx 不触发重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryOnClientError` |
| 171 | VendorAPIService | 网络超时属于瞬态错误会被重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retriesOnTimeout` |
| 172 | VendorAPIService | 无 body 的 GET 请求同样走网络替身 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsRequestWithoutBody` |
| 173 | VendorAPIService | JSON 请求体按键排序序列化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sendsJSONBody` |
| 174 | VendorAPIService | SSE 事件被逐个转发给回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsStreamEvents` |
| 175 | VendorAPIService | 回调返回 false 时提前终止读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsWhenCallbackReturnsFalse` |
| 176 | VendorAPIService | 已经收到事件后失败不重试，避免重复投递 token | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `doesNotRetryAfterPartialStream` |
| 177 | VendorLLMProvider | 静态供应商:usesRemoteModelList==false, availableModels==静态列表, refresh 无害 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticProviderBehavior` |
| 178 | VendorProvider | OpenAI 兼容协议返回正文与 token 统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAICompletionParsesResponse` |
| 179 | VendorProvider | 未指定模型时回落到供应商默认模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `fallsBackToDefaultModel` |
| 180 | VendorProvider | 工具名被转义并在响应中还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNamesAreSanitizedAndRestored` |
| 181 | VendorProvider | Anthropic 兼容协议返回正文与 token 统计 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicCompletionParsesResponse` |
| 182 | VendorProvider | 多条 system 消息被合并进顶层 system 字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergesSystemMessages` |
| 183 | VendorProvider | Responses 协议读取 output_text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesProtocolReadsOutputText` |
| 184 | VendorProvider | Responses 协议回落到 output 数组里的文本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesProtocolFallsBackToOutputArray` |
| 185 | VendorProvider | Responses 协议在没有任何文本时返回空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `responsesProtocolReturnsEmptyText` |
| 186 | VendorProvider | 缺少端点配置时抛出未配置错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenEndpointIsMissing` |
| 187 | VendorProvider | HTTP 错误状态被转成 httpStatus 错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `surfacesHTTPStatusError` |
| 188 | VendorProvider | OpenAI 兼容流式响应累积正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIStreamAccumulatesContent` |
| 189 | VendorProvider | Anthropic 兼容流式响应累积正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicStreamAccumulatesContent` |
| 190 | VendorProvider | Responses 协议没有流式实现时回落到非流式请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesStreamFallsBackToCompletion` |
| 191 | VendorProvider | 没有收到结束信号时拒绝不完整响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsIncompleteStream` |
| 192 | VendorProvider | 供应商标识与元数据一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerIDMatchesInfo` |
| 193 | VendorProvider | 工具 schema 转成适配器可用的形态并带回查映射 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemasBuildReverseMap` |
| 194 | VendorProvider | 没有工具时返回空的可选值 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolSchemasAreNilWhenEmpty` |
| 195 | VendorProvider | 推理档位归一化并拒绝未知取值 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizesReasoningEffort` |

> 说明：全部 **195 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 39 / 39
- P1: 已覆盖 142 / 142
- P2: 已覆盖 14 / 14
- **合计: 195 / 195**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（39 条）
- **P1**: 其余功能性用例（142 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（14 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 195 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
