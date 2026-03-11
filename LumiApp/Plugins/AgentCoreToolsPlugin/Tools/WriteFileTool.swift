import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 文件写入工具
///
/// 允许 AI 助手创建新文件或覆盖现有文件。
struct WriteFileTool: AgentTool, SuperLog {
    nonisolated static let emoji = "✍️"
    nonisolated static let verbose = true

    let name = "write_file"
    let description = "Create a new file or overwrite an existing file with the given content."

    var inputSchema: [String: Any] {
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
                ]
            ],
            "required": ["path", "content"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        // 写文件始终视为高风险操作，需要用户批准。
        return .high
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
            os_log("\(Self.t)写入文件：\(fileName)（\(content.count) 字符）")
        }

        let fileURL = URL(fileURLWithPath: path)
        let directoryURL = fileURL.deletingLastPathComponent()

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            if Self.verbose {
                os_log("\(Self.t)目录不存在，正在创建：\(directoryURL.path)")
            }
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                if Self.verbose {
                    os_log("\(Self.t)目录创建成功")
                }
            } catch {
                os_log(.error, "\(Self.t)创建目录失败：\(error.localizedDescription)")
                return "Error creating directory: \(error.localizedDescription)"
            }
        }

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            if Self.verbose {
                os_log("\(Self.t)文件写入成功：\(fileName)")
            }
            return "Successfully wrote to \(path)"
        } catch {
            os_log(.error, "\(Self.t)写入文件失败：\(error.localizedDescription)")
            return "Error writing file: \(error.localizedDescription)"
        }
    }
}

