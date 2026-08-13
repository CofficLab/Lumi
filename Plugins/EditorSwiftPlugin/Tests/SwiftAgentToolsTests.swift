@testable import EditorSwiftPlugin
import AgentToolKit
import Foundation
import KernelLumi
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

@Test func generateXcodeProjectToolMetadataAndRisk() async {
    let tool = GenerateXcodeProjectTool()
    #expect(tool.name == "generate_xcode_project")
    #expect(tool.permissionRiskLevel(arguments: [:]) == .high)

    let args: [String: LumiJSONValue] = [
        "project_root": .string("/tmp/LumiProject/NewApp"),
    ]
    let allowedKernel = KernelLumi()
    let allowedState = LumiToolExecutionContextState(
        conversationID: UUID(),
        toolCallID: "call_1",
        toolName: tool.name,
        allowedDirectories: ["/tmp/LumiProject"]
    )
    #expect(try await allowedKernel.withToolExecutionContextState(allowedState) {
        tool.riskLevel(arguments: args, kernel: allowedKernel)
    } == .medium)

    let blockedKernel = KernelLumi()
    let blockedState = LumiToolExecutionContextState(
        conversationID: UUID(),
        toolCallID: "call_2",
        toolName: tool.name,
        allowedDirectories: ["/tmp/Other"]
    )
    #expect(try await blockedKernel.withToolExecutionContextState(blockedState) {
        tool.riskLevel(arguments: args, kernel: blockedKernel)
    } == .high)
}

@Test func generateXcodeProjectToolDisplayDescription() {
    let tool = GenerateXcodeProjectTool()
    let description = tool.displayDescription(arguments: [
        "project_name": .string("Demo"),
        "targets": .array([
            .object([
                "name": .string("Demo"),
                "kind": .string("app"),
            ])
        ]),
    ])
    #expect(description.contains("Demo"))
}

@Test func listSwiftPackagesToolRequiresProjectPath() async {
    let tool = ListSwiftPackagesTool()
    let context = LumiToolExecutionContextState(conversationID: UUID(), toolCallID: "call", toolName: tool.name)
    let kernel = KernelLumi()
    await #expect(throws: Error.self) {
        _ = try await kernel.withToolExecutionContextState(context) {
            try await tool.execute(arguments: [:], kernel: kernel)
        }
    }
}
