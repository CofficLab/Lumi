import AgentToolKit
import Foundation
import LumiKernel
import Testing
@testable import AskUserPlugin

// MARK: - Bridge Identity Tests
//
// `AskUserTool().asLumiAgentTool()` 把 legacy SuperAgentTool 适配为 LumiAgentTool，
// 验证桥接后的 metadata（name / toolDescription / inputSchema）来源全部是 underlying tool。

@Suite struct AskUserToolBridgeIdentityTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func bridgeNameMatchesAskUserTool() {
        #expect(bridge.name == "ask_user")
        #expect(bridge.name == AskUserTool.name)
    }

    @Test func bridgeDescriptionMatchesAskUserToolChinese() {
        // 默认语言为 english，所以 description 应与 english 分支一致
        let desc = bridge.toolDescription
        #expect(desc.lowercased().contains("ask"))
        // 桥接器直接取 description() 在 default language 的输出，
        // 不能依赖 zh/en 切换的具体字符串，避免 i18n 漂移。
        #expect(!desc.isEmpty)
    }

    @Test func bridgeInputSchemaPreservesProperties() {
        let schema = bridge.inputSchema
        // 顶层 type
        guard case let .object(top) = schema,
              case let .string(type) = top["type"]
        else {
            Issue.record("顶层 schema 不是 object{type:string}")
            return
        }
        #expect(type == "object")

        // properties.question.type == "string"
        guard case let .object(properties) = top["properties"],
              case let .object(question) = properties["question"] ?? .null,
              case let .string(questionType) = question["type"] ?? .null
        else {
            Issue.record("properties.question 路径不对")
            return
        }
        #expect(questionType == "string")

        // properties.options.items.type == "string"
        guard case let .object(options) = properties["options"] ?? .null,
              case let .object(items) = options["items"] ?? .null,
              case let .string(itemsType) = items["type"] ?? .null
        else {
            Issue.record("properties.options.items 路径不对")
            return
        }
        #expect(itemsType == "string")

        // properties.allow_free_input.type == "boolean"
        guard case let .object(allowFree) = properties["allow_free_input"] ?? .null,
              case let .string(allowFreeType) = allowFree["type"] ?? .null
        else {
            Issue.record("properties.allow_free_input 路径不对")
            return
        }
        #expect(allowFreeType == "boolean")

        // required 包含 "question"
        guard case let .array(required) = top["required"] ?? .null else {
            Issue.record("required 不是 array")
            return
        }
        #expect(required.contains(.string("question")))
    }
}

// MARK: - Bridge Execute Tests
//
// execute() 必须把 LumiToolExecutionContext / LumiJSONValue 转回 legacy ToolExecutionContext / ToolArgument，
// 再把结果原样透传。这是给 plugin 注册路径用的，必须保证参数无损。

@Suite struct AskUserToolBridgeExecuteTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func executeReturnsPendingPrefix() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-bridge-1",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("是否继续?")],
            context: context
        )
        #expect(output.hasPrefix(LumiAskUserMarkers.pendingPrefix))
    }

    @Test func executeUsesDefaultOptionsWhenNotProvided() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-bridge-default",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("是否继续?")],
            context: context
        )
        // 默认 options = ["是", "否"]，出现在 JSON 中
        #expect(output.contains("是"))
        #expect(output.contains("否"))
    }

    @Test func executeUsesCustomOptionsWhenProvided() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-bridge-custom",
            toolName: "ask_user"
        )
        let options: LumiJSONValue = .array([.string("红"), .string("蓝"), .string("绿")])
        let output = try await bridge.execute(
            arguments: [
                "question": .string("选哪个?"),
                "options": options,
            ],
            context: context
        )
        #expect(output.contains("红"))
        #expect(output.contains("蓝"))
        #expect(output.contains("绿"))
    }

    @Test func executePropagatesAllowFreeInput() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-bridge-free",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: [
                "question": .string("你的想法?"),
                "allow_free_input": .bool(true),
            ],
            context: context
        )
        #expect(output.contains("\"allowFreeInput\" : true") || output.contains("\"allowFreeInput\": true"))
    }

    @Test func executeIncludesToolCallIDFromContext() async throws {
        let conversationId = UUID()
        let context = LumiToolExecutionContext(
            conversationID: conversationId,
            toolCallID: "call-unique-9999",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("test")],
            context: context
        )
        #expect(output.contains("call-unique-9999"))
        #expect(output.contains(conversationId.uuidString))
    }

    @Test func executeIncludesVerbosityFromContext() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call",
            toolName: "ask_user",
            verbosity: "v3"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("test")],
            context: context
        )
        // verbosity 字段出现在 JSON 里
        #expect(output.contains("\"verbosity\" : \"v3\"") || output.contains("\"verbosity\": \"v3\""))
    }

    @Test func executeDefaultsVerbosityToStandardWhenContextOmits() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call",
            toolName: "ask_user",
            verbosity: nil
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("test")],
            context: context
        )
        // nil → "standard" fallback
        #expect(output.contains("\"verbosity\" : \"standard\"") || output.contains("\"verbosity\": \"standard\""))
    }
}

// MARK: - Bridge Error Path Tests
//
// 桥接器对错误应当透传：underyling tool 走 error 分支时，
// 输出仍以 errorPrefix 开头，error 内容编码为 JSON。

@Suite struct AskUserToolBridgeErrorPathTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func executeReturnsErrorPrefixWhenQuestionMissing() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-err",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: [:],
            context: context
        )
        #expect(output.hasPrefix(LumiAskUserMarkers.errorPrefix))
        #expect(output.contains("question"))
    }

    @Test func executeReturnsErrorPrefixWhenQuestionEmpty() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-err-empty",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("")],
            context: context
        )
        #expect(output.hasPrefix(LumiAskUserMarkers.errorPrefix))
    }

    @Test func executeReturnsErrorPrefixWhenQuestionNotString() async throws {
        // question 传成 .int 而不是 .string — underlying tool 用 `as? String` 转换失败，
        // 应当走 error path（这是 adapter 的隐式契约：错误输入不能崩）。
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-err-int",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .int(42)],
            context: context
        )
        #expect(output.hasPrefix(LumiAskUserMarkers.errorPrefix))
    }

    @Test func errorResultJSONContainsErrorMessage() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call-err-json",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: [:],
            context: context
        )
        // 解析 errorPrefix 之后的 JSON body
        let body = output.dropFirst("\(LumiAskUserMarkers.errorPrefix)\n".count)
        let data = body.data(using: .utf8)!
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["error"] is String)
    }
}

// MARK: - Bridge Risk Level Tests
//
// permissionRiskLevel = .low 在两个协议层都成立。adapter 应当无损转换。

@Suite struct AskUserToolBridgeRiskLevelTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func riskLevelIsLowForEmptyArgs() {
        #expect(bridge.riskLevel(arguments: [:], context: nil) == .low)
    }

    @Test func riskLevelIsLowForArbitraryArgs() {
        let args: [String: LumiJSONValue] = [
            "question": .string("anything"),
            "options": .array([.string("a"), .string("b")]),
            "allow_free_input": .bool(true),
        ]
        #expect(bridge.riskLevel(arguments: args, context: nil) == .low)
    }

    @Test func riskLevelAcceptsContextWithoutCrashing() {
        // 验证 context 可选时也安全：调用方可能传 nil context
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "call",
            toolName: "ask_user"
        )
        _ = bridge.riskLevel(arguments: [:], context: context)
    }
}

// MARK: - Bridge Display Description Tests
//
// displayDescription 应保留 underlying tool 的截断行为：长问题被截断到 50 字符。

@Suite struct AskUserToolBridgeDisplayDescriptionTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func displayDescriptionContainsQuestion() {
        let desc = bridge.displayDescription(arguments: ["question": .string("测试问题")])
        #expect(desc.contains("测试问题"))
    }

    @Test func displayDescriptionTruncatesLongQuestion() {
        let long = String(repeating: "a", count: 100)
        let desc = bridge.displayDescription(arguments: ["question": .string(long)])
        // underlying: "询问: " + question.prefix(50)，所以总长 <= 60
        #expect(desc.count <= 60)
    }

    @Test func displayDescriptionFallbackForMissingQuestion() {
        let desc = bridge.displayDescription(arguments: [:])
        // underlying 在缺失 question 时返回 "询问用户"
        #expect(desc == "询问用户")
    }

    @Test func displayDescriptionCoercesNonStringQuestion() {
        // 非 String question 在 underlying 里 `as? String` 失败，应走 fallback
        let desc = bridge.displayDescription(arguments: ["question": .int(123)])
        #expect(desc == "询问用户")
    }
}

// MARK: - Bridge Context Conversion Tests
//
// 验证 LumiToolExecutionContext → ToolExecutionContext 的字段透传。
// 直接验证路径：传入 allowedDirectories / currentProjectPath / verbosity，
// 然后让 execute 输出 JSON，看这些字段在 payload 里是否仍存在。

@Suite struct AskUserToolBridgeContextConversionTests {
    let bridge = AskUserTool().asLumiAgentTool()

    @Test func executePropagatesConversationID() async throws {
        let conversationId = UUID()
        let context = LumiToolExecutionContext(
            conversationID: conversationId,
            toolCallID: "call-ctx",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("x")],
            context: context
        )
        #expect(output.contains(conversationId.uuidString))
    }

    @Test func executePropagatesToolCallID() async throws {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "ctx-tool-call-id-42",
            toolName: "ask_user"
        )
        let output = try await bridge.execute(
            arguments: ["question": .string("x")],
            context: context
        )
        #expect(output.contains("ctx-tool-call-id-42"))
    }

    @Test func executePropagatesVerbosityAcrossAllSupportedValues() async throws {
        for verbosity in ["v1", "v2", "v3", "brief", "standard", "detailed"] {
            let context = LumiToolExecutionContext(
                conversationID: UUID(),
                toolCallID: "call",
                toolName: "ask_user",
                verbosity: verbosity
            )
            let output = try await bridge.execute(
                arguments: ["question": .string("x")],
                context: context
            )
            // verbosity 字符串原样出现在 JSON body
            let needle = "\"verbosity\" : \"\(verbosity)\""
            let altNeedle = "\"verbosity\": \"\(verbosity)\""
            #expect(
                output.contains(needle) || output.contains(altNeedle),
                "verbosity \(verbosity) not propagated"
            )
        }
    }
}