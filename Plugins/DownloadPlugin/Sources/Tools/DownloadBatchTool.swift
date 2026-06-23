import AgentToolKit
import DownloadKit
import Foundation
import SuperLogKit

/// 批量下载文件工具
///
/// Agent 调用此工具从多个 URL 并发下载文件。
public struct DownloadBatchTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = false

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public let name = "download_batch"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "批量下载多个文件。提供 URL 列表，自动并发下载（最多 3 个并发）。每个 URL 独立处理，返回整体完成摘要。"
        case .english:
            return "Download multiple files in batch from a list of URLs. Concurrent downloads (up to 3 at once). Returns a summary when all downloads complete or fail."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "urls": [
                    "type": "array",
                    "items": [
                        "type": "string",
                    ],
                    "description": "文件下载链接列表 (HTTP/HTTPS)",
                ],
                "directory": [
                    "type": "string",
                    "description": "可选，保存目录的绝对路径。不提供则使用默认下载目录",
                ],
            ],
            "required": ["urls"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let urls = arguments["urls"]?.value as? [String] {
            return "批量下载 \(urls.count) 个文件"
        }
        return "批量下载文件"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let urls = arguments["urls"]?.value as? [String] else {
            return "❌ 错误：urls 参数必需，且必须为字符串数组"
        }

        guard !urls.isEmpty else {
            return "⚠️ URL 列表为空"
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = arguments["directory"]?.value as? String {
            directory = URL(fileURLWithPath: dirPath, isDirectory: true)
        } else {
            directory = DownloadPlugin.defaultDownloadDirectory()
        }

        var results: [String] = []
        var successCount = 0
        var failCount = 0

        for urlString in urls {
            guard let url = URL(string: urlString) else {
                results.append("❌ 无效 URL: \(urlString)")
                failCount += 1
                continue
            }

            let filename = DownloadPlugin.extractFilename(from: url)
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
                results.append("✅ \(filename) (\(size))")
                successCount += 1
            } catch {
                results.append("❌ \(filename): \(error.localizedDescription)")
                failCount += 1
            }
        }

        var summary = """
        📦 批量下载完成
        总计: \(urls.count) 个文件
        成功: \(successCount)
        失败: \(failCount)

        """

        if !results.isEmpty {
            summary += results.map { "- \($0)" }.joined(separator: "\n")
        }

        return summary
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
