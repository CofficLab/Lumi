import Foundation
import HttpKit
import KernelLumi
import LLMKit
import KernelLumi
import Testing
@testable import LLMProviderMiniMaxPlugin

@Suite(.serialized)
@MainActor
struct PluginLLMProviderMiniMaxTests {
    private func makeMessage(for error: Error, conversationID: UUID = UUID()) -> LumiChatMessage {
        let provider = MiniMaxTokenPlanProvider()
        let request = LumiLLMRequest(
            messages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "test")
            ],
            model: MiniMaxTokenPlanProvider.info.defaultModel
        )
        let disposition = provider.retryDisposition(
            for: error,
            context: LumiLLMRetryContext(attempt: 1, maxAttempts: 3)
        )
        return provider.makeErrorMessage(
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition
        )
    }

    @Test func pluginMetadata() {
        #expect(MiniMaxPlugin().id.isEmpty == false)
        #expect(MiniMaxPlugin().name.isEmpty == false)
        #expect(MiniMaxPlugin().category == .llmProvider)
        #expect(MiniMaxPlugin().policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(MiniMaxTokenPlanProvider.info.id == "minimax-tokenplan")
        #expect(MiniMaxTokenPlanProvider.info.displayName.isEmpty == false)
        #expect(MiniMaxTokenPlanProvider.info.defaultModel == "MiniMax-M2.7")
        #expect(MiniMaxTokenPlanProvider.apiKeyHelpURL != nil)
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains { $0.id == "MiniMax-M3" })
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains { $0.id == "MiniMax-M2.7" })
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains { $0.id == "MiniMax-M2.7-highspeed" })
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains { $0.id == "MiniMax-M2.5" })
    }

    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: MiniMaxRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "zhipu",
            isError: true,
            renderKind: MiniMaxRenderKind.http(403)
        )

        #expect(ApiKeyMissingRenderer.item.canRender(apiKeyMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(forbiddenMessage))
        #expect(Http403Renderer.item.canRender(forbiddenMessage))
        #expect(!Http403Renderer.item.canRender(otherProviderMessage))
        #expect(Http403Renderer.item.order > 160)

        let anthropicMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxAnthropicProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.http(429)
        )
        #expect(HttpErrorRenderer.item.canRender(anthropicMessage))

        let responsesMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxResponsesProvider.info.id,
            isError: true,
            rawErrorDetail: "MiniMax returned an empty response",
            renderKind: MiniMaxRenderKind.requestFailed
        )
        #expect(RequestFailedRenderer.item.canRender(responsesMessage))

        let unauthorizedMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 错误 (401): invalid_api_key",
            renderKind: MiniMaxRenderKind.http(401)
        )

        #expect(Http401Renderer.item.canRender(unauthorizedMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(unauthorizedMessage))
    }

    @Test func providersUseSeparateProtocolEndpoints() {
        let openAI = MiniMaxOpenAIProvider()
        let anthropic = MiniMaxAnthropicProvider()
        #expect(openAI is MiniMaxOpenAIProvider)
        #expect(anthropic is MiniMaxAnthropicProvider)
        #expect(MiniMaxOpenAIProvider.info.id != MiniMaxAnthropicProvider.info.id)
    }

    @Test func responsesParserAcceptsMiniMaxResponsesAPIEvents() throws {
        let stream = """
        event: response.reasoning_text.delta
        data: {"type":"response.reasoning_text.delta","delta":"先判断","sequence_number":1}

        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":"这是答案","sequence_number":2}

        event: response.completed
        data: {"type":"response.completed","response":{"status":"completed","usage":{"input_tokens":12,"output_tokens":7,"total_tokens":19}}}


        """
        let parser = MiniMaxResponsesSSEParser()
        let splitIndex = stream.index(stream.startIndex, offsetBy: stream.count / 2)
        let events = parser.append(Data(stream[..<splitIndex].utf8))
            + parser.append(Data(stream[splitIndex...].utf8))
            + parser.finish()

        #expect(events.count == 3)
        #expect(events[0].reasoning == "先判断")
        #expect(events[1].text == "这是答案")
        #expect(events[2].isDone)
        #expect(events[2].usage?.inputTokens == 12)
        #expect(events[2].usage?.outputTokens == 7)

        let state = MiniMaxResponsesMessageState(
            conversationID: UUID(),
            providerID: MiniMaxResponsesProvider.info.id,
            model: "MiniMax-M2.7-highspeed",
            started: Date()
        )
        for event in events {
            state.append(event)
            if event.isDone { state.finish() }
        }
        let message = state.message()
        #expect(message.content == "这是答案")
        #expect(message.reasoningContent == "先判断")
        #expect(message.inputTokenCount == 12)
        #expect(message.outputTokenCount == 7)
    }

    @Test func responsesParserAccumulatesFunctionCallArguments() throws {
        let stream = """
        event: response.output_item.added
        data: {"type":"response.output_item.added","item":{"type":"function_call","call_id":"call_1","name":"project_overview","arguments":""}}

        event: response.function_call_arguments.delta
        data: {"type":"response.function_call_arguments.delta","delta":"{\\"path\\":\\"/tmp\\"}"}

        event: response.completed
        data: {"type":"response.completed","response":{"status":"completed"}}


        """
        let events = MiniMaxResponsesEventParser.parse(Data(stream.utf8))
        let state = MiniMaxResponsesMessageState(
            conversationID: UUID(),
            providerID: MiniMaxResponsesProvider.info.id,
            model: "MiniMax-M2.7-highspeed",
            started: Date()
        )
        for event in events {
            state.append(event)
            if event.isDone { state.finish() }
        }

        let call = try #require(state.message().toolCalls?.first)
        #expect(call.id == "call_1")
        #expect(call.name == "project_overview")
        #expect(call.arguments.contains("/tmp"))
    }

    @Test func openAIToolCallIsFlushedWhenStreamOmitsDoneSentinel() {
        let response = #"data: {"choices":[{"finish_reason":"tool_calls","delta":{"tool_calls":[{"id":"call_1","type":"function","function":{"name":"project_overview","arguments":"{}"}}]}}]}"#
        let events = MiniMaxOpenAIEventParser.parse(Data(response.utf8))
        let state = MiniMaxMessageState(
            conversationID: UUID(),
            providerID: MiniMaxOpenAIProvider.info.id,
            model: MiniMaxOpenAIProvider.info.defaultModel,
            started: Date()
        )

        for event in events {
            state.append(event)
        }
        state.finish()

        let message = state.message()
        #expect(message.toolCalls?.count == 1)
        #expect(message.toolCalls?.first?.name == "project_overview")
        #expect(message.toolCalls?.first?.arguments == "{}")
    }

    @Test func truncatedOpenAIToolArgumentsAreNormalizedBeforePersistence() {
        let state = MiniMaxMessageState(
            conversationID: UUID(),
            providerID: MiniMaxOpenAIProvider.info.id,
            model: MiniMaxOpenAIProvider.info.defaultModel,
            started: Date()
        )
        _ = state.append(MiniMaxOpenAIEvent(
            content: nil,
            reasoning: nil,
            toolDeltas: [(
                id: "call_truncated",
                name: "write_file",
                arguments: #"{"content":"code","path":"/tmp/file""#
            )],
            stopReason: "tool_calls",
            done: false,
            error: nil,
            inputTokens: nil,
            outputTokens: nil
        ))
        _ = state.finish()

        #expect(state.message().toolCalls?.first?.arguments == "{}")
    }

    @Test func malformedHistoricalToolArgumentsAreNormalizedBeforeRequest() throws {
        let malformed = #"{"content":"code","path":"/tmp/file""#
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "",
            toolCalls: [
                LumiToolCall(id: "call_truncated", name: "write_file", arguments: malformed),
            ]
        )
        let request = LumiLLMRequest(
            messages: [message],
            model: MiniMaxOpenAIProvider.info.defaultModel
        )

        let body = MiniMaxRequestBuilder.openAI(request)
        let messages = try #require(body["messages"] as? [[String: Any]])
        let toolCalls = try #require(messages[0]["tool_calls"] as? [[String: Any]])
        let function = try #require(toolCalls[0]["function"] as? [String: Any])

        #expect(function["arguments"] as? String == "{}")
        _ = try JSONSerialization.data(withJSONObject: body)
    }

    @Test func anthropicToolImagesAreNestedInsideToolResult() throws {
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString(),
            fileName: "preview.png"
        )
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .tool,
            content: "已读取图片",
            metadata: LumiImageAttachmentMetadata.encode([attachment]),
            toolCallID: "call_image"
        )
        let body = MiniMaxRequestBuilder.anthropic(LumiLLMRequest(
            messages: [message],
            model: MiniMaxAnthropicProvider.info.defaultModel
        ))

        let messages = try #require(body["messages"] as? [[String: Any]])
        let outerContent = try #require(messages[0]["content"] as? [[String: Any]])
        let resultContent = try #require(outerContent[0]["content"] as? [[String: Any]])

        #expect(outerContent.count == 1)
        #expect(resultContent.map { $0["type"] as? String } == ["text", "image"])
    }

    @Test func openAIEmbeddedThinkTagsAreSeparatedFromContent() {
        let state = MiniMaxMessageState(
            conversationID: UUID(),
            providerID: MiniMaxOpenAIProvider.info.id,
            model: MiniMaxOpenAIProvider.info.defaultModel,
            started: Date()
        )
        _ = state.append(MiniMaxOpenAIEvent(
            content: "<think>先检查代码",
            reasoning: nil,
            toolDeltas: [],
            stopReason: nil,
            done: false,
            error: nil,
            inputTokens: nil,
            outputTokens: nil
        ))
        _ = state.append(MiniMaxOpenAIEvent(
            content: "</think>这是正文</think>",
            reasoning: nil,
            toolDeltas: [],
            stopReason: nil,
            done: false,
            error: nil,
            inputTokens: nil,
            outputTokens: nil
        ))
        _ = state.finish()

        let message = state.message()
        #expect(message.reasoningContent == "先检查代码")
        #expect(message.content == "这是正文")
    }

    @Test func anthropicSSEParserPreservesFramesSplitAcrossChunks() {
        let parser = MiniMaxAnthropicSSEParser()
        let first = parser.append(Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"hel".utf8))
        let second = parser.append(Data("lo\"}}\n\n".utf8))

        #expect(first.isEmpty)
        #expect(second.count == 1)
        #expect(second.first?.text == "hello")
    }

    @Test func openAISSEParserPreservesFramesSplitAcrossChunks() {
        let parser = MiniMaxOpenAISSEParser()
        let first = parser.append(Data("data: {\"choices\":[{\"delta\":{\"content\":\"hel".utf8))
        let second = parser.append(Data("lo\"}}]}\n\n".utf8))

        #expect(first.isEmpty)
        #expect(second.count == 1)
        #expect(second.first?.content == "hello")
    }

    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let conversationID = UUID()
        let rateLimited = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.http(429)
        )
        let forbidden = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.http(403)
        )

        #expect(HttpErrorRenderer.item.canRender(rateLimited))
        #expect(!HttpErrorRenderer.item.canRender(forbidden))
    }

    @Test func errorMessageMapsMissingAPIKey() {
        let message = makeMessage(
            for: LumiLLMProviderSupportError.missingAPIKey(MiniMaxTokenPlanProvider.info.displayName)
        )

        #expect(message.renderKind == MiniMaxRenderKind.apiKeyMissing)
        #expect(message.providerID == MiniMaxTokenPlanProvider.info.id)
        #expect(message.isError)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessageMapsHTTP401FromHTTPClientError() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        )

        #expect(message.renderKind == MiniMaxRenderKind.http(401))
        #expect(message.rawErrorDetail == "invalid_api_key")
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains("invalid_api_key") == true)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessagePreservesMiniMaxRawResponse() {
        let rawResponse = #"{"error":{"message":"已达到 Token Plan 用量上限：请升级 Token Plan 套餐或购买积分补充用量。 (2056)","type":"rate_limit_error"},"request_id":"06c0e1336148ddfb89b77bc39f2b9c9b","type":"error"}"#
        let message = makeMessage(
            for: MiniMaxProviderError.api(statusCode: 429, message: rawResponse)
        )

        #expect(message.rawErrorDetail?.contains("Token Plan") == true)
        #expect(message.metadata[LLMTransportMetadata.responseDetails] == rawResponse)
    }

    @Test func errorMessagePreservesHTTPNetworkErrorBody() {
        let rawResponse = #"{"error":{"message":"已达到 Token Plan 用量上限：请升级 Token Plan 套餐或购买积分补充用量。 (2056)","type":"rate_limit_error"},"request_id":"06c0e1336148ddfb89b77bc39f2b9c9b9","type":"error"}"#
        let error = HTTPNetworkError(
            url: URL(string: "https://api.minimax.chat/anthropic/v1/messages")!,
            statusCode: 429,
            body: Data(rawResponse.utf8)
        )
        let message = makeMessage(for: error)

        #expect(message.renderKind == MiniMaxRenderKind.http(429))
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains("Response Status: 429") == true)
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains("Response Headers:") == true)
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains(rawResponse) == true)
    }

    @Test func errorMessageMapsHTTP429AsRetryable() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 429, message: "rate limited")
        )

        #expect(message.renderKind == MiniMaxRenderKind.http(429))
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "true")
    }

    @Test func errorMessageUsesNestedProviderMessageAsSummary() {
        let providerMessage = "当前服务集群负载较高，请稍后重试，感谢您的耐心等待。 (2064)"
        let rawResponse = "{\"error\":{\"type\":\"overloaded_error\",\"message\":\"\(providerMessage)\",\"http_code\":\"529\"},\"type\":\"error\"}"
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 529, message: rawResponse)
        )

        #expect(message.rawErrorDetail == providerMessage)
        #expect(message.metadata[LLMTransportMetadata.responseDetails] == rawResponse)
        #expect(message.renderKind == MiniMaxRenderKind.http(529))
    }

    @Test func unsupportedModelAvailabilityMapsToStructuredFailure() {
        let body = #"{"error":{"code":"invalid_parameter_error","message":"model not supported"}}"#
        let error = HTTPClientError.httpError(statusCode: 400, message: body)

        #expect(AvailabilityService.isUnsupportedModelError(error))

        let mapped = AvailabilityService.mapUnsupportedModelResult(
            .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.reason == .unsupportedModel)
        #expect(!failure.availabilityDisplayText.contains("invalid_parameter"))
        #expect(!failure.availabilityDisplayText.contains("URL:"))
        #expect(failure.hasTransportDiagnostics)
        #expect(failure.transportDetails?.contains("invalid_parameter") == true)
        #expect(failure.httpStatusCode == 400)
    }

    @Test func unsupportedModelDetectsModelNotFoundInResponse() {
        let body = #"{"error":{"code":"model_not_found","message":"MiniMax-M2.7 is unavailable"}}"#

        #expect(AvailabilityService.isUnsupportedModelResponse(body))
    }

    @Test func renderKindParsingRoundTripsHTTPStatusCode() {
        let renderKind = MiniMaxRenderKind.http(429)

        #expect(MiniMaxRenderKind.httpStatusCode(from: renderKind) == 429)
        #expect(MiniMaxRenderKind.httpStatusCode(from: "aliyun-http-429") == nil)
    }
}
