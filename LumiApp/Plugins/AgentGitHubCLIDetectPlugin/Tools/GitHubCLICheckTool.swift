import Foundation
import MagicKit

/// GitHub CLI 安装检测工具
///
/// 检测用户系统是否安装了 GitHub CLI (gh) 命令行工具
struct GitHubCLICheckTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
    let name = "github_cli_check"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "检测用户系统是否安装了 GitHub CLI (gh) 命令行工具，返回安装状态、版本号和安装路径。"
        case .english:
            return "Check whether GitHub CLI (gh) is installed on the user's system. Returns installation status, version, and executable path."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
            if GitHubCLIDetectPlugin.verbose {
                            GitHubCLIDetectPlugin.logger.info("\(Self.t)检测 GitHub CLI 安装状态")
            }
        }

        let result = GitHubCLIDetectService.shared.getDetectionDetails()
        return formatDetectionResult(result)
    }

    private func formatDetectionResult(_ result: GitHubCLIDetectionResult) -> String {
        result.description
    }
}
