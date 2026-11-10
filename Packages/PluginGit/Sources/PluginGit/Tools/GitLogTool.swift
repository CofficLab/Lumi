import Foundation
import KitAgentTool
import ProviderGit

/// 查看 Git 提交历史，支持限制数量、指定分支和文件。
///
/// 返回内容是人类可读的 Markdown 文本，供 LLM 直接理解。
public struct GitLogTool: SuperAgentTool, @unchecked Sendable {
    public static let toolName = "git_log"
    public let name = Self.toolName
    private let project: (any GitProjectCapability)?
    public init(project: (any GitProjectCapability)? = nil) { self.project = project }
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
            return output
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "获取 Git 日志失败：\(error.localizedDescription)"
            )
        }
    }

    /// 规范化 count 参数：接受 Int / Double / 数字字符串，钳制到 1...50。
    ///
    /// 转换必须先检查范围：JSON 数字会桥接成 `Double`，而 `Int(_:)` 对超出
    /// `Int` 范围的 `Double` 会触发运行时陷阱，直接终止宿主进程。
    /// 无法安全表示的值（`1e100`、`nan` 等）退回默认值 10。
    static func normalizedCount(_ value: Any?) -> Int {
        ToolArgumentNumber.int(value, clampedTo: 1...50, default: 10)
    }
}