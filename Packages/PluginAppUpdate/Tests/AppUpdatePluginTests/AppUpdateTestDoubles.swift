import Foundation
import ProviderNetwork
import ProviderStorage

/// App Update 插件测试共用的 Provider 替身。
///
/// 目标是把「宿主引导 / 网络探测 / 存储目录」这条链路测清楚，与真实持久化和
/// 真实网络无关。
enum AppUpdateTestDoubles {

    // MARK: - NetworkProviding

    /// 可记录请求、并按预设状态码或错误回应的网络替身。
    ///
    /// `NetworkProviding` 要求 `Sendable`，因此这里用锁保护可变状态。
    final class StubNetworkProvider: NetworkProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [HTTPRequest] = []
        private let statusCode: Int
        private let failure: Error?

        init(statusCode: Int = 200, failure: Error? = nil) {
            self.statusCode = statusCode
            self.failure = failure
        }

        /// 记录下来的请求，按发生顺序。
        var requests: [HTTPRequest] {
            lock.withLock { recorded }
        }

        func request(_ request: HTTPRequest) async throws -> HTTPResponse {
            lock.withLock { recorded.append(request) }

            if let failure { throw failure }
            return HTTPResponse(
                statusCode: statusCode,
                headers: [:],
                body: Data(),
                url: request.url
            )
        }

        func stream(
            _ request: HTTPRequest,
            onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
            onChunk: @Sendable @escaping (Data) async -> Bool
        ) async throws {}

        func get(
            url: URL,
            headers: [String: String],
            timeout: TimeInterval
        ) async throws -> HTTPResponse {
            try await request(HTTPRequest(url: url, method: .get, headers: headers, timeout: timeout))
        }

        func post(
            url: URL,
            body: Data,
            contentType: String,
            headers: [String: String],
            timeout: TimeInterval
        ) async throws -> HTTPResponse {
            var merged = headers
            merged["Content-Type"] = contentType
            return try await request(
                HTTPRequest(url: url, method: .post, headers: merged, body: body, timeout: timeout)
            )
        }

        func json<T: Sendable, R: Sendable>(
            url: URL,
            method: HTTPMethod,
            body: T,
            headers: [String: String],
            timeout: TimeInterval
        ) async throws -> R where T: Encodable, R: Decodable {
            let encoded = try JSONEncoder().encode(body)
            let response = try await request(
                HTTPRequest(url: url, method: method, headers: headers, body: encoded, timeout: timeout)
            )
            return try JSONDecoder().decode(R.self, from: response.body)
        }

        func download(
            from url: URL,
            to destination: URL,
            headers: [String: String],
            timeout: TimeInterval
        ) async throws -> URL {
            let response = try await request(
                HTTPRequest(url: url, method: .get, headers: headers, timeout: timeout)
            )
            try response.body.write(to: destination)
            return destination
        }
    }

    /// 指向临时目录的存储替身。
    final class StubStorageProvider: StorageProviding {
        let root: URL

        init(root: URL) {
            self.root = root
        }

        var dataRootDirectory: URL { root }

        func pluginDataDirectory(for pluginID: String) -> URL {
            root.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            root.appendingPathComponent("core", isDirectory: true)
        }
    }

    // MARK: - 辅助

    /// 创建一个本次测试独占的临时目录。
    static func makeTemporaryDirectory(_ label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppUpdateTests-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
