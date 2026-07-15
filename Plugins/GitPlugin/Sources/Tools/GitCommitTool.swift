import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 提交工具
public struct GitCommitTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "💾"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "git_commit",
        displayName: "Git Commit",
        description: "Commit Git changes. Supports specifying commit message, adding specific files, or amending the last commit. Before committing, it's recommended to first examine recent commit history to determine the commit style for consistency. Important: Commit changes by topic, ensuring each commit contains only related logical changes. If changes involve multiple unrelated topics, split them into separate commits."
    )
    public static let tags: Set<LumiToolTag> = [.git, .destructive, .requiresApproval]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path, defaults to current working directory"),
                ]),
                "message": .object([
                    "type": .string("string"),
                    "description": .string("Commit message (required). Should follow the project's commit style (e.g., feat:, fix:, chore: prefixes). It's recommended to first check recent commit history to determine the style. Important: Commit changes by topic, ensuring each commit contains only related logical changes. If changes involve multiple unrelated topics, split them into separate commits."),
                ]),
                "files": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("List of file paths to add (optional), empty array means add all changes"),
                ]),
                "amend": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to amend the last commit (optional), default false"),
                ]),
            ]),
            "required": .array([.string("message")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "提交变更"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium // 提交会修改代码库，风险中等
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")
        guard let message = arguments.string("message") else {
            throw NSError(domain: "GitCommitTool", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "缺少必需的提交信息参数"])
        }

        let files = arguments.stringArray("files") ?? []
        let amend = arguments.bool("amend") ?? false

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)执行 Git 提交：\(message)")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

            let result = try await GitService.shared.commit(
                path: validatedPath,
                message: message,
                files: files,
                amend: amend
            )
            return formatCommitResult(result)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)Git 提交失败：\(error.localizedDescription)")
            }
            return "Git 提交失败：\(error.localizedDescription)"
        }
    }

    private func formatCommitResult(_ result: GitCommitResult) -> String {
        var output = "## Git 提交成功 ✅\n\n"
        output += "**提交哈希**: `\(result.hash)`\n\n"
        output += "**提交信息**: \(result.message)\n\n"
        output += "**作者**: \(result.author) <\(result.email)>\n\n"
        output += "**时间**: \(result.date)\n\n"

        if !result.changedFiles.isEmpty {
            output += "### 变更文件\n"
            for file in result.changedFiles {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        return output
    }
}
