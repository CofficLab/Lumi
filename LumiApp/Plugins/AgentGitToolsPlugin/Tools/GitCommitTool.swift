import Foundation

/// Git 提交工具
struct GitCommitTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = false
    let name = "git_commit"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "提交 Git 变更。支持指定提交信息、添加特定文件，或修改最后一次提交。"
        case .english:
            return "Commit Git changes. Supports specifying commit message, adding specific files, or amending the last commit."
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
            messageDesc = "提交信息（必填）"
            filesDesc = "要添加的文件路径列表（可选），空数组表示添加所有变更"
            amendDesc = "是否修改最后一次提交（可选），默认为 false"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            messageDesc = "Commit message (required)"
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

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium // 提交会修改代码库，风险中等
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String
        guard let message = arguments["message"]?.value as? String else {
            throw NSError(domain: "GitCommitTool", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "缺少必需的提交信息参数"])
        }
        
        let files = arguments["files"]?.value as? [String] ?? []
        let amend = arguments["amend"]?.value as? Bool ?? false
        
        if Self.verbose {
            if GitToolsPlugin.verbose {
                GitToolsPlugin.logger.info("\(Self.t)执行 Git 提交：\(message)")
            }
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
            if GitToolsPlugin.verbose {
                GitToolsPlugin.logger.error("\(Self.t)Git 提交失败：\(error.localizedDescription)")
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