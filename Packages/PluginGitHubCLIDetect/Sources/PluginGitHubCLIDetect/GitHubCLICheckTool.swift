import Foundation
import AgentToolKit
import SuperLogKit

/// GitHub CLI 安装检测工具
///
/// 检测用户系统是否安装了 GitHub CLI (gh) 命令行工具
public struct GitHubCLICheckTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public let name = "github_cli_check"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "检测用户系统是否安装了 GitHub CLI (gh) 命令行工具，返回安装状态、版本号和安装路径。"
        case .english:
            return "Check whether GitHub CLI (gh) is installed on the user's system. Returns installation status, version, and executable path."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
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
