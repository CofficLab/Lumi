import Foundation
import KitAgentTool
import ProviderProject

/// 查看 Git 仓库状态：分支、远程、变更文件分类。
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