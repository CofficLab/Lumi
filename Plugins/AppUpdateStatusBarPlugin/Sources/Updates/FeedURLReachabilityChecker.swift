import Foundation
import os

/// Checks whether the feed URL's server is reachable.
enum FeedURLReachabilityChecker {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "update.reachability")

    /// Checks if the given URL is reachable (returns HTTP 200).
    static func checkReachability(of url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.debug("Non-HTTP response for \(url)")
                return false
            }
            let ok = (200...299).contains(httpResponse.statusCode)
            if !ok {
                logger.debug("HTTP \(httpResponse.statusCode) for \(url)")
            }
            return ok
        } catch {
            logger.debug("Reachability check failed for \(url): \(error)")
            return false
        }
    }
}
