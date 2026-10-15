import Foundation
import ProviderNetwork

/// Probe whether a single URL is reachable.
///
/// Ported from `LumiAppKit/Updates/FeedURLReachabilityChecker.swift` (v4.19.0).
/// Production uses Kernel network; tests may inject a mock checker.
public protocol FeedURLReachabilityChecker: Sendable {
    /// Probe whether `url` is reachable.
    /// - Parameter url: Target URL to probe.
    /// - Returns: `true` if reachable; any error counts as unreachable.
    func isReachable(_ url: URL) async -> Bool
}

/// Provider-backed reachability implementation.
public struct ProviderNetworkReachabilityChecker: FeedURLReachabilityChecker {

    /// Request timeout in seconds. The original `UpdateService` used `5`.
    public let timeout: TimeInterval

    private let network: any NetworkProviding

    public init(
        network: any NetworkProviding,
        timeout: TimeInterval = 5,
    ) {
        self.network = network
        self.timeout = timeout
    }

    public func isReachable(_ url: URL) async -> Bool {
        do {
            let response = try await network.request(
                HTTPRequest(url: url, method: .head, timeout: timeout)
            )
            return response.statusCode == 200
        } catch {
            return false
        }
    }
}
