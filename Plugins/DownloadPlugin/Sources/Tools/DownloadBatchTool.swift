import DownloadKit
import Foundation
import LumiCoreKit
import SuperLogKit

/// 批量下载工具
///
/// 批量从多个 URL 下载文件到本地。
public struct DownloadBatchTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📥"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "download_batch",
        displayName: LumiPluginLocalization.string("Batch Download", bundle: .module),
        description: LumiPluginLocalization.string(
            "Download multiple files in batch from a list of URLs. Concurrent downloads (up to 3 at once). Returns a summary when all downloads complete or fail.",
            bundle: .module
        )
    )

    private let manager: DownloadManager

    public init(manager: DownloadManager) {
        self.manager = manager
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "urls": .object([
                    "type": .string("array"),
                    "description": .string("文件下载链接列表 (HTTP/HTTPS)")
                ]),
                "directory": .object([
                    "type": .string("string"),
                    "description": .string("可选，保存目录的绝对路径。不提供则使用默认下载目录")
                ])
            ]),
            "required": .array([.string("urls")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if case .array(let urls) = arguments["urls"] {
            return "批量下载 \(urls.count) 个文件"
        }
        return "批量下载"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let urlStrings: [String]
        
        if let urlsValue = arguments["urls"] {
            switch urlsValue {
            case .array(let arr):
                urlStrings = arr.compactMap { $0.stringValue }
            case .object:
                // 尝试从对象中提取 urls 字段
                if let nested = arguments["urls"]?.stringValue {
                    urlStrings = [nested]
                } else {
                    urlStrings = []
                }
            default:
                if let anyVal = arguments["urls"]?.anyValue as? [String] {
                    urlStrings = anyVal
                } else {
                    urlStrings = []
                }
            }
        } else {
            urlStrings = []
        }

        guard !urlStrings.isEmpty else {
            return "❌ 错误：urls 参数必需且必须是字符串数组"
        }

        let urls = urlStrings.compactMap { URL(string: $0) }
        guard !urls.isEmpty else {
            return "❌ 错误：无效的 URL 列表"
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = arguments["directory"]?.stringValue {
            directory = URL(fileURLWithPath: dirPath, isDirectory: true)
        } else {
            directory = DownloadPlugin.defaultDownloadDirectory()
        }

        var results: [String] = []
        var failedCount = 0

        // 并发下载（最多 3 个同时）
        try await withThrowingTaskGroup(of: (Int, Result<URL, Error>).self) { group in
            var pendingURLs = urls.enumerated().map { ($0.offset, $0.element) }
            var inFlight = 0
            let maxConcurrent = 3

            while !pendingURLs.isEmpty || inFlight > 0 {
                // 启动新任务
                while inFlight < maxConcurrent && !pendingURLs.isEmpty {
                    let (index, url) = pendingURLs.removeFirst()
                    inFlight += 1

                    group.addTask {
                        let filename = DownloadPlugin.extractFilename(from: url)
                        let destination = directory.appendingPathComponent(filename)
                        let task = DownloadTask(
                            id: UUID().uuidString,
                            url: url,
                            destination: destination,
                            expectedSize: nil
                        )

                        do {
                            let finalURL = try await self.manager.download(task)
                            return (index, .success(finalURL))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                }

                // 等待一个完成
                if let result = try await group.next() {
                    inFlight -= 1
                    switch result.1 {
                    case .success(let url):
                        results.append("✅ \(url.lastPathComponent)")
                    case .failure(let error):
                        failedCount += 1
                        results.append("❌ 失败: \(error.localizedDescription)")
                    }
                }
            }
        }

        let successCount = urls.count - failedCount
        let summary = """
        📊 下载完成
        成功: \(successCount) / \(urls.count)
        保存目录: \(directory.path)

        详情:
        \(results.joined(separator: "\n"))
        """

        return summary
    }
}
