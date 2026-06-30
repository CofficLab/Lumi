import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 未推送 Commit 查询工具
public struct GitUnpushedTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📤"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "git_unpushed",
        displayName: "Git Unpushed",
        description: "Check how many local commits have not been pushed to the remote repository."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path, defaults to current working directory"),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看未推送提交"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)检查未推送 commit：\(path ?? "当前目录")")
        }

        // 验证路径是否在允许的范围内
        let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

        let hashes = GitService.shared.getUnpushedCommitHashes(path: validatedPath)

        return formatResult(hashes)
    }

    private func formatResult(_ hashes: [String]) -> String {
        guard !hashes.isEmpty else {
            return "✅ 所有 commit 都已推送到远程"
        }

        var output = "## 未推送的 Commit\n\n"
        output += "共有 **\(hashes.count)** 个 commit 未推送到远程：\n\n"
        for hash in hashes {
            output += "- `\(hash.prefix(7))`\n"
        }
        output += "\n💡 使用 `git push` 推送到远程"

        return output
    }
}
