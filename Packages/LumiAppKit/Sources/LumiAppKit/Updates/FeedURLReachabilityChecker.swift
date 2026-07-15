import Foundation

/// 探测单个 URL 是否可达
///
/// 拆分自 `UpdateService.isURLReachable(_:)`。
/// 默认实现使用 `URLSession` 发送 HEAD 请求并以 5 秒超时等待响应；
/// 测试可通过注入 `MockReachabilityChecker` 替换。
public protocol FeedURLReachabilityChecker: Sendable {
    /// 探测 `url` 是否可达。
    /// - Parameter url: 待探测的目标 URL。
    /// - Returns: 探测完成时返回是否可达；任何错误视为不可达。
    func isReachable(_ url: URL) async -> Bool
}

/// 基于 `URLSession` 的默认可达性实现。
public struct URLSessionReachabilityChecker: FeedURLReachabilityChecker {

    /// 请求超时（秒）。原 `UpdateService` 使用 `5` 秒。
    public let timeout: TimeInterval

    /// 注入的 session，便于测试中替换网络栈。
    public let session: URLSession

    public init(
        timeout: TimeInterval = 5,
        session: URLSession = .shared
    ) {
        self.timeout = timeout
        self.session = session
    }

    public func isReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}