import Foundation
import KitAgentTool
import ProviderProject

/// 查看 Git 提交历史，支持限制数量、指定分支和文件。
///
/// 返回内容由两部分组成：
/// 1. 人类可读的 Markdown 文本（供 LLM 直接理解）；
/// 2. 末尾追加的 ` ```json ` 结构化 commit 列表（供消息渲染器
///    `GitLogRowRenderer` 解码为 commit 卡片展示）。
public struct GitLogTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "git_log"
    public let name = Self.toolName
    private let project: (any ProjectProviding)?
    public init(project: (any ProjectProviding)? = nil) { self.project = project }
    public func description(for language: LanguagePreference) -> String { "View Git commit history. Supports limiting the number of commits and viewing logs for a specific branch or file." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { GitV2ToolSupport.schema(["path": GitV2ToolSupport.pathProperty(), "count": ["type": "integer", "description": "Number of commits to display, default 10, range 1-50.", "minimum": 1, "maximum": 50], "branch": ["type": "string", "description": "Optional, view logs for a specific branch."], "file": ["type": "string", "description": "Optional, view commit history for a specific file."]]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看提交历史" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        do {
            let logs = try await GitService.shared.getLog(
                path: GitV2ToolSupport.path(arguments, project: project),
                count: Self.normalizedCount(arguments["count"]?.value),
                branch: GitV2ToolSupport.string(arguments, "branch"),
                file: GitV2ToolSupport.string(arguments, "file")
            )
            guard !logs.isEmpty else { return "暂无提交记录" }
            var output = "## Git 提交历史\n\n"
            for (index, log) in logs.enumerated() { output += "### \(index + 1). `\(log.hash.prefix(7))` - \(log.message)\n\n**作者**: \(log.author)\n**日期**: \(log.date.prefix(10))\n\n" }
            return output + Self.structuredPayload(logs)
        } catch { return "获取 Git 日志失败：\(error.localizedDescription)" }
    }

    /// 规范化 count 参数：接受 Int / Double / 数字字符串，钳制到 1...50。
    static func normalizedCount(_ value: Any?) -> Int {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = 10
        }
        return min(max(requested, 1), 50)
    }

    /// 把结构化 commit 列表编码为 JSON 代码块追加到返回内容末尾。
    ///
    /// 消息渲染器（`GitLogRowRenderer`）从 `ToolCallResult.content` 中提取此块，
    /// 解码为 `[GitCommitLog]` 后渲染 commit 卡片列表。无法编码时静默回退，
    /// 保证 LLM 始终拿到人类可读文本，渲染器解析失败也能回退默认文本视图。
    static func structuredPayload(_ logs: [GitCommitLog]) -> String {
        guard let data = try? JSONEncoder().encode(logs),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return "\n\n```json\n\(json)\n```"
    }
}