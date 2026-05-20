import Foundation
import SwiftUI
import WorkspaceFileKit

struct ListDirectoryTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false
    private let lister = WorkspaceDirectoryLister()
    let name = "ls"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出指定路径下的文件和目录。适合用于探索项目结构。"
        case .english:
            return "List files and directories at a given path. Useful for exploring the project structure."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
                ]
            ],
            "required": ["path"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(domain: "ListDirectoryTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
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
