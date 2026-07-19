import Foundation
import LumiKernel
import SuperLogKit

/// GitHub CLI 安装检测工具
///
/// 检测用户系统是否安装了 GitHub CLI (gh) 命令行工具
public struct GitHubCLICheckTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_cli_check",
        displayName: "GitHubCliCheck",
        description: "GitHub tool: github_cli_check"
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "检测 GitHub CLI"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        if Self.verbose {
            if GitHubPlugin.verbose {
                GitHubPlugin.logger.info("\(Self.t)检测 GitHub CLI 安装状态")
            }
        }

        let result = GitHubCLIDetectService.shared.getDetectionDetails()
        return formatDetectionResult(result)
    }

    private func formatDetectionResult(_ result: GitHubCLIDetectionResult) -> String {
        result.description
    }
}
