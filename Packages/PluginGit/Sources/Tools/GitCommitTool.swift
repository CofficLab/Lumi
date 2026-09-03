import Foundation
import KitAgentTool
import ProviderProject

/// 提交 Git 变更：支持指定文件、amend。
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