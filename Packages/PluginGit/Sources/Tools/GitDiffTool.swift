import Foundation
import KitAgentTool
import ProviderProject

/// 查看 Git 代码变更：工作区或暂存区的 diff 与统计。
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