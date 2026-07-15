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
            conversationId: UUID().uuidString,
            verbosity: "standard"
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


// MARK: - Pure Static Helpers Tests
//
// 覆盖 AskUserTool 内部纯静态函数：resolvedOptions / resolvedAllowFreeInput /
// buildPendingResponse / encodePendingPayload / encodeErrorPayload / defaultOptions。
// 这些函数已被 extract 成 static，便于在不带 ToolCall 的轻量单元测试里复用。

@Suite struct AskUserToolResolvedOptionsTests {
    @Test func returnsDefaultWhenArgumentsEmpty() {
        let result = AskUserTool.resolvedOptions([:])
        #expect(result == AskUserTool.defaultOptions)
    }

    @Test func returnsDefaultWhenOptionsMissing() {
        let args: [String: ToolArgument] = ["question": .init("x")]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == AskUserTool.defaultOptions)
    }

    @Test func returnsDefaultWhenOptionsIsEmptyArray() {
        // 空数组应当回退到默认，而不是返回空列表（避免渲染器无选项可显示）
        let args: [String: ToolArgument] = ["options": .init([] as [String])]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == AskUserTool.defaultOptions)
    }

    @Test func returnsDefaultWhenOptionsIsNotStringArray() {
        // 非 [String] 类型（如 [Int]）也应回退到默认
        let args: [String: ToolArgument] = ["options": .init([1, 2, 3])]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == AskUserTool.defaultOptions)
    }

    @Test func returnsProvidedOptionsWhenNonEmpty() {
        let provided = ["红", "蓝", "绿"]
        let args: [String: ToolArgument] = ["options": .init(provided)]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == provided)
    }

    @Test func preservesOrderOfProvidedOptions() {
        let provided = ["c", "a", "b"]
        let args: [String: ToolArgument] = ["options": .init(provided)]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == provided)
    }

    @Test func allowsDuplicateOptionStrings() {
        // 重复字符串不在 resolvedOptions 的处理范围内，按原样透传（去重是上层职责）
        let provided = ["是", "是", "否"]
        let args: [String: ToolArgument] = ["options": .init(provided)]
        let result = AskUserTool.resolvedOptions(args)
        #expect(result == provided)
    }
}

@Suite struct AskUserToolResolvedAllowFreeInputTests {
    @Test func returnsFalseWhenArgumentsEmpty() {
        // 默认行为：缺失 allow_free_input 时为 false（与 defaultOptions 不同，
        // 这是显式保守选择，避免误让用户输入任意文本）。
        let result = AskUserTool.resolvedAllowFreeInput([:])
        #expect(result == false)
    }

    @Test func returnsFalseWhenKeyMissing() {
        let args: [String: ToolArgument] = ["question": .init("x")]
        let result = AskUserTool.resolvedAllowFreeInput(args)
        #expect(result == false)
    }

    @Test func returnsTrueWhenExplicitlyTrue() {
        let args: [String: ToolArgument] = ["allow_free_input": .init(true)]
        let result = AskUserTool.resolvedAllowFreeInput(args)
        #expect(result == true)
    }

    @Test func returnsFalseWhenExplicitlyFalse() {
        let args: [String: ToolArgument] = ["allow_free_input": .init(false)]
        let result = AskUserTool.resolvedAllowFreeInput(args)
        #expect(result == false)
    }

    @Test func returnsFalseWhenNonBoolValue() {
        // 非 Bool 值（如 Int / String）应回退到 false，而不是崩溃
        let intArgs: [String: ToolArgument] = ["allow_free_input": .init(1)]
        #expect(AskUserTool.resolvedAllowFreeInput(intArgs) == false)

        let stringArgs: [String: ToolArgument] = ["allow_free_input": .init("true")]
        #expect(AskUserTool.resolvedAllowFreeInput(stringArgs) == false)
    }
}

@Suite struct AskUserToolDefaultOptionsTests {
    @Test func defaultOptionsIsChineseYesNo() {
        // 默认选项固定为 ["是", "否"]，是 AskUserBriefView 渲染快捷按钮的依据，
        // 改动会影响 UI 行为，列入测试防止回退。
        #expect(AskUserTool.defaultOptions == ["是", "否"])
    }

    @Test func defaultOptionsIsNotEmpty() {
        #expect(!AskUserTool.defaultOptions.isEmpty)
    }
}

@Suite struct AskUserToolBuildPendingResponseTests {
    let conversationId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test func copiesAllFieldsFromInputs() {
        let context = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: "call-abc",
            toolName: "ask_user",
            verbosity: "detailed"
        )
        let response = AskUserTool.buildPendingResponse(
            context: context,
            question: "是否继续?",
            options: ["是", "否"],
            allowFreeInput: true
        )
        #expect(response.toolCallId == "call-abc")
        #expect(response.question == "是否继续?")
        #expect(response.options == ["是", "否"])
        #expect(response.allowFreeInput == true)
        #expect(response.conversationId == conversationId.uuidString)
    }

    @Test func verbosityPassesThroughWhenContextProvidesIt() {
        for verbosity in ["brief", "standard", "detailed", "v1", "v2", "v3"] {
            let context = ToolExecutionContext(
                conversationId: conversationId,
                toolCallId: "call",
                toolName: "ask_user",
                verbosity: verbosity
            )
            let response = AskUserTool.buildPendingResponse(
                context: context,
                question: "q",
                options: ["a"],
                allowFreeInput: false
            )
            #expect(response.verbosity == verbosity, "verbosity mismatch for \(verbosity)")
        }
    }

    @Test func verbosityDefaultsToStandardWhenContextOmitsIt() {
        // 源码契约：context.verbosity == nil 时，buildPendingResponse 必须默认回退到 "standard"。
        // 这是渲染器路分发（standard → AskUserStandardView）的关键安全网。
        let context = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: "call",
            toolName: "ask_user",
            verbosity: nil
        )
        let response = AskUserTool.buildPendingResponse(
            context: context,
            question: "q",
            options: ["a"],
            allowFreeInput: false
        )
        #expect(response.verbosity == "standard")
    }

    @Test func emptyOptionsArrayAllowed() {
        // buildPendingResponse 不做 options 校验（那是 resolvedOptions 的职责），
        // 它应当透传调用方传入的任意数组，包括空数组。
        let context = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: "call",
            toolName: "ask_user"
        )
        let response = AskUserTool.buildPendingResponse(
            context: context,
            question: "q",
            options: [],
            allowFreeInput: true
        )
        #expect(response.options.isEmpty)
    }
}

@Suite struct AskUserToolEncodePayloadTests {
    @Test func encodePendingPayloadProducesPrettyJSON() throws {
        let response = AskUserPendingResponse(
            toolCallId: "call-1",
            question: "测试",
            options: ["是", "否"],
            allowFreeInput: false,
            conversationId: "11111111-2222-3333-4444-555555555555",
            verbosity: "standard"
        )
        let payload = try AskUserTool.encodePendingPayload(response)
        // prettyPrinted 输出含换行与缩进
        #expect(payload.contains("\n"))
        #expect(payload.contains("\"question\" : \"测试\"") || payload.contains("\"question\": \"测试\""))
        #expect(payload.contains("call-1"))
    }

    @Test func encodePendingPayloadRoundTripViaDecoder() throws {
        // 编码产物应当能被同一模型解码回来 —— 这是 JSON payload 在 ToolCallExecutor
        // 与渲染器之间传输的契约。
        let original = AskUserPendingResponse(
            toolCallId: "call-rt",
            question: "Round trip?",
            options: ["yes", "no"],
            allowFreeInput: true,
            conversationId: UUID().uuidString,
            verbosity: "detailed"
        )
        let payload = try AskUserTool.encodePendingPayload(original)
        let data = payload.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AskUserPendingResponse.self, from: data)
        // AskUserPendingResponse 未实现 Equatable，逐字段断言等价。
        #expect(decoded.toolCallId == original.toolCallId)
        #expect(decoded.question == original.question)
        #expect(decoded.options == original.options)
        #expect(decoded.allowFreeInput == original.allowFreeInput)
        #expect(decoded.conversationId == original.conversationId)
        #expect(decoded.verbosity == original.verbosity)
    }

    @Test func encodeErrorPayloadContainsErrorField() throws {
        let error = AskUserErrorResponse(error: "boom")
        let payload = try AskUserTool.encodeErrorPayload(error)
        #expect(payload.contains("boom"))
        #expect(payload.contains("error"))
    }
}

@Suite struct AskUserToolErrorResultPayloadTests {
    @Test func errorResultContainsEncodedJSONError() {
        // errorResult 应当把 error message 编码进 JSON（而不是直接拼接裸字符串），
        // 以保证渲染器可以解析。
        let result = AskUserTool.errorResult(message: "missing field")
        #expect(result.hasPrefix(LumiAskUserMarkers.errorPrefix))

        let body = result.dropFirst("\(LumiAskUserMarkers.errorPrefix)\n".count)
        let data = body.data(using: .utf8)!
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["error"] as? String == "missing field")
    }

    @Test func errorResultIsStableForSameMessage() {
        // errorResult 应是幂等的：相同输入产生相同输出（不含 UUID 等随机字段）。
        let first = AskUserTool.errorResult(message: "deterministic")
        let second = AskUserTool.errorResult(message: "deterministic")
        #expect(first == second)
    }
}
