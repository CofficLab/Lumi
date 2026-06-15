import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import AskUserPlugin

// MARK: - InputSchema Tests

@Suite struct AskUserToolInputSchemaTests {
    let tool = AskUserTool()

    @Test func schemaTypeIsObject() {
        let schema = tool.inputSchema
        #expect(schema["type"] as? String == "object")
    }

    @Test func schemaHasQuestionProperty() {
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        #expect(properties?["question"] != nil)
    }

    @Test func schemaQuestionTypeIsString() {
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        let question = properties?["question"] as? [String: Any]
        #expect(question?["type"] as? String == "string")
    }

    @Test func schemaHasOptionsProperty() {
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        let options = properties?["options"] as? [String: Any]
        #expect(options != nil)
        #expect(options?["type"] as? String == "array")
    }

    @Test func schemaOptionsItemsAreStrings() {
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        let options = properties?["options"] as? [String: Any]
        let items = options?["items"] as? [String: Any]
        #expect(items?["type"] as? String == "string")
    }

    @Test func schemaHasAllowFreeInputProperty() {
        let schema = tool.inputSchema
        let properties = schema["properties"] as? [String: Any]
        let allowFreeInput = properties?["allow_free_input"] as? [String: Any]
        #expect(allowFreeInput != nil)
        #expect(allowFreeInput?["type"] as? String == "boolean")
    }

    @Test func schemaRequiredContainsQuestion() {
        let schema = tool.inputSchema
        let required = schema["required"] as? [String]
        #expect(required?.contains("question") == true)
    }
}

// MARK: - DisplayDescription Tests

@Suite struct AskUserToolDisplayDescriptionTests {
    let tool = AskUserTool()

    @Test func showsQuestionInDescription() {
        let args: [String: ToolArgument] = ["question": .init("测试问题")]
        let desc = tool.displayDescription(for: args)
        #expect(desc.contains("测试问题"))
    }

    @Test func truncatesLongQuestion() {
        let longQuestion = String(repeating: "a", count: 100)
        let args: [String: ToolArgument] = ["question": .init(longQuestion)]
        let desc = tool.displayDescription(for: args)
        #expect(desc.count <= 60) // "询问: " + 50 chars
    }

    @Test func fallbackWhenNoQuestion() {
        let args: [String: ToolArgument] = [:]
        let desc = tool.displayDescription(for: args)
        #expect(desc == "询问用户")
    }
}

// MARK: - RiskLevel Tests

@Suite struct AskUserToolRiskLevelTests {
    let tool = AskUserTool()

    @Test func riskLevelIsLow() {
        let args: [String: ToolArgument] = [:]
        #expect(tool.permissionRiskLevel(arguments: args) == .low)
    }
}

// MARK: - Description Tests

@Suite struct AskUserToolDescriptionTests {
    let tool = AskUserTool()

    @Test func chineseDescriptionContainsAsk() {
        let desc = tool.description(for: .chinese)
        #expect(desc.contains("询问") || desc.contains("提问"))
    }

    @Test func englishDescriptionContainsAsk() {
        let desc = tool.description(for: .english)
        #expect(desc.lowercased().contains("ask"))
    }
}

// MARK: - Name Tests

@Suite struct AskUserToolNameTests {
    @Test func toolNameIsAskUser() {
        #expect(AskUserTool.name == "ask_user")
        let tool = AskUserTool()
        #expect(tool.name == "ask_user")
    }

    @Test func pendingPrefixMatchesLumiMarkers() {
        #expect(AskUserTool.pendingPrefix == LumiAskUserMarkers.pendingPrefix)
    }
}

// MARK: - Helpers

private func makeContext(
    conversationId: UUID = UUID(),
    toolCallId: String = "call-test"
) -> ToolExecutionContext {
    ToolExecutionContext(
        conversationId: conversationId,
        toolCallId: toolCallId,
        toolName: "ask_user"
    )
}

// MARK: - Execute Tests

@Suite struct AskUserToolExecuteTests {
    let tool = AskUserTool()

    @Test func executeReturnsPendingPrefix() async throws {
        let args: [String: ToolArgument] = ["question": .init("测试问题")]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.hasPrefix(LumiAskUserMarkers.pendingPrefix))
    }

    @Test func executeContainsJSONWithQuestion() async throws {
        let args: [String: ToolArgument] = ["question": .init("是否继续？")]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.contains("是否继续？"))
    }

    @Test func executeContainsDefaultOptions() async throws {
        let args: [String: ToolArgument] = ["question": .init("是否继续？")]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.contains("是"))
        #expect(result.contains("否"))
    }

    @Test func executeWithCustomOptions() async throws {
        let args: [String: ToolArgument] = [
            "question": .init("选哪个？"),
            "options": .init(["红色", "蓝色", "绿色"])
        ]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.contains("红色"))
        #expect(result.contains("蓝色"))
        #expect(result.contains("绿色"))
    }

    @Test func executeReturnsErrorWhenQuestionMissing() async throws {
        let args: [String: ToolArgument] = [:]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.hasPrefix(LumiAskUserMarkers.errorPrefix))
        #expect(result.contains("question"))
    }

    @Test func executeReturnsErrorWhenQuestionEmpty() async throws {
        let args: [String: ToolArgument] = ["question": .init("")]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.hasPrefix(LumiAskUserMarkers.errorPrefix))
    }

    @Test func executeContainsToolCallId() async throws {
        let args: [String: ToolArgument] = ["question": .init("测试")]
        let result = try await tool.execute(arguments: args, context: makeContext(toolCallId: "call-unique-id"))
        #expect(result.contains("call-unique-id"))
    }

    @Test func executeContainsConversationId() async throws {
        let conversationId = UUID()
        let args: [String: ToolArgument] = ["question": .init("测试")]
        let result = try await tool.execute(arguments: args, context: makeContext(conversationId: conversationId))
        #expect(result.contains(conversationId.uuidString))
    }

    @Test func executeWithAllowFreeInput() async throws {
        let args: [String: ToolArgument] = [
            "question": .init("你的想法？"),
            "allow_free_input": .init(true)
        ]
        let result = try await tool.execute(arguments: args, context: makeContext())
        #expect(result.contains("true"))
    }
}

// MARK: - ErrorResult Tests

@Suite struct AskUserToolErrorResultTests {
    @Test func errorResultStartsWithErrorPrefix() {
        let result = AskUserTool.errorResult(message: "test error")
        #expect(result.hasPrefix(LumiAskUserMarkers.errorPrefix))
    }

    @Test func errorResultContainsMessage() {
        let result = AskUserTool.errorResult(message: "something went wrong")
        #expect(result.contains("something went wrong"))
    }
}

// MARK: - Response Model Tests

@Suite struct AskUserResponseModelTests {
    @Test func pendingResponseEncodable() throws {
        let response = AskUserPendingResponse(
            toolCallId: "call-1",
            question: "测试",
            options: ["是", "否"],
            allowFreeInput: false,
            conversationId: UUID().uuidString
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["question"] as? String == "测试")
        #expect(json?["toolCallId"] as? String == "call-1")
    }

    @Test func errorResponseEncodable() throws {
        let response = AskUserErrorResponse(error: "出错")
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["error"] as? String == "出错")
    }
}
