import Foundation
import SwiftUI
import WorkspaceFileKit

/// 文件写入工具
///
/// 允许 AI 助手创建新文件或覆盖现有文件。
struct WriteFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = false
    private let writer = WorkspaceFileWriter()
    let name = "write_file"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "使用给定内容创建新文件，或覆盖已有文件。"
        case .english:
            return "Create a new file or overwrite an existing file with the given content."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let displayDesc: String
        switch language {
        case .chinese:
            displayDesc = "向用户展示当前操作描述，如：正在写入 xxx.swift"
        case .english:
            displayDesc = "A short description shown to the user, e.g. \"Writing xxx.swift\""
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to write"
                ],
                "content": [
                    "type": "string",
                    "description": "The full content to write to the file"
                ],
                "display_name": [
                    "type": "string",
                    "description": displayDesc
                ]
            ],
            "required": ["path", "content"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String,
              let content = arguments["content"]?.value as? String else {
            throw NSError(
                domain: "WriteFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' or 'content' argument"]
            )
        }

        let fileName = path.components(separatedBy: "/").last ?? path
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)写入文件：\(fileName)（\(content.count) 字符）")
        }

        do {
            try writer.write(path: path, content: content)
            if Self.verbose {
                AgentCoreToolsPlugin.logger.info("\(self.t)文件写入成功：\(fileName)")
            }
            return "Successfully wrote to \(path)"
        } catch {
            AgentCoreToolsPlugin.logger.error("\(self.t)写入文件失败：\(error.localizedDescription)")
            return "Error writing file: \(error.localizedDescription)"
        }
    }
}
