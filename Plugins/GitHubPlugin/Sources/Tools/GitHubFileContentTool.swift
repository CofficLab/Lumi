import Foundation
import GitHubKit
import LumiCoreKit
import SuperLogKit

/// GitHub 文件内容获取工具
public struct GitHubFileContentTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true
    public static let info = LumiAgentToolInfo(
        id: "github_file_content",
        displayName: "GitHubFileContent",
        description: "GitHub tool: github_file_content"
    )

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {        "查看文件内容"    }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let owner = arguments["owner"]?.anyValue as? String,
              let repo = arguments["repo"]?.anyValue as? String,
              let path = arguments["path"]?.anyValue as? String else {
            throw NSError(
                domain: Self.info.id,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数"]
            )
        }

        let branch = arguments["branch"]?.anyValue as? String ?? "main"

        if Self.verbose {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.info("\(self.t)获取文件：\(owner)/\(repo)/\(path)")
            }
        }

        do {
            let fileContent = try await GitHubAPIService.shared.getFileContent(
                owner: owner,
                repo: repo,
                path: path,
                branch: branch
            )

            guard let content = fileContent.decodedContent else {
                return "无法解码文件内容"
            }

            return "📄 **\(fileContent.name)**\n\n```\(content)```"
        } catch {
            if GitHubPlugin.verbose {
                            GitHubPlugin.logger.error("\(self.t)获取文件失败：\(error.localizedDescription)")
            }
            return "获取文件失败：\(error.localizedDescription)"
        }
    }
}
