import AgentToolKit
import Foundation
import ProviderProject

enum GitV2ToolNames {
    static let all = ["git_status", "git_diff", "git_log", "git_show", "git_branch", "git_commit", "git_unpushed"]
}

private enum GitV2ToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func bool(_ arguments: [String: ToolArgument], _ key: String) -> Bool? {
        guard let value = arguments[key]?.value else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return Bool(string) }
        return nil
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func strings(_ arguments: [String: ToolArgument], _ key: String) -> [String] {
        guard let value = arguments[key]?.value else { return [] }
        if let strings = value as? [String] { return strings }
        if let values = value as? [Any] { return values.compactMap { $0 as? String } }
        return []
    }

    @MainActor
    static func path(_ arguments: [String: ToolArgument], project: (any ProjectProviding)?) throws -> String {
        let requested = string(arguments, "path")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = requested?.isEmpty == false
            ? requested
            : project?.currentProject?.path
        return try GitService.validatePath(candidate, allowedDirectories: [])
    }

    static func schema(_ properties: [String: Any], required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties, "additionalProperties": false]
        if !required.isEmpty { schema["required"] = required }
        return schema
    }

    static func pathProperty() -> [String: Any] {
        ["type": "string", "description": "Git repository path, defaults to the current project directory."]
    }
}

public struct GitStatusV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_status"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "Get the current status of a Git repository, including branch info and file changes. Returns structured JSON data." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty()]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看 Git 状态" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        do { return format(try await GitService.shared.getStatus(path: GitV2ToolSupport.path(arguments, project: project))) }
        catch { return "获取 Git 状态失败：\(error.localizedDescription)" }
    }
    private func format(_ status: GitStatus) -> String {
        var output = "## Git 仓库状态\n\n**分支**: `\(status.branch)`\n\n"
        if let remote = status.remote { output += "**远程**: `\(remote)`\n\n" }
        for (title, files) in [("修改的文件", status.modified), ("新增的文件", status.added), ("删除的文件", status.deleted), ("重命名文件", status.renamed), ("已暂存的文件", status.staged)] where !files.isEmpty {
            output += "### \(title)\n" + files.map { "- `\($0)`\n" }.joined() + "\n"
        }
        if status.modified.isEmpty && status.added.isEmpty && status.deleted.isEmpty && status.renamed.isEmpty && status.staged.isEmpty { output += "✅ 工作区干净，无变更\n" }
        return output
    }
}

public struct GitDiffV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_diff"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "View code changes in a Git repository. Supports working tree changes and staged changes." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "staged": ["type": "boolean", "description": "Whether to view staged changes. false means viewing working tree changes."], "file": ["type": "string", "description": "Optional, only view changes for the specified file."]]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看代码变更" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        do {
            let path = try await GitV2ToolSupport.path(arguments, project: project)
            let target = try resolveTarget(path: path, file: GitV2ToolSupport.string(arguments, "file"))
            let diff = try await GitService.shared.getDiff(path: target.repositoryPath, staged: GitV2ToolSupport.bool(arguments, "staged") ?? false, file: target.file)
            guard !diff.isEmpty else { return "✅ 没有变更" }
            var output = "## Git 变更\n\n"
            if let stats = diff.stats { output += "**变更统计**: \(stats.filesChanged) 个文件，+\(stats.insertions) 行，-\(stats.deletions) 行\n\n" }
            return output + "```diff\n\(diff.content)\n```"
        } catch { return "获取 Git 差异失败：\(error.localizedDescription)" }
    }
    private func resolveTarget(path: String, file: String?) throws -> (repositoryPath: String, file: String?) {
        let repositoryPath = try GitService.repositoryRoot(containing: path)
        if let file, !file.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return (repositoryPath, GitService.relativePath(file, fromRepositoryRoot: repositoryPath) ?? file) }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue { return (repositoryPath, nil) }
        let relative = GitService.relativePath(path, fromRepositoryRoot: repositoryPath)
        return (repositoryPath, relative?.isEmpty == true ? nil : relative)
    }
}

public struct GitLogV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_log"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "View Git commit history. Supports limiting the number of commits and viewing logs for a specific branch or file." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "count": ["type": "integer", "description": "Number of commits to display, default 10, range 1-50.", "minimum": 1, "maximum": 50], "branch": ["type": "string", "description": "Optional, view logs for a specific branch."], "file": ["type": "string", "description": "Optional, view commit history for a specific file."]]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看提交历史" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        do {
            let logs = try await GitService.shared.getLog(path: GitV2ToolSupport.path(arguments, project: project), count: min(max(GitV2ToolSupport.int(arguments, "count") ?? 10, 1), 50), branch: GitV2ToolSupport.string(arguments, "branch"), file: GitV2ToolSupport.string(arguments, "file"))
            guard !logs.isEmpty else { return "暂无提交记录" }
            var output = "## Git 提交历史\n\n"
            for (index, log) in logs.enumerated() { output += "### \(index + 1). `\(log.hash.prefix(7))` - \(log.message)\n\n**作者**: \(log.author)\n**日期**: \(log.date.prefix(10))\n\n" }
            return output
        } catch { return "获取 Git 日志失败：\(error.localizedDescription)" }
    }
}

public struct GitShowV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_show"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "View detailed information of a specific commit, including author, date, changed files and stats." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "hash": ["type": "string", "description": "Commit hash (full or abbreviated)."]], required: ["hash"]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看提交详情" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let hash = GitV2ToolSupport.string(arguments, "hash"), !hash.isEmpty else { return "缺少必需的 commit 哈希参数" }
        do {
            let path = try await GitV2ToolSupport.path(arguments, project: project)
            let detail = try await GitService.shared.getCommitDetail(path: path, hash: hash)
            let files = try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
            var output = "## Commit `\(detail.hash.prefix(7))`\n\n**信息**: \(detail.message)\n\n**作者**: \(detail.author) <\(detail.email)>\n\n**日期**: \(detail.date)\n\n"
            if !detail.body.isEmpty { output += "**正文**:\n\(detail.body)\n\n" }
            if let stats = detail.stats { output += "**统计**: \(stats.filesChanged) 个文件，+\(stats.insertions) 行，-\(stats.deletions) 行\n\n" }
            if !files.isEmpty { output += "### 变更文件\n" + files.map { "- `[\($0.changeType.displayLabel)]` \($0.path)\n" }.joined() + "\n" }
            return output
        } catch { return "获取 commit 详情失败：\(error.localizedDescription)" }
    }
}

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

public struct GitCommitV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_commit"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "Commit Git changes. Commit related changes together and follow the project's established commit-message style." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "message": ["type": "string", "description": "Commit message (required). Follow the project's established commit style."], "files": ["type": "array", "items": ["type": "string"], "description": "List of file paths to add (optional); an empty list adds all changes."], "amend": ["type": "boolean", "description": "Whether to amend the last commit (optional), default false."]], required: ["message"]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "提交变更" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let message = GitV2ToolSupport.string(arguments, "message"), !message.isEmpty else { return "缺少必需的提交信息参数" }
        do {
            let result = try await GitService.shared.commit(path: GitV2ToolSupport.path(arguments, project: project), message: message, files: GitV2ToolSupport.strings(arguments, "files"), amend: GitV2ToolSupport.bool(arguments, "amend") ?? false)
            var output = "## Git 提交成功 ✅\n\n**提交哈希**: `\(result.hash)`\n\n**提交信息**: \(result.message)\n\n**作者**: \(result.author) <\(result.email)>\n\n**时间**: \(result.date)\n\n"
            if !result.changedFiles.isEmpty { output += "### 变更文件\n" + result.changedFiles.map { "- `\($0)`\n" }.joined() + "\n" }
            return output
        } catch { return "Git 提交失败：\(error.localizedDescription)" }
    }
}

public struct GitUnpushedV2Tool: SuperAgentTool, @unchecked Sendable {
    public let name = "git_unpushed"
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "Check how many local commits have not been pushed to the remote repository." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty()]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看未推送提交" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let hashes = GitService.shared.getUnpushedCommitHashes(path: try await GitV2ToolSupport.path(arguments, project: project))
        guard !hashes.isEmpty else { return "✅ 所有 commit 都已推送到远程" }
        return "## 未推送的 Commit\n\n共有 **\(hashes.count)** 个 commit 未推送到远程：\n\n" + hashes.map { "- `\($0.prefix(7))`\n" }.joined() + "\n💡 使用 `git push` 推送到远程"
    }
}
