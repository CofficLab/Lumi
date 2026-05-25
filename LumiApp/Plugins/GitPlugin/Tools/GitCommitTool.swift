import Foundation
import AgentToolKit

/// Git 提交工具
struct GitCommitTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = true
    let name = "git_commit"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "提交 Git 变更。支持指定提交信息、添加特定文件，或修改最后一次提交。在提交前，建议先根据最近的 commit 历史确定提交风格，以保持一致性。重要：应按主题提交变更，确保每个提交只包含相关的逻辑变更。如果变更涉及多个不相关的主题，请拆分成多个独立的提交。"
        case .english:
            return "Commit Git changes. Supports specifying commit message, adding specific files, or amending the last commit. Before committing, it's recommended to first examine recent commit history to determine the commit style for consistency. Important: Commit changes by topic, ensuring each commit contains only related logical changes. If changes involve multiple unrelated topics, split them into separate commits."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let messageDesc: String
        let filesDesc: String
        let amendDesc: String
        
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            messageDesc = "提交信息（必填）。应遵循项目的 commit 风格（如 feat:、fix:、chore: 等前缀），建议先查看最近的 commit 历史确定风格。重要：应按主题提交变更，确保每个提交只包含相关的逻辑变更。如果变更涉及多个不相关的主题，请拆分成多个独立的提交。"
            filesDesc = "要添加的文件路径列表（可选），空数组表示添加所有变更"
            amendDesc = "是否修改最后一次提交（可选），默认为 false"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            messageDesc = "Commit message (required). Should follow the project's commit style (e.g., feat:, fix:, chore: prefixes). It's recommended to first check recent commit history to determine the style. Important: Commit changes by topic, ensuring each commit contains only related logical changes. If changes involve multiple unrelated topics, split them into separate commits."
            filesDesc = "List of file paths to add (optional), empty array means add all changes"
            amendDesc = "Whether to amend the last commit (optional), default false"
        }
        
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc,
                ],
                "message": [
                    "type": "string",
                    "description": messageDesc,
                ],
                "files": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": filesDesc,
                ],
                "amend": [
                    "type": "boolean",
                    "description": amendDesc,
                ],
            ],
            "required": ["message"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "提交变更"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium // 提交会修改代码库，风险中等
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String
        guard let message = arguments["message"]?.value as? String else {
            throw NSError(domain: "GitCommitTool", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "缺少必需的提交信息参数"])
        }
        
        let files = arguments["files"]?.value as? [String] ?? []
        let amend = arguments["amend"]?.value as? Bool ?? false
        
        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)执行 Git 提交：\(message)")
        }
        
        do {
            let result = try await GitService.shared.commit(
                path: path,
                message: message,
                files: files,
                amend: amend
            )
            return formatCommitResult(result)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)Git 提交失败：\(error.localizedDescription)")
            }
            return "Git 提交失败：\(error.localizedDescription)"
        }
    }

    private func formatCommitResult(_ result: GitCommitResult) -> String {
        var output = "## Git 提交成功 ✅\n\n"
        output += "**提交哈希**: `\(result.hash)`\n\n"
        output += "**提交信息**: \(result.message)\n\n"
        output += "**作者**: \(result.author) <\(result.email)>\n\n"
        output += "**时间**: \(result.date)\n\n"
        
        if !result.changedFiles.isEmpty {
            output += "### 变更文件\n"
            for file in result.changedFiles {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }
        
        return output
    }
}
