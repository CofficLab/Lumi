import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 下载单个文件工具
///
/// Agent 调用此工具从 URL 下载单个文件到本地。
/// 支持 HTTP/HTTPS 协议，自动断点续传。
public struct DownloadFileTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📥"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "download_file"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "从 URL 下载单个文件到本地。支持 HTTP/HTTPS 链接，自动断点续传。可以指定文件名和保存目录，不提供则自动从 URL 推断。"
        case .english:
            return "Download a single file from URL to local disk. Supports HTTP/HTTPS with automatic resume. Filename and destination directory are optional (auto-detected from URL)."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "文件下载链接 (HTTP/HTTPS)",
                ],
                "filename": [
                    "type": "string",
                    "description": "可选，保存的文件名。不提供则从 URL 自动推断",
                ],
                "directory": [
                    "type": "string",
                    "description": "可选，保存目录的绝对路径。不提供则使用默认下载目录",
                ],
            ],
            "required": ["url"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let urlString = arguments["url"]?.value as? String,
           let url = URL(string: urlString) {
            let name = url.lastPathComponent
            if !name.isEmpty && name != "/" {
                return "下载 \(name)"
            }
        }
        return "下载文件"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String,
              let url = URL(string: urlString) else {
            return "❌ 错误：无效的 URL"
        }

        // 确定文件名
        let filename: String
        if let customName = arguments["filename"]?.value as? String, !customName.isEmpty {
            filename = customName
        } else {
            filename = DownloadPlugin.extractFilename(from: url)
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = arguments["directory"]?.value as? String {
            directory = URL(fileURLWithPath: dirPath, isDirectory: true)
        } else {
            directory = DownloadPlugin.defaultDownloadDirectory()
        }

        let destination = directory.appendingPathComponent(filename)
        let taskId = UUID().uuidString

        let task = DownloadTask(
            id: taskId,
            url: url,
            destination: destination,
            expectedSize: nil
        )

        do {
            let finalURL = try await manager.download(task)
            let size = try Self.fileSizeString(at: finalURL)
            return """
            ✅ 下载完成
            文件名: \(filename)
            任务 ID: \(taskId)
            大小: \(size)
            路径: \(finalURL.path)
            """
        } catch {
            return "❌ 下载失败: \(error.localizedDescription)\n任务 ID: \(taskId)"
        }
    }

    private static func fileSizeString(at url: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = attrs[.size] as? Int64 ?? 0
        if bytes > 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes > 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes > 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}
