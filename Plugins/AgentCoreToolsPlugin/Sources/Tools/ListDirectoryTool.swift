import Foundation
import SuperLogKit
import AgentToolKit
import SwiftUI
import WorkspaceFileKit

public struct ListDirectoryTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose: Bool = false
    private let lister = WorkspaceDirectoryLister()
    public let name = "ls"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出指定路径下的文件和目录。适合用于探索项目结构。"
        case .english:
            return "List files and directories at a given path. Useful for exploring the project structure."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let displayDesc: String
        switch language {
        case .chinese:
            displayDesc = "向用户展示当前操作描述，如：正在列出 LumiApp 目录"
        case .english:
            displayDesc = "A short description shown to the user, e.g. \"Listing LumiApp directory\""
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the directory to list"
                ],
                "recursive": [
                    "type": "boolean",
                    "description": "Whether to list subdirectories recursively (default: false)"
                ],
                "display_name": [
                    "type": "string",
                    "description": displayDesc
                ]
            ],
            "required": ["path"]
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument], context: ToolExecutionContext?) -> CommandRiskLevel {
        let baseRisk: CommandRiskLevel = .low
        guard let context else { return baseRisk }
        return AgentCoreToolRisk.elevatedRiskIfPathOutOfBounds(arguments: arguments, baseRisk: baseRisk, context: context)
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments["path"]?.value as? String else { return "列出目录" }
        let dirName = URL(fileURLWithPath: path).lastPathComponent
        return "列出 \(dirName) 目录"
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(domain: "ListDirectoryTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        // 验证路径是否在允许的范围内
        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "ListDirectoryTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        let recursive = arguments["recursive"]?.value as? Bool ?? false

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)列出目录：\(path.components(separatedBy: "/").last ?? path)（递归：\(recursive ? "是" : "否")）")
        }

        do {
            let listing = try lister.list(path: path, recursive: recursive)
            if recursive {
                if listing.truncated, Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)文件数量过多，已停止列表（限制 500 个）")
                }
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)递归列表完成：\(listing.itemCount) 个项目")
                }
            } else {
                if Self.verbose {
                    AgentCoreToolsPlugin.logger.info("\(self.t)目录列表完成：\(listing.itemCount) 个项目")
                }
            }
            return listing.output
        } catch let error as WorkspaceFileError {
            if Self.verbose {
                AgentCoreToolsPlugin.logger.error("\(self.t)路径不存在：\(path)")
            }
            return "Error: \(error.localizedDescription)"
        } catch {
            AgentCoreToolsPlugin.logger.error("\(self.t)列出目录失败：\(error.localizedDescription)")
            return "Error listing directory: \(error.localizedDescription)"
        }
    }
}
