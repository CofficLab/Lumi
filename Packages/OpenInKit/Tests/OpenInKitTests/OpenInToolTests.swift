import Foundation
import KitAgentTool
import ProviderProject
import Testing
@testable import OpenInKit

@Test func presetConfigurationsKeepStableToolNamesAndFallbacks() {
    let configurations: [OpenInTool.AppConfig] = [
        OpenInTool.finder,
        OpenInTool.xcode,
        OpenInTool.cursor,
        OpenInTool.vscode,
        OpenInTool.antigravity,
        OpenInTool.gitHubDesktop,
        OpenInTool.gitOK,
    ]

    #expect(configurations.map(\.toolName) == [
        "open_in_finder",
        "open_in_xcode",
        "open_in_cursor",
        "open_in_vscode",
        "open_in_antigravity",
        "open_in_github_desktop",
        "open_in_gitok",
    ])
    #expect(configurations.allSatisfy { !$0.displayName.isEmpty && !$0.fallbackPath.isEmpty })
    #expect(configurations.allSatisfy { $0.opensURLs })
}

@Test func toolMetadataDeclaresOptionalPathAndLowRisk() {
    let tool = OpenInTool(config: OpenInTool.finder, project: nil)
    let schema = tool.inputSchema(for: LanguagePreference.english)
    let properties = schema["properties"] as? [String: Any]
    let pathSchema = properties?["path"] as? [String: Any]
    let pathType = pathSchema?["type"] as? String

    #expect(tool.name == "open_in_finder")
    #expect(tool.description(for: LanguagePreference.english).contains("Finder"))
    #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    #expect(tool.displayDescription(for: [:]) == "在 Finder 中打开当前项目")
    #expect(tool.displayDescription(for: ["path": ToolArgument("/tmp/Example")]) == "在 Finder 中打开 /tmp/Example")
    #expect(schema["type"] as? String == "object")
    #expect(pathType == "string")
    #expect(schema["required"] == nil)
}

@Test func explicitPathOverridesProjectAndEmptyPathFallsBack() {
    #expect(OpenInTool.resolvedTargetPath(
        explicitPath: "/workspace/Other",
        currentProjectPath: "/workspace/Current"
    ) == "/workspace/Other")
    #expect(OpenInTool.resolvedTargetPath(
        explicitPath: "",
        currentProjectPath: "/workspace/Current"
    ) == "/workspace/Current")
    #expect(OpenInTool.resolvedTargetPath(explicitPath: nil, currentProjectPath: nil) == nil)
}

@Test @MainActor func executionReturnsReadableErrorWhenNoPathOrProjectExists() async throws {
    let tool = OpenInTool(config: OpenInTool.finder, project: DefaultProjectProvider())

    let result = try await tool.execute(arguments: [:])

    #expect(result.contains("No project is open and no path was provided"))
    #expect(result.contains("Open in Finder"))
}
