import Foundation
import LumiCoreKit
import Testing
@testable import AgentToolKit

private struct MockBridgeTool: SuperAgentTool {
    let name = "mock_bridge_tool"

    func description(for language: LanguagePreference) -> String {
        "Mock bridge tool"
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Search query",
                ]
            ],
            "required": ["query"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Run mock tool"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let query = arguments["query"]?.value as? String else {
            return "missing query"
        }
        return "ok:\(query):\(context.currentProjectPath ?? "")"
    }
}

@Test func superAgentToolBridgeExposesUnderlyingMetadata() {
    let bridge = MockBridgeTool().asLumiAgentTool()

    #expect(bridge.name == "mock_bridge_tool")
    #expect(bridge.toolDescription == "Mock bridge tool")
    #expect(bridge.inputSchema.anyValue is [String: Any])
}

@Test func superAgentToolBridgeExecutesWithConvertedContext() async throws {
    let bridge = MockBridgeTool().asLumiAgentTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-1",
        toolName: bridge.name,
        currentProjectPath: "/tmp/project"
    )

    let output = try await bridge.execute(
        arguments: ["query": .string("hello")],
        context: context
    )

    #expect(output == "ok:hello:/tmp/project")
}

@Test func superAgentToolBridgeMapsRiskLevel() {
    let bridge = MockBridgeTool().asLumiAgentTool()

    #expect(bridge.riskLevel(arguments: [:], context: nil) == .low)
}
