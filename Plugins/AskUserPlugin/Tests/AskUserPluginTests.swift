import AgentToolKit
import Foundation
import LumiKernel
import Testing
@testable import AskUserPlugin

// MARK: - AskUserPlugin Tests

@Suite("AskUserPlugin")
@MainActor
struct AskUserPluginTests {
    @Test("plugin id is stable")
    func pluginId() {
        let plugin = AskUserPlugin()
        #expect(plugin.id == "plugin-ask-user")
    }

    @Test("plugin order is 100")
    func pluginOrder() {
        let plugin = AskUserPlugin()
        #expect(plugin.order == 100)
    }

    @Test("plugin policy is alwaysOn")
    func pluginPolicy() {
        let plugin = AskUserPlugin()
        #expect(plugin.policy == .alwaysOn)
    }

    @Test("plugin name is AskUser")
    func pluginName() {
        let plugin = AskUserPlugin()
        #expect(plugin.name == "AskUser")
    }

    @Test("agentTools returns one tool named ask_user")
    func agentToolsReturnsAskUserTool() {
        let plugin = AskUserPlugin()
        let tools = plugin.agentTools(kernel: LumiKernel())
        #expect(tools.count == 1)
        #expect(tools.first?.name == "ask_user")
    }
}

// MARK: - AskUserTool Tests

@Suite("AskUserTool")
@MainActor
struct AskUserToolTests {
    let tool = AskUserTool()

    @Test("tool name is ask_user")
    func toolName() {
        #expect(tool.name == "ask_user")
    }

    @Test("tool id matches info id")
    func toolIdMatches() {
        #expect(tool.name == AskUserTool.info.id)
    }

    @Test("tool risk level is low")
    func riskLevelIsLow() {
        let kernel = LumiKernel()
        #expect(tool.riskLevel(arguments: [:], kernel: kernel) == .low)
    }

    @Test("input schema has question property")
    func schemaHasQuestionProperty() {
        guard case .object(let top) = tool.inputSchema,
              case .object(let properties) = top["properties"] else {
            Issue.record("schema should be object with properties")
            return
        }
        #expect(properties["question"] != nil)
    }

    @Test("input schema has options property")
    func schemaHasOptionsProperty() {
        guard case .object(let top) = tool.inputSchema,
              case .object(let properties) = top["properties"] else {
            Issue.record("schema should be object with properties")
            return
        }
        #expect(properties["options"] != nil)
    }

    @Test("input schema has allow_free_input property")
    func schemaHasAllowFreeInputProperty() {
        guard case .object(let top) = tool.inputSchema,
              case .object(let properties) = top["properties"] else {
            Issue.record("schema should be object with properties")
            return
        }
        #expect(properties["allow_free_input"] != nil)
    }

    @Test("input schema requires question")
    func schemaRequiresQuestion() {
        guard case .object(let top) = tool.inputSchema,
              case .array(let required) = top["required"] else {
            Issue.record("schema should be object with required array")
            return
        }
        #expect(required.contains(.string("question")))
    }

    @Test("default options are yes and no")
    func defaultOptionsAreYesNo() {
        #expect(AskUserTool.defaultOptions == ["是", "否"])
    }

    @Test("lookLikeMultipleChoice detects Chinese keywords")
    func detectChineseMultipleChoice() {
        #expect(AskUserTool.lookLikeMultipleChoice("选择哪个方案？"))
        #expect(AskUserTool.lookLikeMultipleChoice("哪个更好？"))
        #expect(AskUserTool.lookLikeMultipleChoice("有哪些选项？"))
    }

    @Test("lookLikeMultipleChoice detects English keywords")
    func detectEnglishMultipleChoice() {
        #expect(AskUserTool.lookLikeMultipleChoice("Which option should I choose?"))
        #expect(AskUserTool.lookLikeMultipleChoice("Select one of these"))
    }

    @Test("lookLikeMultipleChoice returns false for simple yes/no questions")
    func noFalsePositiveForSimpleQuestions() {
        #expect(!AskUserTool.lookLikeMultipleChoice("是否继续？"))
        #expect(!AskUserTool.lookLikeMultipleChoice("Do you want to proceed?"))
    }

    @Test("resolvedOptions returns default when missing")
    func resolvedOptionsDefaultsWhenMissing() {
        #expect(AskUserTool.resolvedOptions([:]) == ["是", "否"])
    }

    @Test("resolvedOptions returns default when empty array")
    func resolvedOptionsDefaultsWhenEmptyArray() {
        let args: [String: LumiJSONValue] = ["options": .array([])]
        #expect(AskUserTool.resolvedOptions(args) == ["是", "否"])
    }

    @Test("resolvedOptions returns provided options")
    func resolvedOptionsReturnsProvided() {
        let args: [String: LumiJSONValue] = ["options": .array([.string("红"), .string("蓝"), .string("绿")])]
        #expect(AskUserTool.resolvedOptions(args) == ["红", "蓝", "绿"])
    }

    @Test("resolvedAllowFreeInput defaults to false")
    func resolvedAllowFreeInputDefaultsFalse() {
        #expect(AskUserTool.resolvedAllowFreeInput([:]) == false)
    }

    @Test("resolvedAllowFreeInput returns true when set")
    func resolvedAllowFreeInputTrueWhenSet() {
        let args: [String: LumiJSONValue] = ["allow_free_input": .bool(true)]
        #expect(AskUserTool.resolvedAllowFreeInput(args) == true)
    }

    @Test("resolvedAllowFreeInput returns false for non-bool")
    func resolvedAllowFreeInputFalseForNonBool() {
        // A string that cannot be parsed as bool should return nil → fallback to false
        let args: [String: LumiJSONValue] = ["allow_free_input": .string("yesplease")]
        #expect(AskUserTool.resolvedAllowFreeInput(args) == false)
    }

    @Test("encodePendingPayload produces pretty-printed JSON")
    func encodePendingPayloadIsPrettyPrinted() throws {
        let response = AskUserPendingResponse(
            toolCallId: "call-1",
            question: "继续？",
            options: ["是", "否"],
            allowFreeInput: false,
            conversationId: "11111111-2222-3333-4444-555555555555",
            verbosity: "standard"
        )
        let payload = try AskUserTool.encodePendingPayload(response)
        #expect(payload.contains("\n")) // pretty-printed
        #expect(payload.contains("继续？"))
        #expect(payload.contains("call-1"))
    }

    @Test("encodePendingPayload round-trips through decoder")
    func encodePendingPayloadRoundTrips() throws {
        let original = AskUserPendingResponse(
            toolCallId: "call-rt",
            question: "Which?",
            options: ["A", "B"],
            allowFreeInput: true,
            conversationId: UUID().uuidString,
            verbosity: "detailed"
        )
        let payload = try AskUserTool.encodePendingPayload(original)
        let data = payload.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AskUserPendingResponse.self, from: data)
        #expect(decoded.toolCallId == original.toolCallId)
        #expect(decoded.question == original.question)
        #expect(decoded.options == original.options)
        #expect(decoded.allowFreeInput == original.allowFreeInput)
        #expect(decoded.conversationId == original.conversationId)
        #expect(decoded.verbosity == original.verbosity)
    }

    @Test("encodeErrorPayload contains error field")
    func encodeErrorPayloadContainsError() throws {
        let error = AskUserErrorResponse(error: "boom")
        let payload = try AskUserTool.encodeErrorPayload(error)
        #expect(payload.contains("boom"))
        #expect(payload.contains("error"))
    }

    @Test("errorResult starts with error prefix")
    func errorResultHasPrefix() {
        let result = AskUserTool.errorResult(message: "missing question")
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
    }

    @Test("errorResult JSON contains error message")
    func errorResultContainsMessage() {
        let result = AskUserTool.errorResult(message: "test error")
        #expect(result.contains("test error"))
    }
}

// MARK: - AskUserRowRenderer Tests

@Suite("AskUserRowRenderer")
struct AskUserRowRendererTests {
    @Test("id is stable")
    func rendererIdIsStable() {
        #expect(AskUserRowRenderer.id == "ask-user-row")
    }

    @Test("priority is 100")
    func rendererPriorityIsHigh() {
        #expect(AskUserRowRenderer.priority == 100)
    }

    @Test("parsePendingResponse returns nil for malformed content")
    func parseReturnsNilForMissingPrefix() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "no JSON here")
        #expect(result == nil)
    }

    @Test("parsePendingResponse returns nil for empty string")
    func parseReturnsNilForEmpty() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "")
        #expect(result == nil)
    }

    @Test("parsePendingResponse returns nil for empty JSON")
    func parseReturnsNilForPrefixOnly() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "")
        #expect(result == nil)
    }

    @Test("parsePendingResponse returns nil for malformed JSON")
    func parseReturnsNilForMalformedJSON() {
        let result = AskUserRowRenderer.parsePendingResponse(from: "{not json}")
        #expect(result == nil)
    }

    @Test("parsePendingResponse decodes valid payload")
    func parseDecodesValid() {
        let payload = """
        {"toolCallId":"c1","question":"Continue?","options":["是","否"],"allowFreeInput":false,"conversationId":"\(UUID().uuidString)","verbosity":"standard"}
        """
        let result = AskUserRowRenderer.parsePendingResponse(from: payload)
        #expect(result != nil)
        #expect(result?.question == "Continue?")
        #expect(result?.verbosity == "standard")
    }

    @Test("canRender returns true for ask_user with awaitingUserResponse")
    func canRenderForAskUserPending() {
        let toolCall = ToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: ToolCallResult(
                content: "{}",
                awaitingUserResponse: true,
                interactionState: .waiting
            )
        )
        let renderer = AskUserRowRenderer()
        #expect(renderer.canRender(toolCall: toolCall))
    }

    @Test("canRender returns false for other tool name")
    func canRenderFalseForOtherTool() {
        let toolCall = ToolCall(
            id: "call-1",
            name: "other_tool",
            arguments: "{}",
            result: ToolCallResult(
                content: "result",
                awaitingUserResponse: true
            )
        )
        let renderer = AskUserRowRenderer()
        #expect(!renderer.canRender(toolCall: toolCall))
    }

    @Test("canRender returns false when awaitingUserResponse is false")
    func canRenderFalseWhenNotAwaiting() {
        let toolCall = ToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: ToolCallResult(
                content: "normal result",
                awaitingUserResponse: false
            )
        )
        let renderer = AskUserRowRenderer()
        #expect(!renderer.canRender(toolCall: toolCall))
    }

    @Test("canRender returns false when result is nil")
    func canRenderFalseWhenResultNil() {
        let toolCall = ToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: nil
        )
        let renderer = AskUserRowRenderer()
        #expect(!renderer.canRender(toolCall: toolCall))
    }
}

// MARK: - AskUserBridge Tests

@Suite("AskUserBridge")
@MainActor
struct AskUserBridgeTests {
    @Test("shared instance exists")
    func sharedInstanceExists() {
        _ = AskUserBridge.shared
    }

    @Test("shared instance is same object")
    func sharedInstanceIsSingleton() {
        #expect(AskUserBridge.shared === AskUserBridge.shared)
    }

}
