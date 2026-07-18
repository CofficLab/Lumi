import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

// MARK: - Inline Tool Call Recovery 集成测试
//
// 验证：当模型把工具调用以特殊格式（<tool_call>、<function_calls>、JSON 块等）
// 写进正文而非结构化 `toolCalls` 时，AgentLoop 会检测到并追加纠正消息重试，
// 而非因 `toolCalls` 为空而提前结束。
//
// 复用 EmptyResponseRetryTests 中的 SequencedResponseMockProvider / NoOpToolService。

// MARK: - 检测器单元测试

@Suite struct InlineToolCallDetectorSuite {

    @Test("<tool_call> 标签被检测")
    func hermesToolCallTag() {
        let body = "我来读取文件\n<tool_call>\n{\"name\":\"read_file\",\"arguments\":{\"path\":\"a.swift\"}}\n</tool_call>"
        #expect(InlineToolCallDetector.detected(in: body))
    }

    @Test("<function_calls> 标签被检测")
    func anthropicFunctionCallsTag() {
        #expect(InlineToolCallDetector.detected(in: "<function_calls>\n<invoke>read_file</invoke>\n</function_calls>"))
    }

    @Test("antml: 命名空间标签被检测")
    func antmlNamespace() {
        #expect(InlineToolCallDetector.detected(in: "<antml:function_calls>"))
        #expect(InlineToolCallDetector.detected(in: "<antml:parameter name=\"path\">a.swift</antml:parameter>"))
    }

    @Test("```tool_call 代码块被检测")
    func fencedToolCallBlock() {
        #expect(InlineToolCallDetector.detected(in: "```tool_call\n{\"name\":\"read_file\"}\n```"))
    }

    @Test("纯 JSON 工具调用(name + arguments)被检测")
    func pureJSONToolCall() {
        let body = "{\"name\":\"read_file\",\"arguments\":{\"path\":\"a.swift\"}}"
        #expect(InlineToolCallDetector.detected(in: body))
    }

    @Test("纯 JSON 工具调用(name + parameters)被检测")
    func pureJSONToolCallParameters() {
        let body = "{\"tool\":\"read_file\",\"parameters\":{\"path\":\"a.swift\"}}"
        #expect(InlineToolCallDetector.detected(in: body))
    }

    @Test("普通正文不误判")
    func normalBodyNotFlagged() {
        #expect(!InlineToolCallDetector.detected(in: "我已经读取了文件，内容如下..."))
        #expect(!InlineToolCallDetector.detected(in: ""))
        #expect(!InlineToolCallDetector.detected(in: "  \n  "))
    }

    @Test("普通 JSON 说明文本不误判(缺少 arguments/parameters 键)")
    func plainJSONNotFlagged() {
        // 只有 name 没有 arguments —— 不算工具调用
        #expect(!InlineToolCallDetector.detected(in: "{\"name\":\"Alice\",\"age\":30}"))
        // 普通配置对象
        #expect(!InlineToolCallDetector.detected(in: "{\"version\":2,\"items\":[1,2,3]}"))
    }

    @Test("有结构化 toolCalls 的消息不算内联工具调用")
    func structuredToolCallsNotFlagged() {
        let msg = LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "<tool_call>{\"name\":\"x\"}</tool_call>",  // 即便正文也有
            toolCalls: [LumiToolCall(id: "1", name: "noop", arguments: "{}")]
        )
        #expect(!msg.hasInlineToolCallInBody)
    }

    @Test("错误消息不参与检测")
    func errorMessageNotFlagged() {
        let msg = LumiChatMessage(
            conversationID: UUID(),
            role: .error,
            content: "<tool_call>{\"name\":\"x\",\"arguments\":{}}</tool_call>",
            isError: true
        )
        #expect(!msg.hasInlineToolCallInBody)
    }
}

// MARK: - makeAssistantMessageWithInlineToolCallRetry 测试

@Suite(.serialized)
@MainActor
struct InlineToolCallRetrySuite {
    private func makeService(provider: SequencedResponseMockProvider) throws -> (ChatService, UUID) {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "InlineToolCallRetry")
        service.registerProviders([provider])
        service.selectProvider(id: type(of: provider).info.id, model: "mock", for: conversationID)
        return (service, conversationID)
    }

    @Test("首次正文内联工具调用 → 重试后返回正常消息，注入纠正 nudge")
    func retriesOnInlineToolCallThenSucceeds() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            // 重试请求（首次由调用方传入，不经过 provider）
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Done") },
        ])
        let (service, conversationID) = try makeService(provider: provider)

        let firstMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "<tool_call>\n{\"name\":\"read_file\",\"arguments\":{\"path\":\"a.swift\"}}\n</tool_call>"
        )

        let message = try await service.makeAssistantMessageWithInlineToolCallRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            firstMessage: firstMessage,
            imageAttachments: []
        )

        #expect(message.content == "Done")
        #expect(!message.hasInlineToolCallInBody)
        #expect(provider.callCount == 1) // 仅重试那一次请求 LLM

        // 重试请求应注入纠正 nudge
        let retriedRequest = provider.receivedRequests[0]
        #expect(retriedRequest.messages.contains {
            $0.metadata["lumi-nudge"] == "inline-tool-call-retry"
        })
    }

    @Test("重试后仍内联 → 耗尽，返回最后一条含内联工具调用的消息")
    func exhaustsRetriesWhenStillInline() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            // 重试仍返回内联工具调用
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant,
                content: "{\"name\":\"read_file\",\"arguments\":{\"path\":\"a.swift\"}}") },
        ])
        let (service, conversationID) = try makeService(provider: provider)

        let firstMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "<function_calls><invoke>read_file</invoke></function_calls>"
        )

        let message = try await service.makeAssistantMessageWithInlineToolCallRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            firstMessage: firstMessage,
            imageAttachments: []
        )

        #expect(message.hasInlineToolCallInBody)
        #expect(provider.callCount == 1) // 仅重试那一次
    }

    @Test("首条消息不含内联工具调用 → 不请求 LLM，直接返回")
    func noRetryOnNormalResponse() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Hello!") }
        ])
        let (service, conversationID) = try makeService(provider: provider)

        let firstMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "Hello!"
        )

        let message = try await service.makeAssistantMessageWithInlineToolCallRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            firstMessage: firstMessage,
            imageAttachments: []
        )

        #expect(message.content == "Hello!")
        #expect(provider.callCount == 0) // 不含内联工具调用，完全不请求 LLM
    }

    @Test("重试中的内联消息不写入持久化历史")
    func retryInlineMessagesAreNotAppended() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "OK") },
        ])
        let (service, conversationID) = try makeService(provider: provider)

        let firstMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "<tool_call>{\"name\":\"read_file\",\"arguments\":{}}</tool_call>"
        )

        _ = try await service.makeAssistantMessageWithInlineToolCallRetry(
            conversationID: conversationID,
            baseMessages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "hi")
            ],
            firstMessage: firstMessage,
            imageAttachments: []
        )

        // 重试方法本身不 append，验证不产生副作用。
        let messages = service.messages(for: conversationID)
        let inlineAssistants = messages.filter { $0.hasInlineToolCallInBody }
        #expect(inlineAssistants.isEmpty)
    }
}

// MARK: - runAgentTurn 端到端测试

@Suite(.serialized)
@MainActor
struct InlineToolCallEndToEndSuite {
    private func makeService(
        provider: SequencedResponseMockProvider,
        toolService: LumiToolServicing? = nil
    ) throws -> (ChatService, UUID) {
        let directory = ChatPerformanceTestSupport.makeTemporaryDatabaseDirectory()
        let service = try ChatService(configuration: .coreDatabase(directory: directory))
        let conversationID = service.createConversation(title: "InlineE2E")
        service.registerProviders([provider])
        service.selectProvider(id: type(of: provider).info.id, model: "mock", for: conversationID)
        service.setAutomationLevel(.autonomous, for: conversationID)
        if let toolService {
            service.registerToolService(toolService)
        }
        return (service, conversationID)
    }

    @Test("正文内联工具调用 → 重试后正常 toolCalls → turn 不误结束，工具被执行")
    func inlineThenStructuredToolCallCompletes() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            // 第一轮：把工具调用写进正文（无结构化 toolCalls）
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant,
                content: "<tool_call>\n{\"name\":\"noop\",\"arguments\":{\"message\":\"hi\"}}\n</tool_call>") },
            // 重试后：返回正常结构化 toolCalls
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "",
                toolCalls: [LumiToolCall(id: "1", name: "noop", arguments: "{}")]) },
            // 工具执行后：非空完成
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Task done") },
        ])
        let toolService = NoOpToolService()
        let (service, conversationID) = try makeService(provider: provider, toolService: toolService)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(outcome == .completed)
        #expect(provider.callCount == 3)
        // 不应残留含内联工具调动的 assistant 消息（首次的已被重试替换）
        let messages = service.messages(for: conversationID)
        #expect(messages.contains(where: { $0.hasInlineToolCallInBody }) == false)
        // 不应出现 error fallback
        #expect(messages.contains(where: { $0.isError }) == false)
    }

    @Test("重试后仍内联 → turn failed，注入 fallback error 消息")
    func inlineExhaustedFailsWithFallback() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant,
                content: "<tool_call>{\"name\":\"noop\",\"arguments\":{}}</tool_call>") },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant,
                content: "<function_calls><invoke>noop</invoke></function_calls>") },
        ])
        let (service, conversationID) = try makeService(provider: provider)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(outcome == .failed)
        let messages = service.messages(for: conversationID)
        let fallback = messages.first { $0.metadata["lumi-inline-tool-call"] == "true" }
        #expect(fallback != nil)
        #expect(fallback?.isError == true)
        #expect(fallback?.role == .error)
    }

    @Test("正常工具流程不受影响")
    func normalToolFlowNotAffected() async throws {
        let provider = SequencedResponseMockProvider(responses: [
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "",
                toolCalls: [LumiToolCall(id: "1", name: "noop", arguments: "{}")]) },
            { req in LumiChatMessage(
                conversationID: req.messages.last?.conversationID ?? UUID(),
                role: .assistant, content: "Done") },
        ])
        let toolService = NoOpToolService()
        let (service, conversationID) = try makeService(provider: provider, toolService: toolService)
        service.append(LumiChatMessage(conversationID: conversationID, role: .user, content: "hi"))

        let outcome = try await service.runAgentTurn(conversationID: conversationID)

        #expect(provider.callCount == 2)
        #expect(outcome == .completed)
    }
}
