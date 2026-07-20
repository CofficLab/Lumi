import Foundation
import os

/// Provides the update feed URL, with reachability checking and fallback.
@MainActor
final class UpdateFeedURLProvider {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "update.feed")

    /// The resolved feed URL, or `nil` if unavailable.
    @MainActor private(set) static var feedURL: URL?

    /// Resolves the feed URL from the bundle, checking reachability.
    /// Returns the URL if reachable, `nil` otherwise.
    @MainActor
    static func resolveFeedURL() async -> URL? {
        guard let detectedURL = FeedURLDetector.detectFeedURL() else {
            logger.info("No feed URL detected in bundle")
            return nil
        }

        let isReachable = await FeedURLReachabilityChecker.checkReachability(of: detectedURL)
        guard isReachable else {
            logger.info("Feed URL not reachable: \(detectedURL)")
            return nil
        }

        feedURL = detectedURL
        logger.info("Feed URL resolved: \(detectedURL)")
        return detectedURL
    }
}
