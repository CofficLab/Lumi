import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 分支管理工具
public struct GitBranchTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔀"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "git_branch",
        displayName: "Git Branch",
        description: "List, create, or switch Git branches. Defaults to listing local branches when no action is specified."
    )
    public static let tags: Set<LumiToolTag> = [.git, .destructive]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path, defaults to current working directory"),
                ]),
                "action": .object([
                    "type": .string("string"),
                    "enum": .array([.string("list"), .string("create"), .string("checkout")]),
                    "description": .string("Action: list (default), create, or checkout"),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Branch name (required for create/checkout)"),
                ]),
                "remote": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include remote branches (list only), default false"),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let action = arguments.string("action") ?? "list"
        switch action {
        case "create": return "创建分支"
        case "checkout": return "切换分支"
        default: return "查看分支"
        }
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        guard let action = arguments.string("action") else { return .low }
        switch action {
        case "list": return .low
        case "create", "checkout": return .medium
        default: return .low
        }
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")
        let action = arguments.string("action") ?? "list"
        let name = arguments.string("name")
        let remote = arguments.bool("remote") ?? false

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)分支操作：\(action) name=\(name ?? "nil")")
        }

        // 验证路径是否在允许的范围内
        let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

        switch action {
        case "list":
            return try await listBranches(path: validatedPath, remote: remote)
        case "create":
            guard let name else {
                throw NSError(domain: "GitBranchTool", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "创建分支需要指定 name 参数"])
            }
            return try await createBranch(path: validatedPath, name: name)
        case "checkout":
            guard let name else {
                throw NSError(domain: "GitBranchTool", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "切换分支需要指定 name 参数"])
            }
            return try await checkoutBranch(path: validatedPath, name: name)
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
