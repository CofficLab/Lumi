import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 日志工具
public struct GitLogTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "git_log",
        displayName: "Git Log",
        description: "View Git commit history. Supports limiting the number of commits and viewing logs for a specific branch or file."
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
                "count": .object([
                    "type": .string("integer"),
                    "description": .string("Number of commits to display, default 10, range 1-50"),
                    "minimum": .int(1),
                    "maximum": .int(50),
                ]),
                "branch": .object([
                    "type": .string("string"),
                    "description": .string("Optional, view logs for a specific branch"),
                ]),
                "file": .object([
                    "type": .string("string"),
                    "description": .string("Optional, view commit history for a specific file"),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看提交历史"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")
        let count = Self.normalizedCount(arguments["count"]?.anyValue)
        let branch = arguments.string("branch")
        let file = arguments.string("file")

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)获取 Git 日志：\(path ?? "当前目录") count=\(count)")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

            let logs = try await GitService.shared.getLog(
                path: validatedPath,
                count: count,
                branch: branch,
                file: file
            )
            return formatLog(logs)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 Git 日志失败：\(error.localizedDescription)")
            }
            return "获取 Git 日志失败：\(error.localizedDescription)"
        }
    }

    private func formatLog(_ logs: [GitCommitLog]) -> String {
        guard !logs.isEmpty else {
            return "暂无提交记录"
        }

        var output = "## Git 提交历史\n\n"

        for (index, log) in logs.enumerated() {
            let dateStr = log.date.prefix(10)
            output += "### \(index + 1). `\(log.hash.prefix(7))` - \(log.message)\n\n"
            output += "**作者**: \(log.author)\n"
            output += "**日期**: \(dateStr)\n\n"
        }

        return output
    }

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
}
