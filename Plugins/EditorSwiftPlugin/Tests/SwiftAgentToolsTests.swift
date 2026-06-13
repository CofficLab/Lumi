@testable import EditorSwiftPlugin
import AgentToolKit
import Foundation
import Testing

@Test func addSwiftPackageToolMetadata() {
    let tool = AddSwiftPackageTool()
    #expect(tool.name == "add_xcode_package")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
    #expect(!tool.description(for: .english).isEmpty)
    #expect((tool.inputSchema(for: .english)["required"] as? [String])?.contains("project_path") == true)
}

@Test func listSwiftPackagesToolMetadata() {
    let tool = ListSwiftPackagesTool()
    #expect(tool.name == "list_xcode_packages")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    #expect((tool.inputSchema(for: .english)["required"] as? [String])?.contains("project_path") == true)
}

@Test func generateXcodeProjectToolMetadataAndRisk() {
    let tool = GenerateXcodeProjectTool()
    #expect(tool.name == "generate_xcode_project")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .high)

    let allowedContext = ToolExecutionContext(
        conversationId: UUID(),
        toolCallId: "call_1",
        toolName: tool.name,
        allowedDirectories: ["/tmp/LumiProject"]
    )
    let args: [String: ToolArgument] = [
        "project_root": ToolArgument("/tmp/LumiProject/NewApp"),
    ]
    #expect(tool.permissionRiskLevel(arguments: args, context: allowedContext) == .medium)

    let blockedContext = ToolExecutionContext(
        conversationId: UUID(),
        toolCallId: "call_2",
        toolName: tool.name,
        allowedDirectories: ["/tmp/Other"]
    )
    #expect(tool.permissionRiskLevel(arguments: args, context: blockedContext) == .high)
}

@Test func generateXcodeProjectToolDisplayDescription() {
    let tool = GenerateXcodeProjectTool()
    let description = tool.displayDescription(for: [
        "project_name": ToolArgument("Demo"),
        "targets": ToolArgument([["name": "Demo", "kind": "app"]]),
    ])
    #expect(description.contains("Demo"))
}

@Test func listSwiftPackagesToolRequiresProjectPath() async {
    let tool = ListSwiftPackagesTool()
    let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call", toolName: tool.name)
    await #expect(throws: Error.self) {
        _ = try await tool.execute(arguments: [:], context: context)
    }
}
