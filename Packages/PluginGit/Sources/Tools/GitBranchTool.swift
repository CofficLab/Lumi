import Foundation
import KitAgentTool
import ProviderProject

/// 查看、创建、切换 Git 分支。
public struct GitBranchV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_branch"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "List, create, or switch Git branches. Defaults to listing local branches when no action is specified." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "action": ["type": "string", "enum": ["list", "create", "checkout"], "description": "Action: list (default), create, or checkout."], "name": ["type": "string", "description": "Branch name (required for create/checkout)."], "remote": ["type": "boolean", "description": "Whether to include remote branches (list only), default false."]]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { switch GitV2ToolSupport.string(arguments, "action") ?? "list" { case "create": "创建分支"; case "checkout": "切换分支"; default: "查看分支" } }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { switch GitV2ToolSupport.string(arguments, "action") ?? "list" { case "create", "checkout": .medium; default: .low } }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = try await GitV2ToolSupport.path(arguments, project: project)
        switch GitV2ToolSupport.string(arguments, "action") ?? "list" {
        case "list":
            let current = GitBranchService.currentBranch(at: path)
            var output = "## Git 分支列表\n\n### 本地分支\n" + GitBranchService.listLocalBranches(at: path).map { "- `\($0.name)`\($0.name == current ? " ← **当前**" : "")\n" }.joined() + "\n"
            if GitV2ToolSupport.bool(arguments, "remote") ?? false {
                let remote = GitBranchService.listRemoteBranches(at: path)
                if !remote.isEmpty { output += "### 远程分支\n" + remote.map { "- `\($0.name)`\n" }.joined() + "\n" }
            }
            return output
        case "create":
            guard let name = GitV2ToolSupport.string(arguments, "name") else { return "创建分支需要指定 name 参数" }
            try GitBranchService.createBranch(name, at: path)
            return "✅ 已创建并切换到分支 `\(name)`"
        case "checkout":
            guard let name = GitV2ToolSupport.string(arguments, "name") else { return "切换分支需要指定 name 参数" }
            guard !GitBranchService.isWorkingTreeDirty(at: path) else { return "⚠️ 工作区有未提交的变更，建议先提交或 stash 后再切换分支。\n\n如仍要切换，请使用命令行操作。" }
            try GitBranchService.checkout(branch: name, at: path)
            return "✅ 已切换到分支 `\(name)`"
        default: return "不支持的操作：\(GitV2ToolSupport.string(arguments, "action") ?? "")"
        }
    }
}