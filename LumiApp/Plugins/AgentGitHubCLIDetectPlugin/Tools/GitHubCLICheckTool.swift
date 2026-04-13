import Foundation
import MagicKit

/// GitHub CLI 安装检测工具
///
/// 检测用户系统是否安装了 GitHub CLI (gh) 命令行工具
struct GitHubCLICheckTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = true
    let name = "github_cli_check"
    let description = "检测用户系统是否安装了 GitHub CLI (gh) 命令行工具，返回安装状态、版本号和安装路径。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        if Self.verbose {
            GitHubCLIDetectPlugin.logger.info("\(Self.t)检测 GitHub CLI 安装状态")
        }

        let result = GitHubCLIDetectService.shared.getDetectionDetails()
        return formatDetectionResult(result)
    }

    private func formatDetectionResult(_ result: GitHubCLIDetectionResult) -> String {
        result.description
    }
}
