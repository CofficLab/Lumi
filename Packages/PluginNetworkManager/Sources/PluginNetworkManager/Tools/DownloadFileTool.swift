import KitAgentTool
import Foundation
import LumiLoggingKit
/// 下载文件工具
///
/// 使用 URLSession 下载文件到本地磁盘。
struct DownloadFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📥"
    nonisolated static let verbose = false

    typealias DownloadHandler = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias ExchangeStoreProvider = @MainActor @Sendable () -> HTTPExchangeStore?

    let name = "network_download_file"

    /// 实际传输实现。默认走 `URLSession.shared`，测试可注入以隔离真实网络。
    private let download: DownloadHandler

    /// exchange 记录来源。默认取插件共享 store，测试可注入独立实例，
    /// 避免并行测试互相覆盖全局 store。
    private let exchangeStore: ExchangeStoreProvider

    init(
        download: @escaping DownloadHandler = { try await URLSession.shared.data(for: $0) },
        exchangeStore: @escaping ExchangeStoreProvider = { NetworkService.shared.currentExchangeStore }
    ) {
        self.download = download
        self.exchangeStore = exchangeStore
    }

    func description(for language: LanguagePreference) -> String {
        "Download a file from URL using the system's NetworkManager service. Supports HTTP/HTTPS. Returns the local file path after successful download."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "文件下载链接 (HTTP/HTTPS)",
                ],
                "filename": [
                    "type": "string",
                    "description": "可选，保存的文件名。不提供则使用 URL 中的文件名",
                ],
                "directory": [
                    "type": "string",
                    "description": "可选，保存目录的绝对路径。不提供则使用临时目录",
                ],
            ],
            "required": ["url"],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let urlString = NetworkToolSupport.string(arguments, "url"),
           let url = URL(string: urlString) {
            let name = url.lastPathComponent
            if !name.isEmpty && name != "/" {
                return "下载 \(name)"
            }
        }
        return "下载文件"
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = NetworkToolSupport.string(arguments, "url"),
              let url = URL(string: urlString) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "无效的 URL")
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "仅支持 HTTP/HTTPS 协议")
        }

        // 确定文件名
        let filename: String
        if let customName = NetworkToolSupport.string(arguments, "filename"), !customName.isEmpty {
            filename = customName
        } else {
            filename = extractFilename(from: url)
        }

        // 确定保存目录
        let directory: URL
        if let dirPath = NetworkToolSupport.string(arguments, "directory") {
            let dirURL = URL(fileURLWithPath: dirPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory) || !isDirectory.boolValue {
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "目录不存在或不是有效的目录: \(dirPath)"
                )
            }
            directory = dirURL
        } else {
            directory = FileManager.default.temporaryDirectory
        }

        let destination = directory.appendingPathComponent(filename)
        let request = URLRequest(url: url)

        // 使用 URLSession 下载；成功与失败都必须写入 HTTP exchange，否则
        // HTTP Logs、统计与 domain 导出会完全漏掉这次下载（#977）。
        do {
            let (data, response) = try await Self.performInstrumentedDownload(
                request: request,
                download: download,
                exchangeStore: exchangeStore
            )

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "下载失败: HTTP \(statusCode)\nURL: \(url.absoluteString)"
                )
            }

            try data.write(to: destination)
            let size = fileSizeString(at: destination)
            return """
            ✅ 下载完成
            文件名: \(filename)
            大小: \(size)
            路径: \(destination.path)
            """
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "下载失败: \(error.localizedDescription)\nURL: \(url.absoluteString)"
            )
        }
    }

    /// 在 `HTTPExchangeStore` 上为该下载请求收口一条 exchange 记录。
    ///
    /// `begin`/`finish` 都要求主线程（SwiftData `ModelContext`），网络等待在
    /// 两者之间进行，因此整个方法留在 MainActor 上，`await` 期间不会阻塞 UI。
    @MainActor
    private static func performInstrumentedDownload(
        request: URLRequest,
        download: DownloadHandler,
        exchangeStore: ExchangeStoreProvider
    ) async throws -> (Data, URLResponse) {
        let store = exchangeStore()
        let record = store?.begin(request: request)
        do {
            let result = try await download(request)
            store?.finish(record, response: result.1, body: result.0)
            return result
        } catch {
            store?.finish(record, error: error)
            throw error
        }
    }

    private func extractFilename(from url: URL) -> String {
        let pathComponent = url.lastPathComponent
        if !pathComponent.isEmpty, pathComponent != "/", !pathComponent.contains("?") {
            return pathComponent
        }

        if let query = url.query {
            let pairs = query.components(separatedBy: "&")
            for pair in pairs {
                let keyValue = pair.components(separatedBy: "=")
                if keyValue.count == 2 {
                    let key = keyValue[0]
                    let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                    if key.lowercased() == "filename" || key.lowercased() == "file" {
                        return value
                    }
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "download_\(formatter.string(from: Date()))"
    }

    private func fileSizeString(at url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else { return "unknown" }
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
