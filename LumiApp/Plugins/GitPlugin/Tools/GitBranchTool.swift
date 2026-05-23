import Foundation
import AgentToolKit

/// Git 分支管理工具
struct GitBranchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔀"
    nonisolated static let verbose: Bool = false
    let name = "git_branch"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出、创建或切换 Git 分支。不传 action 时默认列出本地分支。"
        case .english:
            return "List, create, or switch Git branches. Defaults to listing local branches when no action is specified."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let actionDesc: String
        let nameDesc: String
        let remoteDesc: String

        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            actionDesc = "操作类型：list（列出分支，默认）、create（创建分支）、checkout（切换分支）"
            nameDesc = "分支名称（create/checkout 时必填）"
            remoteDesc = "是否包含远程分支（仅 list 有效），默认 false"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            actionDesc = "Action: list (default), create, or checkout"
            nameDesc = "Branch name (required for create/checkout)"
            remoteDesc = "Whether to include remote branches (list only), default false"
        }

        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc,
                ],
                "action": [
                    "type": "string",
                    "enum": ["list", "create", "checkout"],
                    "description": actionDesc,
                ],
                "name": [
                    "type": "string",
                    "description": nameDesc,
                ],
                "remote": [
                    "type": "boolean",
                    "description": remoteDesc,
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let action = arguments["action"]?.value as? String else { return .low }
        switch action {
        case "list": return .low
        case "create", "checkout": return .medium
        default: return .low
        }
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String
        let action = arguments["action"]?.value as? String ?? "list"
        let name = arguments["name"]?.value as? String
        let remote = arguments["remote"]?.value as? Bool ?? false

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)分支操作：\(action) name=\(name ?? "nil")")
        }

        switch action {
        case "list":
            return try await listBranches(path: path, remote: remote)
        case "create":
            guard let name else {
                throw NSError(domain: "GitBranchTool", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "创建分支需要指定 name 参数"])
            }
            return try await createBranch(path: path, name: name)
        case "checkout":
            guard let name else {
                throw NSError(domain: "GitBranchTool", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "切换分支需要指定 name 参数"])
            }
            return try await checkoutBranch(path: path, name: name)
        default:
            throw NSError(domain: "GitBranchTool", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "不支持的操作：\(action)"])
        }
    }

    // MARK: - List Branches

    private func listBranches(path: String?, remote: Bool) async throws -> String {
        let repoPath = resolvePath(path)
        let localBranches = GitBranchService.listLocalBranches(at: repoPath)
        let currentBranch = GitBranchService.currentBranch(at: repoPath)

        var output = "## Git 分支列表\n\n"

        // 本地分支
        output += "### 本地分支\n"
        for branch in localBranches {
            let marker = branch.name == currentBranch ? " ← **当前**" : ""
            output += "- `\(branch.name)`\(marker)\n"
        }
        output += "\n"

        // 远程分支
        if remote {
            let remoteBranches = GitBranchService.listRemoteBranches(at: repoPath)
            if !remoteBranches.isEmpty {
                output += "### 远程分支\n"
                for branch in remoteBranches {
                    output += "- `\(branch.name)`\n"
                }
                output += "\n"
            }
        }

        return output
    }

    // MARK: - Create Branch

    private func createBranch(path: String?, name: String) async throws -> String {
        let repoPath = resolvePath(path)
        try GitBranchService.createBranch(name, at: repoPath)

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)已创建并切换到分支：\(name)")
        }

        return "✅ 已创建并切换到分支 `\(name)`"
    }

    // MARK: - Checkout Branch

    private func checkoutBranch(path: String?, name: String) async throws -> String {
        let repoPath = resolvePath(path)

        if GitBranchService.isWorkingTreeDirty(at: repoPath) {
            return "⚠️ 工作区有未提交的变更，建议先提交或 stash 后再切换分支。\n\n如仍要切换，请使用命令行操作。"
        }

        try GitBranchService.checkout(branch: name, at: repoPath)

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)已切换到分支：\(name)")
        }

        return "✅ 已切换到分支 `\(name)`"
    }

    // MARK: - Helper

    private func resolvePath(_ path: String?) -> String {
        path ?? FileManager.default.currentDirectoryPath
    }
}
