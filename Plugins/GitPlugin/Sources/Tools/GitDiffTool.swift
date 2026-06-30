import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 差异工具
public struct GitDiffTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "git_diff",
        displayName: "Git Diff",
        description: "View code changes in a Git repository. Supports working tree changes and staged changes."
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
                "staged": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to view staged changes. false means viewing working tree changes"),
                ]),
                "file": .object([
                    "type": .string("string"),
                    "description": .string("Optional, only view changes for the specified file"),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看代码变更"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")
        let staged = arguments.bool("staged") ?? false
        let file = arguments.string("file")

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)获取 Git 差异：\(path ?? "当前目录") staged=\(staged) file=\(file ?? "all")")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

            let diff = try await GitService.shared.getDiff(
                path: validatedPath,
                staged: staged,
                file: file
            )
            return formatDiff(diff)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 Git 差异失败：\(error.localizedDescription)")
            }
            return "获取 Git 差异失败：\(error.localizedDescription)"
        }
    }

    private func formatDiff(_ diff: GitDiff) -> String {
        guard !diff.isEmpty else {
            return "✅ 没有变更"
        }

        var output = "## Git 变更\n\n"

        if let stats = diff.stats {
            output += "**变更统计**: \(stats.filesChanged) 个文件，+\(stats.insertions) 行，-\(stats.deletions) 行\n\n"
        }

        output += "```diff\n\(diff.content)\n```"

        return output
    }
}
