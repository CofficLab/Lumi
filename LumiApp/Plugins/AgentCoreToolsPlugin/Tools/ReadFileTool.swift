import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 文件读取工具
///
/// 允许 AI 助手读取指定路径的文件内容。
struct ReadFileTool: AgentTool, SuperLog {
    nonisolated static let verbose = false

    let name = "read_file"
    let description = "Read the contents of a file at the given path. Use this to examine code or configuration files."

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ]
            ],
            "required": ["path"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: "ReadFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if Self.verbose {
            os_log("\(Self.t)📖 读取文件：\(path.components(separatedBy: "/").last ?? path)")
        }

        let fileURL = URL(fileURLWithPath: path)

        do {
            let data = try Data(contentsOf: fileURL)
            guard let content = String(data: data, encoding: .utf8) else {
                if Self.verbose {
                    os_log(.error, "\(Self.t)文件内容不是有效的 UTF-8 文本")
                }
                return "Error: File content is not valid UTF-8 text."
            }

            if content.count > 50_000 {
                let prefix = content.prefix(50_000)
                if Self.verbose {
                    os_log("\(Self.t)文件过大，已截断输出（限制 50KB）")
                }
                return "\(prefix)\n... (File truncated due to size limit)"
            }

            if Self.verbose {
                os_log("\(Self.t)文件读取成功：\(content.count) 字符")
            }
            return content
        } catch {
            os_log(.error, "\(Self.t)❌ 读取文件失败：\(error.localizedDescription)")
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}

