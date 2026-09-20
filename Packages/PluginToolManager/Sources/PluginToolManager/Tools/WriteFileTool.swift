import KitAgentTool
import Foundation

/// 写入文件。
public struct WriteFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "write_file"
    public let executionCapability: ToolExecutionCapability = .serialSideEffect
    private let workspaceRootProvider: @MainActor @Sendable () -> String?

    public init(
        workspaceRootProvider: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.workspaceRootProvider = workspaceRootProvider
    }

    public func description(for language: LanguagePreference) -> String {
        "Write UTF-8 text content to a file."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute or workspace-relative path to the file"],
                "content": ["type": "string", "description": "UTF-8 text content to write"],
            ],
            "required": ["path", "content"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "写入文件" }
        return "写入 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(arguments: arguments, workspaceRootOverride: nil)
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let workspaceRoot = await context.conversationProjectPath()
        let content = try await execute(arguments: arguments, workspaceRootOverride: workspaceRoot)
        return ToolCallResult(content: content)
    }

    private func execute(
        arguments: [String: ToolArgument],
        workspaceRootOverride: String?
    ) async throws -> String {
        guard let path = arguments.stringValue("path"),
              let content = arguments.stringValue("content")
        else {
            throw NSError(domain: "WriteFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing path or content"])
        }

        let defaultRoot = await workspaceRootProvider()
        let url = WorkspacePathResolver.resolve(
            path: path,
            workspaceRoot: workspaceRootOverride ?? defaultRoot
        )
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "Wrote \(content.count) characters to \(path)"
    }
}
