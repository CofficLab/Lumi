import Foundation

/// Probe whether a single URL is reachable.
///
/// Ported from `LumiAppKit/Updates/FeedURLReachabilityChecker.swift` (v4.19.0).
/// The default implementation uses `URLSession` with a HEAD request and a
/// 5-second timeout; tests may inject `MockReachabilityChecker` to replace it.
public protocol FeedURLReachabilityChecker: Sendable {
    /// Probe whether `url` is reachable.
    /// - Parameter url: Target URL to probe.
    /// - Returns: `true` if reachable; any error counts as unreachable.
    func isReachable(_ url: URL) async -> Bool
}

/// Default `URLSession`-based reachability implementation.
public struct URLSessionReachabilityChecker: FeedURLReachabilityChecker {

    /// Request timeout in seconds. The original `UpdateService` used `5`.
    public let timeout: TimeInterval

    /// Injected session, so tests can swap the network stack.
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
