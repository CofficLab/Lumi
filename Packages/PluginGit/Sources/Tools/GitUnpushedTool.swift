import Foundation
import KitAgentTool
import ProviderProject

/// 查看未推送到远程的本地 commit 数量与 hash 列表。
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