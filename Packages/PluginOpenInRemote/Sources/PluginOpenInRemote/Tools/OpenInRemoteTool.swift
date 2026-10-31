import Foundation
import KitAgentTool

/// 在默认浏览器中打开项目远程仓库的 Agent 工具。
///
/// 目标解析顺序与 Open In 家族一致：显式 `path` 参数 > 当前项目。
/// 只做「读 remote URL + 打开浏览器」，不修改仓库，风险等级为低。
struct OpenInRemoteTool: SuperAgentTool, @unchecked Sendable {
    /// 项目能力：提供当前项目路径。
    private let projectCapability: any OpenInRemoteProjectCapability
    /// 解析器：把仓库路径解析为远程仓库 Web 链接。
    private let resolver: RemoteRepositoryResolver

    init(
        projectCapability: any OpenInRemoteProjectCapability,
        resolver: RemoteRepositoryResolver
    ) {
        self.projectCapability = projectCapability
        self.resolver = resolver
    }

    var name: String { OpenInRemoteConstants.toolName }

    func description(for language: LanguagePreference) -> String {
        "Open the remote repository of the current project (or the given path) in the default browser."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Optional absolute path to a project. Defaults to the current project path.",
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let path = arguments["path"]?.value as? String, !path.isEmpty {
            return "在浏览器中打开 \(path) 的远程仓库"
        }
        return "在浏览器中打开当前项目的远程仓库"
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let explicitPath = arguments["path"]?.value as? String
        let currentProjectPath = await projectCapability.currentProjectPath

        guard let path = Self.resolvedTargetPath(
            explicitPath: explicitPath,
            currentProjectPath: currentProjectPath
        ) else {
            return """
            ## Open in Remote ❌

            **Status**: No project is open and no path was provided.
            """
        }

        guard let url = await resolver.webURL(forRepositoryAt: path) else {
            return """
            ## Open in Remote ❌

            **Path**: `\(path)`

            **Status**: No remote repository URL was found for this project.
            """
        }

        guard await MainActor.run(body: { RemoteRepositoryOpener.open(url) }) else {
            return """
            ## Open in Remote ❌

            **Path**: `\(path)`

            **Status**: The default browser could not be opened.
            """
        }

        return """
        ## Open in Remote ✅

        **Path**: `\(path)`

        **URL**: \(url.absoluteString)
        """
    }

    /// 解析目标路径：显式参数 > 当前项目路径。
    static func resolvedTargetPath(explicitPath: String?, currentProjectPath: String?) -> String? {
        if let explicitPath, !explicitPath.isEmpty { return explicitPath }
        return currentProjectPath
    }
}
