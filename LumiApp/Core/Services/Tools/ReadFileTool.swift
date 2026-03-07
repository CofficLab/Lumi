import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 文件读取工具
///
/// 允许 AI 助手读取指定路径的文件内容。
/// 用于：
/// - 查看代码文件
/// - 查看配置文件
/// - 查看文档
///
/// ## 功能特性
///
/// - 支持绝对路径和相对路径
/// - 自动检测 UTF-8 编码
/// - 大文件自动截断（50KB 限制）
/// - 详细的错误信息
struct ReadFileTool: AgentTool, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "📄"
    
    /// 是否启用详细日志
    nonisolated static let verbose = true

    /// 工具名称
    let name = "read_file"
    
    /// 工具描述
    let description = "Read the contents of a file at the given path. Use this to examine code or configuration files."

    /// 输入参数 JSON Schema
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

    /// 执行文件读取
    ///
    /// - Parameter arguments: 参数字典，必须包含 "path" 键
    /// - Returns: 文件内容字符串
    /// - Throws: 参数错误或文件读取错误
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 验证必需参数
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: "ReadFileTool", 
                code: 400, 
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if Self.verbose {
            os_log("\(Self.t)读取文件：\(path.components(separatedBy: "/").last ?? path)")
        }

        let fileURL = URL(fileURLWithPath: path)

        do {
            // 读取文件数据
            let data = try Data(contentsOf: fileURL)
            
            // 尝试 UTF-8 解码
            guard let content = String(data: data, encoding: .utf8) else {
                if Self.verbose {
                    os_log(.error, "\(Self.t)文件内容不是有效的 UTF-8 文本")
                }
                return "Error: File content is not valid UTF-8 text."
            }

            // 大小限制：50KB
            // 防止文件过大导致上下文溢出
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
            os_log(.error, "\(Self.t)读取文件失败：\(error.localizedDescription)")
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}