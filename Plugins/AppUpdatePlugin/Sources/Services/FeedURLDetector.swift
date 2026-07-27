import Foundation

/// Probe which Sparkle feed URL should be used.
///
/// Ported from `LumiAppKit/Updates/FeedURLDetector.swift` (v4.19.0).
/// The type is intentionally free of Sparkle dependencies; the app layer
/// composes it to feed `SPUUpdaterDelegate.feedURLString(for:)`.
///
/// Responsibilities:
/// 1. 30-minute cache window (avoid HEAD requests on every check);
/// 2. Injectable reachability probing (default `URLSessionReachabilityChecker`);
/// 3. Primary → fallback decision;
/// 4. Expose the current feed URL for the Sparkle delegate to read.
public actor FeedURLDetector {

    // MARK: - Constants

    /// Probe cache window. Reuses the previous result within 30 minutes.
    /// Original value taken from `LumiApp/Services/UpdateService.swift` line 112.
    public static let defaultCacheWindow: TimeInterval = 30 * 60

    // MARK: - Storage

    /// Currently effective feed URL. Initially `primary`; updated to the
    /// reachable URL after the first `detectIfNeeded()` call.
    public private(set) var resolvedFeedURL: URL

    /// Timestamp of the last probe; used for cache window decisions.
    private var lastDetectionTime: Date?

    /// Injected reachability checker.
    private let reachabilityChecker: FeedURLReachabilityChecker

    /// Cache window; overridable for tests.
    private let cacheWindow: TimeInterval

    /// Time source, so tests can inject a virtual clock.
    private let clock: @Sendable () -> Date

    // MARK: - Init

    /// - Parameters:
    ///   - initialURL: Initial feed URL. Production uses `UpdateFeedURLProvider.primary`.
    ///   - reachabilityChecker: Reachability checker. Default `URLSessionReachabilityChecker()`.
    ///   - cacheWindow: Probe cache window. Default `defaultCacheWindow` (30 minutes).
    ///   - clock: Time source. Default `Date.init`. Tests may inject a virtual clock.
    public init(
        initialURL: URL,
        reachabilityChecker: FeedURLReachabilityChecker = URLSessionReachabilityChecker(),
        cacheWindow: TimeInterval = FeedURLDetector.defaultCacheWindow,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.resolvedFeedURL = initialURL
        self.reachabilityChecker = reachabilityChecker
        self.cacheWindow = cacheWindow
        self.clock = clock
    }

    // MARK: - Public

    /// Re-probe the available feed URL outside the cache window and update `resolvedFeedURL`.
    public func detectIfNeeded() async {
        if let lastDetectionTime,
           clock().timeIntervalSince(lastDetectionTime) < cacheWindow {
            return
        }

        lastDetectionTime = clock()

        let primary = UpdateFeedURLProvider.primary
        let fallback = UpdateFeedURLProvider.fallback
        let detectedURL = await Self.detectFeedURL(
            primary: primary,
            fallback: fallback,
            reachabilityChecker: reachabilityChecker
        )

        resolvedFeedURL = detectedURL
    }

    /// Force an immediate cache reset and re-probe.
    /// Used when the app recovers from "no network".
    public func forceRedetect() async {
        lastDetectionTime = nil
        await detectIfNeeded()
    }

    // MARK: - Private

    /// Detect which feed URL is available.
    /// - Parameters:
    ///   - primary: Primary feed URL (owned server).
    ///   - fallback: Fallback feed URL (GitHub Release).
    ///   - reachabilityChecker: Injected reachability checker.
    /// - Returns: `primary` if reachable, otherwise `fallback`.
    static func detectFeedURL(
        primary: URL,
        fallback: URL,
        reachabilityChecker: FeedURLReachabilityChecker
    ) async -> URL {
        if await reachabilityChecker.isReachable(primary) {
            return primary
        }
        return fallback
    }
}
