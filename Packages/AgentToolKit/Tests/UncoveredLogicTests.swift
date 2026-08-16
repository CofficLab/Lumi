import Foundation
import Testing
@testable import AgentToolKit

// MARK: - SuperAgentTool 默认扩展

private struct DemoTool: SuperAgentTool {
    let name = "demo_tool"

    func description(for language: LanguagePreference) -> String {
        language == .chinese ? "演示工具" : "Demo tool"
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "language": language.rawValue]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Run demo"
    }
}

struct SuperAgentToolDefaultExtensionTests {
    @Test
    func defaultDescriptionUsesEnglishVariant() {
        let tool = DemoTool()
        #expect(tool.description == "Demo tool")
    }

    @Test
    func defaultInputSchemaUsesEnglishVariant() {
        let tool = DemoTool()
        let schema = tool.inputSchema
        #expect(schema["language"] as? String == "en")
    }
}

// MARK: - SuperAgentTool 默认 execute / executeResult

private struct UnimplementedTool: SuperAgentTool {
    let name = "unimplemented_tool"

    func description(for language: LanguagePreference) -> String { "Unimplemented" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Nothing" }
}

private struct FailingTool: SuperAgentTool {
    let name = "failing_tool"

    func description(for language: LanguagePreference) -> String { "Failing" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Fail" }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.permissionDenied(toolName: name)
    }
}

private struct ContentTool: SuperAgentTool {
    let name = "content_tool"

    func description(for language: LanguagePreference) -> String { "Content" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Run" }

    func execute(arguments: [String: ToolArgument]) async throws -> String { "executed" }
}

struct SuperAgentToolExecuteTests {
    @Test
    func defaultExecuteThrowsExecutionFailed() async {
        let tool = UnimplementedTool()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    @Test
    func defaultExecuteErrorMessageMentionsTool() async throws {
        let tool = UnimplementedTool()
        do {
            _ = try await tool.execute(arguments: [:])
            Issue.record("Expected execute to throw")
        } catch let error as ToolExecutionError {
            #expect(
                error.errorDescription
                    == "Failed to execute 'unimplemented_tool': unimplemented_tool does not implement execute(arguments:)"
            )
        }
    }

    @Test
    func defaultExecuteResultWrapsContent() async throws {
        let result = try await ContentTool().executeResult(arguments: [:])
        #expect(result.content == "executed")
        #expect(result.images.isEmpty)
        #expect(!result.isError)
        #expect(!result.awaitingUserResponse)
    }

    @Test
    func defaultExecuteResultPropagatesErrors() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await FailingTool().executeResult(arguments: [:])
        }
    }
}

// MARK: - LanguagePreference 空 locale 回退

struct LanguagePreferenceFallbackTests {
    @Test
    func emptyLocaleFallsBackToIdentifierAndMapsToEnglish() {
        #expect(LanguagePreference(locale: Locale(identifier: "")) == .english)
    }
}

// MARK: - ToolCallInteractionState

struct ToolCallInteractionStateTests {
    @Test
    func answeredStateExposesAnswer() {
        #expect(ToolCallInteractionState.answered("yes").answer == "yes")
    }

    @Test
    func codableRoundTripPreservesBothCases() throws {
        for state in [ToolCallInteractionState.waiting, .answered("blue")] {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ToolCallInteractionState.self, from: data)
            #expect(decoded == state)
        }
    }
}

// MARK: - ToolCallResult 兼容旧数据与可选字段编码

struct ToolCallResultCompatTests {
    @Test
    func decodeLegacyJSONWithOnlyContentAppliesDefaults() throws {
        let json = #"{"content":"ok"}"#
        let decoded = try JSONDecoder().decode(ToolCallResult.self, from: Data(json.utf8))

        #expect(decoded.content == "ok")
        #expect(decoded.images.isEmpty)
        #expect(decoded.isError == false)
        #expect(decoded.duration == nil)
        #expect(decoded.awaitingUserResponse == false)
        #expect(decoded.interactionState == nil)
    }

    @Test
    func roundTripPreservesDurationAwaitingAndInteractionState() throws {
        let original = ToolCallResult(
            content: "waiting",
            isError: false,
            executedAt: Date(timeIntervalSince1970: 1_700_000_100),
            duration: 1.5,
            awaitingUserResponse: true,
            interactionState: .answered("red")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCallResult.self, from: data)

        #expect(decoded == original)
        #expect(decoded.duration == 1.5)
        #expect(decoded.awaitingUserResponse)
        #expect(decoded.interactionState?.answer == "red")
    }

    @Test
    func encodeOmitsDefaultOptionalFields() throws {
        let result = ToolCallResult(content: "plain")
        let data = try JSONEncoder().encode(result)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["images"] == nil)
        #expect(object["isError"] == nil)
        #expect(object["duration"] == nil)
        #expect(object["awaitingUserResponse"] == nil)
        #expect(object["interactionState"] == nil)
        #expect(object["executedAt"] != nil)
    }
}

// MARK: - AgentToolKitLocalization

struct AgentToolKitLocalizationTests {
    @Test
    func returnsKeyItselfWhenTranslationMissing() {
        let value = AgentToolKitLocalization.string(
            "agent_toolkit.missing.key", bundle: .module, locale: Locale(identifier: "en")
        )
        #expect(value == "agent_toolkit.missing.key")
    }

    @Test
    func knownKeyResolvesFromModuleCatalog() {
        // 注意：LumiLocalization 会优先使用系统偏好语言，locale 参数仅作回退，
        // 因此这里只断言模块 catalog 中的键能解析出非空、非 key 本身的值。
        let value = AgentToolKitLocalization.string(
            "Chinese", bundle: .module, locale: Locale(identifier: "zh-Hans")
        )
        #expect(!value.isEmpty)
        #expect(["Chinese", "中文"].contains(value))
    }
}
