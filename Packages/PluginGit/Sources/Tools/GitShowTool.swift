import Foundation
import KitAgentTool
import ProviderProject

/// 查看指定 commit 的详情：信息、作者、日期、统计和变更文件。
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