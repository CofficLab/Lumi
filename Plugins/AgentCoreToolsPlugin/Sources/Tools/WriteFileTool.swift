import Foundation
import SuperLogKit
import AgentToolKit
import SwiftUI
import WorkspaceFileKit

/// 文件写入工具
///
/// 允许 AI 助手创建新文件或覆盖现有文件。
public struct WriteFileTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = false
    private let writer = WorkspaceFileWriter()
    public let name = "write_file"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "使用给定内容创建新文件，或覆盖已有文件。"
        case .english:
            return "Create a new file or overwrite an existing file with the given content."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument], context: ToolExecutionContext?) -> CommandRiskLevel {
        let baseRisk: CommandRiskLevel = .high
        guard let context else { return baseRisk }
        return AgentCoreToolRisk.elevatedRiskIfPathOutOfBounds(arguments: arguments, baseRisk: baseRisk, context: context)
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments["path"]?.value as? String else { return "写入文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        return "写入 \(fileName)"
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String,
              let content = arguments["content"]?.value as? String else {
            throw NSError(
                domain: "WriteFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' or 'content' argument"]
            )
        }

        // 验证路径是否在允许的范围内
        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "WriteFileTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
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
