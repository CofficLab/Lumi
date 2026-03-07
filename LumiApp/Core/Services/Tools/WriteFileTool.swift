import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 文件写入工具
///
/// 允许 AI 助手创建新文件或覆盖现有文件。
/// 用于：
/// - 创建新代码文件
/// - 修改配置文件
/// - 写入文档
///
/// ## 功能特性
///
/// - 自动创建目录（如果不存在）
/// - 覆盖现有文件
/// - UTF-8 编码
/// - 详细的成功/错误信息
struct WriteFileTool: AgentTool, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "✍️"
    
    /// 是否启用详细日志
    nonisolated static let verbose = true

    /// 工具名称
    let name = "write_file"
    
    /// 工具描述
    let description = "Create a new file or overwrite an existing file with the given content."

    /// 输入参数 JSON Schema
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

    /// 执行文件写入
    ///
    /// 执行步骤：
    /// 1. 验证参数（path 和 content）
    /// 2. 检查并创建父目录（如需要）
    /// 3. 写入文件
    ///
    /// - Parameter arguments: 参数字典，必须包含 "path" 和 "content" 键
    /// - Returns: 成功/错误信息
    /// - Throws: 参数错误或文件写入错误
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 验证必需参数
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

        // 确保目录存在
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            if Self.verbose {
                os_log("\(Self.t)目录不存在，正在创建：\(directoryURL.path)")
            }
            do {
                // withIntermediateDirectories: true 会自动创建所有中间目录
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                if Self.verbose {
                    os_log("\(Self.t)目录创建成功")
                }
            } catch {
                os_log(.error, "\(Self.t)创建目录失败：\(error.localizedDescription)")
                return "Error creating directory: \(error.localizedDescription)"
            }
        }

        // 写入文件
        do {
            // atomically: true 表示先写入临时文件，成功后重命名，更安全
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