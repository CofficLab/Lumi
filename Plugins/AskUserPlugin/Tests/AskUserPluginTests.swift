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

    @Test("input schema has mode property")
    func schemaHasModeProperty() {
        guard case .object(let top) = tool.inputSchema,
              case .object(let properties) = top["properties"] else {
            Issue.record("schema should be object with properties")
            return
        }
        #expect(properties["mode"] != nil)
    }

    @Test("input schema requires question and mode")
    func schemaRequiresQuestionAndMode() {
        guard case .object(let top) = tool.inputSchema,
              case .array(let required) = top["required"] else {
            Issue.record("schema should be object with required array")
            return
        }
        #expect(required.contains(.string("question")))
        #expect(required.contains(.string("mode")))
    }

    @Test("default options are yes and no")
    func defaultOptionsAreYesNo() {
        #expect(AskUserTool.defaultOptions == [AskUserOption(label: "是"), AskUserOption(label: "否")])
    }

    @Test("allowed modes are exactly yes_no/choice/free_text")
    func allowedModesAreFixed() {
        #expect(AskUserTool.allowedModes == ["yes_no", "choice", "free_text"])
    }

    @Test("resolvedMode returns nil when missing")
    func resolvedModeNilWhenMissing() {
        #expect(AskUserTool.resolvedMode([:]) == nil)
    }

    @Test("resolvedMode rejects unknown values")
    func resolvedModeRejectsUnknown() {
        let args: [String: LumiJSONValue] = ["mode": .string("yes")]
        #expect(AskUserTool.resolvedMode(args) == nil)
    }

    @Test("resolvedMode accepts the three legal values")
    func resolvedModeAcceptsLegal() {
        for value in ["yes_no", "choice", "free_text"] {
            #expect(AskUserTool.resolvedMode(["mode": .string(value)]) == value)
        }
    }

    @Test("resolvedOptions forces yes/no for yes_no mode")
    func resolvedOptionsForYesNo() {
        // 即使误传 options，yes_no 也强制是/否
        let args: [String: LumiJSONValue] = ["options": .array([.string("A"), .string("B")])]
        #expect(AskUserTool.resolvedOptions(args, mode: "yes_no") == [AskUserOption(label: "是"), AskUserOption(label: "否")])
    }

    @Test("resolvedOptions is empty for free_text mode")
    func resolvedOptionsForFreeText() {
        let args: [String: LumiJSONValue] = ["options": .array([.string("A")])]
        #expect(AskUserTool.resolvedOptions(args, mode: "free_text") == [])
    }

    @Test("resolvedOptions uses provided strings for choice mode")
    func resolvedOptionsForChoice() {
        let args: [String: LumiJSONValue] = ["options": .array([.string("红"), .string("蓝")])]
        #expect(AskUserTool.resolvedOptions(args, mode: "choice") == [AskUserOption(label: "红"), AskUserOption(label: "蓝")])
    }

    @Test("resolvedOptions preserves structured objects with descriptions for choice mode")
    func resolvedOptionsForChoiceStructured() {
        // 回归测试：LLM 返回带 label+description 的对象数组，必须全部保留（旧实现会静默丢弃）。
        let args: [String: LumiJSONValue] = ["options": .array([
            .object([
                "label": .string("保留徽章+整栏底色"),
                "description": .string("右上角加 DEBUG 文字，整栏换成 warning 底色"),
            ]),
            .object([
                "label": .string("仅整栏换底色"),
                "description": .string("去掉徽章，只换背景色"),
            ]),
            .object([
                "label": .string("仅顶部细色条"),
            ]),
        ])]
        let result = AskUserTool.resolvedOptions(args, mode: "choice")
        #expect(result.count == 3)
        #expect(result[0].label == "保留徽章+整栏底色")
        #expect(result[0].description == "右上角加 DEBUG 文字，整栏换成 warning 底色")
        #expect(result[1].label == "仅整栏换底色")
        #expect(result[2].label == "仅顶部细色条")
        #expect(result[2].description == nil)
    }

    @Test("resolvedOptions accepts mixed string and object array for choice mode")
    func resolvedOptionsForChoiceMixed() {
        let args: [String: LumiJSONValue] = ["options": .array([
            .string("裸字符串选项"),
            .object(["label": .string("对象选项"), "description": .string("说明")]),
        ])]
        let result = AskUserTool.resolvedOptions(args, mode: "choice")
        #expect(result.count == 2)
        #expect(result[0] == AskUserOption(label: "裸字符串选项"))
        #expect(result[1] == AskUserOption(label: "对象选项", description: "说明"))
    }

    @Test("resolvedOptions skips options with neither label nor description")
    func resolvedOptionsSkipsBadElements() {
        // 非 string/object 元素、既无 label 又无 description 的对象被跳过；其余保留。
        let args: [String: LumiJSONValue] = ["options": .array([
            .int(123),
            .object(["description": .string("只有说明")]),
            .object(["color": .string("无关字段")]),
            .string("有效选项"),
        ])]
        let result = AskUserTool.resolvedOptions(args, mode: "choice")
        #expect(result == [AskUserOption(label: "只有说明"), AskUserOption(label: "有效选项")])
    }

    @Test("resolvedOptions preserves description-only objects (no label)")
    func resolvedOptionsForChoiceDescriptionOnly() {
        // 回归测试：LLM 合理地只给 description（选项本身即一句话），必须保留而非丢弃。
        let args: [String: LumiJSONValue] = ["options": .array([
            .object(["description": .string("拆为两个独立提交，每个单主题")]),
            .object(["description": .string("打包成一个提交（快但混合主题）")]),
        ])]
        let result = AskUserTool.resolvedOptions(args, mode: "choice")
        #expect(result.count == 2)
        // description 兜底为 label，且不重复作为副标题。
        #expect(result[0].label == "拆为两个独立提交，每个单主题")
        #expect(result[0].description == nil)
        #expect(result[1].label == "打包成一个提交（快但混合主题）")
        #expect(result[1].description == nil)
    }

    @Test("resolvedOptions returns empty (not default) when choice options all unparseable")
    func resolvedOptionsChoiceNoFallback() {
        // choice 解析失败时不再静默回退默认，由 execute 报错给 LLM 重试。
        let args: [String: LumiJSONValue] = ["options": .array([])]
        #expect(AskUserTool.resolvedOptions(args, mode: "choice") == [])
    }

    @Test("execute rejects missing mode")
    func executeRejectsMissingMode() async throws {
        let kernel = LumiKernel()
        let args: [String: LumiJSONValue] = ["question": .string("继续？")]
        let result = try await tool.execute(arguments: args, kernel: kernel)
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("mode is required"))
    }

    @Test("execute rejects unknown mode value")
    func executeRejectsUnknownMode() async throws {
        let kernel = LumiKernel()
        let args: [String: LumiJSONValue] = ["question": .string("继续？"), "mode": .string("maybe")]
        let result = try await tool.execute(arguments: args, kernel: kernel)
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("mode is required"))
    }

    @Test("execute rejects choice mode without options")
    func executeRejectsChoiceWithoutOptions() async throws {
        let kernel = LumiKernel()
        let args: [String: LumiJSONValue] = ["question": .string("选哪个？"), "mode": .string("choice")]
        let result = try await tool.execute(arguments: args, kernel: kernel)
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("mode=choice requires"))
    }

    @Test("execute rejects choice when all options are unparseable")
    func executeRejectsChoiceWithOnlyBadOptions() async throws {
        // 选项存在但全部无法解析（无 label/description）→ 报错给 LLM 重试，不偷换是/否。
        let kernel = LumiKernel()
        let args: [String: LumiJSONValue] = [
            "question": .string("怎么提交？"),
            "mode": .string("choice"),
            "options": .array([.int(1), .object(["color": .string("red")])]),
        ]
        let result = try await tool.execute(arguments: args, kernel: kernel)
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("mode=choice requires"))
    }

    @Test("execute rejects yes_no for open-ended question")
    func executeRejectsYesNoForOpenEnded() async throws {
        let kernel = LumiKernel()
        let args: [String: LumiJSONValue] = ["question": .string("冲突如何处理？"), "mode": .string("yes_no")]
        let result = try await tool.execute(arguments: args, kernel: kernel)
        #expect(result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("free_text"))
    }

    @Test("execute accepts yes_no for a real yes/no question")
    func executeAcceptsYesNoQuestion() async throws {
        let kernel = LumiKernel()
        let state = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "call-1",
            toolName: "ask_user",
            verbosity: "standard"
        )
        let args: [String: LumiJSONValue] = ["question": .string("是否继续构建？"), "mode": .string("yes_no")]
        let result = try await kernel.withToolExecutionContextState(state) {
            try await tool.execute(arguments: args, kernel: kernel)
        }
        #expect(!result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("\"mode\" : \"yes_no\""))
    }

    @Test("execute accepts free_text mode")
    func executeAcceptsFreeText() async throws {
        let kernel = LumiKernel()
        let state = LumiToolExecutionContextState(
            conversationID: UUID(),
            toolCallID: "call-2",
            toolName: "ask_user",
            verbosity: "standard"
        )
        let args: [String: LumiJSONValue] = ["question": .string("接下来怎么做？"), "mode": .string("free_text")]
        let result = try await kernel.withToolExecutionContextState(state) {
            try await tool.execute(arguments: args, kernel: kernel)
        }
        #expect(!result.hasPrefix("__ASK_USER_ERROR__"))
        #expect(result.contains("\"mode\" : \"free_text\""))
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

    @Test("lookLikeOpenEnded detects Chinese open-ended patterns")
    func detectChineseOpenEnded() {
        #expect(AskUserTool.lookLikeOpenEnded("接下来怎么走？"))
        #expect(AskUserTool.lookLikeOpenEnded("打包脚本修完了，下一步怎么办？"))
        #expect(AskUserTool.lookLikeOpenEnded("为什么要这样做？"))
        #expect(AskUserTool.lookLikeOpenEnded("如何改进这个功能？"))
        #expect(AskUserTool.lookLikeOpenEnded("告诉我你的想法"))
    }

    @Test("lookLikeOpenEnded detects English open-ended patterns")
    func detectEnglishOpenEnded() {
        #expect(AskUserTool.lookLikeOpenEnded("What should I do next?"))
        #expect(AskUserTool.lookLikeOpenEnded("How would you like to proceed?"))
        #expect(AskUserTool.lookLikeOpenEnded("Why does this happen?"))
        #expect(AskUserTool.lookLikeOpenEnded("Explain the build process"))
        #expect(AskUserTool.lookLikeOpenEnded("Tell me more"))
    }

    @Test("lookLikeOpenEnded returns false for yes/no questions")
    func noFalsePositiveForYesNo() {
        #expect(!AskUserTool.lookLikeOpenEnded("是否继续？"))
        #expect(!AskUserTool.lookLikeOpenEnded("Should I continue?"))
        #expect(!AskUserTool.lookLikeOpenEnded("Do you want to build?"))
    }

    @Test("encodePendingPayload produces pretty-printed JSON")
    func encodePendingPayloadIsPrettyPrinted() throws {
        let response = AskUserPendingResponse(
            toolCallId: "call-1",
            question: "继续？",
            options: [AskUserOption(label: "是"), AskUserOption(label: "否")],
            mode: "yes_no",
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
            options: [AskUserOption(label: "A"), AskUserOption(label: "B", description: "second")],
            mode: "choice",
            conversationId: UUID().uuidString,
            verbosity: "detailed"
        )
        let payload = try AskUserTool.encodePendingPayload(original)
        let data = payload.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AskUserPendingResponse.self, from: data)
        #expect(decoded.toolCallId == original.toolCallId)
        #expect(decoded.question == original.question)
        #expect(decoded.options == original.options)
        #expect(decoded.mode == original.mode)
        #expect(decoded.conversationId == original.conversationId)
        #expect(decoded.verbosity == original.verbosity)
    }

    @Test("pending payload without mode decodes (backward compat)")
    func pendingPayloadBackwardCompat() throws {
        // 旧 payload（无 mode 字段）必须能 decode，mode 为 nil，视图按 options 回退。
        let json = """
        {"toolCallId":"c1","question":"Continue?","options":["是","否"],"conversationId":"\(UUID().uuidString)","verbosity":"standard"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AskUserPendingResponse.self, from: data)
        #expect(decoded.mode == nil)
        #expect(decoded.options == [AskUserOption(label: "是"), AskUserOption(label: "否")])
    }

    @Test("AskUserOption encodes as bare string when description is nil")
    func optionEncodesAsBareString() throws {
        // 无 description 时编码为裸字符串，保持与旧 wire 格式一致。
        let encoded = try JSONEncoder().encode(AskUserOption(label: "是"))
        // 应为 JSON 字符串 "是"，而非对象
        #expect(String(decoding: encoded, as: UTF8.self) == "\"是\"")
    }

    @Test("AskUserOption encodes as object when description is present")
    func optionEncodesAsObject() throws {
        let encoded = try JSONEncoder().encode(AskUserOption(label: "方案A", description: "说明"))
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: String])
        #expect(json["label"] == "方案A")
        #expect(json["description"] == "说明")
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
        {"toolCallId":"c1","question":"Continue?","options":["是","否"],"mode":"yes_no","conversationId":"\(UUID().uuidString)","verbosity":"standard"}
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

// MARK: - Agent Turn Batch Tests

@Suite("AgentTurnBatch")
struct AgentTurnBatchTests {
    private let conversationID = UUID()

    @Test("a suspended tool is not terminal")
    func suspendedToolIsNotTerminal() {
        let suspension = AgentTurnSuspension(
            suspensionID: "suspension-1",
            conversationID: conversationID,
            toolCallID: "call-1",
            kind: "userInput",
            payload: "{}"
        )
        let call = LumiToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: LumiToolResult(
                content: "{}",
                turnControl: .suspend(suspension)
            )
        )

        #expect(!call.hasTerminalResult)
    }

    @Test("a resumed tool is terminal")
    func resumedToolIsTerminal() {
        let suspension = AgentTurnSuspension(
            suspensionID: "suspension-1",
            conversationID: conversationID,
            toolCallID: "call-1",
            kind: "userInput",
            payload: "{}"
        )
        let call = LumiToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: LumiToolResult(
                content: "{}",
                turnControl: .resumed(suspension, answer: "yes")
            )
        )

        #expect(call.hasTerminalResult)
    }

    @Test("a batch becomes terminal only after every tool is answered")
    func batchReadiness() {
        let firstSuspension = AgentTurnSuspension(
            suspensionID: "suspension-1",
            conversationID: conversationID,
            toolCallID: "call-1",
            kind: "userInput",
            payload: "{}"
        )
        let secondSuspension = AgentTurnSuspension(
            suspensionID: "suspension-2",
            conversationID: conversationID,
            toolCallID: "call-2",
            kind: "userInput",
            payload: "{}"
        )
        let first = LumiToolCall(
            id: "call-1",
            name: "ask_user",
            arguments: "{}",
            result: LumiToolResult(
                content: "{}",
                turnControl: .resumed(firstSuspension, answer: "yes")
            )
        )
        let secondWaiting = LumiToolCall(
            id: "call-2",
            name: "ask_user",
            arguments: "{}",
            result: LumiToolResult(
                content: "{}",
                turnControl: .suspend(secondSuspension)
            )
        )

        #expect(![first, secondWaiting].isTerminalToolBatch)

        let secondAnswered = LumiToolCall(
            id: "call-2",
            name: "ask_user",
            arguments: "{}",
            result: LumiToolResult(
                content: "{}",
                turnControl: .resumed(secondSuspension, answer: "no")
            )
        )
        #expect([first, secondAnswered].isTerminalToolBatch)
    }
}
