import Foundation
import Testing
@testable import KitAgentTool

/// 历史工具调用参数裁剪（Issue #1053）。
///
/// `show_html` 这类展示型工具的原始参数只服务于当次显示；后续回合若继续
/// 逐字回传给模型，大载荷会持续占用上下文。裁剪必须做到三件事：
/// 只动声明的键、保留其余参数、任何异常输入都原样返回。
@Suite("工具调用上下文参数裁剪")
struct ToolCallContextArgumentsTests {

    @Test("只替换声明的键，其余参数保持不变")
    func replacesOnlyRequestedKey() throws {
        let arguments = #"{"html":"<html><body>SECRET_MARKER</body></html>","title":"Report","width":800}"#

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: ["html"])

        #expect(!scrubbed.contains("SECRET_MARKER"))
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(scrubbed.utf8)) as? [String: Any]
        )
        #expect(object["html"] as? String == ToolCallContextArguments.omissionPlaceholder)
        #expect(object["title"] as? String == "Report")
        #expect(object["width"] as? Int == 800)
    }

    @Test("没有声明要移除的键时原样返回")
    func emptyOmissionSetReturnsOriginal() {
        let arguments = #"{"html":"<html></html>"}"#

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: [])

        #expect(scrubbed == arguments)
    }

    @Test("参数里没有目标键时原样返回")
    func missingKeyReturnsOriginal() {
        let arguments = #"{"title":"Report"}"#

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: ["html"])

        #expect(scrubbed == arguments)
    }

    @Test("非法 JSON 原样返回，不破坏历史")
    func invalidJSONReturnsOriginal() {
        let arguments = "html=<html></html>,title=Report"

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: ["html"])

        #expect(scrubbed == arguments)
    }

    @Test("非对象 JSON 原样返回")
    func nonObjectJSONReturnsOriginal() {
        let arguments = #"["html","title"]"#

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: ["html"])

        #expect(scrubbed == arguments)
    }

    @Test("裁剪结果仍是合法 JSON 对象")
    func scrubbedOutputRemainsValidJSONObject() {
        let arguments = #"{"html":"<html></html>"}"#

        let scrubbed = ToolCallContextArguments.scrubbed(arguments, omitting: ["html"])

        let object = try? JSONSerialization.jsonObject(with: Data(scrubbed.utf8)) as? [String: Any]
        #expect(object?["html"] != nil)
    }

    @Test("存在类型上调用也命中工具自己的声明")
    func existentialDispatchUsesToolDeclaration() {
        let tool: any SuperAgentTool = OmittedArgumentTool()

        #expect(tool.contextOmittedArgumentKeys == ["html"])
        #expect(DemoArgumentsTool().contextOmittedArgumentKeys.isEmpty)
    }
}

private struct OmittedArgumentTool: SuperAgentTool {
    let name = "omitted_tool"

    var contextOmittedArgumentKeys: Set<String> { ["html"] }

    func description(for language: LanguagePreference) -> String { "Omitted tool" }

    func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Omit html" }
}

private struct DemoArgumentsTool: SuperAgentTool {
    let name = "demo_arguments_tool"

    func description(for language: LanguagePreference) -> String { "Demo tool" }

    func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }

    func displayDescription(for arguments: [String: ToolArgument]) -> String { "Run demo" }
}
