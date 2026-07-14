import Foundation

/// 探测当前应使用的 Sparkle feed URL
///
/// 拆分自 `LumiApp/Services/UpdateService.setupFeedURLIfNeeded()` 与
/// `detectFeedURL(primary:fallback:)`。该类型仅负责纯逻辑：
///   1. 30 分钟缓存窗口（避免每次检查都发起 HEAD 请求）；
///   2. 注入式可达性探测（默认 `URLSessionReachabilityChecker`）；
///   3. 主→备 fallback 决策；
///   4. 提供当前生效的 feed URL 供 Sparkle Delegate 读取。
///
/// 该类型**故意不**依赖 Sparkle 自身；App 层通过组合它来向
/// `SPUUpdaterDelegate.feedURLString(for:)` 提供返回值。
public actor FeedURLDetector {

    // MARK: - 常量

    /// 探测缓存窗口。30 分钟内复用上一次结果，原始值取自
    /// `LumiApp/Services/UpdateService.swift` 第 112 行。
    public static let defaultCacheWindow: TimeInterval = 30 * 60

    // MARK: - 存储

    /// 当前生效的 feed URL。初始为 `primary`，
    /// 首次 `detectIfNeeded()` 后会被更新为可达的 URL。
    public private(set) var resolvedFeedURL: URL

    /// 上一次探测时间戳；用于缓存窗口判定。
    private var lastDetectionTime: Date?

    /// 注入的可达性探测器。
    private let reachabilityChecker: FeedURLReachabilityChecker

    /// 缓存窗口；可被测试覆盖。
    private let cacheWindow: TimeInterval

    /// 时间源，便于测试中注入虚拟时钟。
    private let clock: @Sendable () -> Date

    // MARK: - 初始化

    /// - Parameters:
    ///   - initialURL: 初始 feed URL。生产中传 `UpdateFeedURLProvider.primary`。
    ///   - reachabilityChecker: 可达性探测器。默认 `URLSessionReachabilityChecker()`。
    ///   - cacheWindow: 探测缓存窗口。默认 `defaultCacheWindow`（30 分钟）。
    ///   - clock: 时间源。默认 `Date.init`。测试可注入虚拟时钟。
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

    // MARK: - 公开方法

    /// 在缓存窗口外重新探测可用 feed URL，并更新 `resolvedFeedURL`。
    ///
    /// 线程模型：在 `actor` 上执行，调用方可在任意并发上下文。
    /// 该方法内部使用 `Task` 触发网络探测；并发安全由 actor 串行保证。
    public func detectIfNeeded() async {
        if let lastDetectionTime,
           clock().timeIntervalSince(lastDetectionTime) < cacheWindow {
            return
        }

        lastDetectionTime = clock()

        let primary = await resolvePrimaryFeedURL()
        let fallback = await resolveFallbackFeedURL()
        let detectedURL = await Self.detectFeedURL(
            primary: primary,
            fallback: fallback,
            reachabilityChecker: reachabilityChecker
        )

        resolvedFeedURL = detectedURL
    }

    /// 强制立即重置探测缓存并重新探测。
    /// 用于 App 从"无网络"恢复后的强制刷新场景。
    public func forceRedetect() async {
        lastDetectionTime = nil
        await detectIfNeeded()
    }

    // MARK: - 私有方法

    /// 获取主 feed URL：先取注入值（测试），否则用全局常量。
    /// 该方法分离出来便于测试中覆盖 primary（默认实现是常量切换）。
    private func resolvePrimaryFeedURL() async -> URL { UpdateFeedURLProvider.primary }

    /// 获取备用 feed URL：先取注入值（测试），否则用全局常量。
    private func resolveFallbackFeedURL() async -> URL { UpdateFeedURLProvider.fallback }

    /// 检测哪个 feed URL 可用
    /// - Parameters:
    ///   - primary: 主 feed URL（自有服务器）。
    ///   - fallback: 备用 feed URL（GitHub Release）。
    ///   - reachabilityChecker: 注入的可达性探测器。
    /// - Returns: 主可达时返回 `primary`，否则返回 `fallback`。
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