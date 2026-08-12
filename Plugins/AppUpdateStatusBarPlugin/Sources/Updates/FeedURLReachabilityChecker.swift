import Foundation
import LumiKernel
import os

/// Checks whether the feed URL's server is reachable.
enum FeedURLReachabilityChecker {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "update.reachability")

    /// Checks if the given URL is reachable (returns HTTP 200).
    static func checkReachability(of url: URL, network: any NetworkProviding) async -> Bool {
        do {
            let response = try await network.request(
                HTTPRequest(url: url, method: .head, timeout: 10)
            )
            let ok = (200...299).contains(response.statusCode)
            if !ok {
                logger.debug("HTTP \(response.statusCode) for \(url)")
            }
            return ok
        } catch {
            logger.debug("Reachability check failed for \(url): \(error)")
            return false
        }
    }
}
