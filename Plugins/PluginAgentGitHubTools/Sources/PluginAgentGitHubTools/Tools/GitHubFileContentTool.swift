import Foundation
import SuperLogKit
import AgentToolKit
import GitHubKit

/// GitHub 文件内容获取工具
public struct GitHubFileContentTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true
    public let name = "github_file_content"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取 GitHub 仓库中指定文件的内容。支持读取 README、源代码文件等。"
        case .english:
            return "Get the content of a specific file in a GitHub repository. Supports README files, source files, and similar text files."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        switch language {
        case .chinese:
            return [
                "type": "object",
                "properties": [
                    "owner": [
                        "type": "string",
                        "description": "仓库所有者"
                    ],
                    "repo": [
                        "type": "string",
                        "description": "仓库名称"
                    ],
                    "path": [
                        "type": "string",
                        "description": "文件路径（如 README.md、src/main.swift）"
                    ],
                    "branch": [
                        "type": "string",
                        "description": "分支名称，默认为 main"
                    ]
                ],
                "required": ["owner", "repo", "path"]
            ]
        case .english:
            return [
                "type": "object",
                "properties": [
                    "owner": [
                        "type": "string",
                        "description": "Repository owner"
                    ],
                    "repo": [
                        "type": "string",
                        "description": "Repository name"
                    ],
                    "path": [
                        "type": "string",
                        "description": "File path (e.g., README.md, src/main.swift)"
                    ],
                    "branch": [
                        "type": "string",
                        "description": "Branch name, defaults to main"
                    ]
                ],
                "required": ["owner", "repo", "path"]
            ]
        }
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "查看文件内容"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数"]
            )
        }

        let branch = arguments["branch"]?.value as? String ?? "main"

        if Self.verbose {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.info("\(self.t)获取文件：\(owner)/\(repo)/\(path)")
            }
        }

        do {
            let fileContent = try await GitHubAPIService.shared.getFileContent(
                owner: owner,
                repo: repo,
                path: path,
                branch: branch
            )

            guard let content = fileContent.decodedContent else {
                return "无法解码文件内容"
            }

            return "📄 **\(fileContent.name)**\n\n```\(content)```"
        } catch {
            if GitHubToolsPlugin.verbose {
                            GitHubToolsPlugin.logger.error("\(self.t)获取文件失败：\(error.localizedDescription)")
            }
            return "获取文件失败：\(error.localizedDescription)"
        }
    }
}
