import Foundation

/// 更新生命周期状态
///
/// 从 `LumiApp/Services/UpdateService.swift` 拆分而来的纯状态机。
/// 仅负责状态转换规则，不依赖 Sparkle / AppKit。
public enum UpdateLifecycleState: String, Sendable {
    /// 空闲状态（未开始检查）
    case idle
    /// 正在检查更新
    case checking
    /// 正在下载更新
    case downloading
    /// 更新已准备好，等待安装
    case readyToInstall
    /// 正在安装更新（退出时）
    case installing
    /// 检查失败或下载失败
    case error
}

/// 更新生命周期状态机
///
/// 管理 `UpdateLifecycleState` 的转换规则，并记录待执行的安装回调。
/// 该类型是 `actor`，保证并发安全。
/// 
/// ## 职责
/// - 管理更新状态转换（idle → checking → downloading → readyToInstall → installing）
/// - 管理待执行的安装回调（Sparkle 提供的 `immediateInstallationBlock`）
/// - 管理最近检查到的更新版本号
/// - 管理本地 feed URL 缓存（供 Sparkle delegate 同步查询）
public actor UpdateServiceStateMachine {

    // MARK: - 存储

    /// 当前更新状态
    public private(set) var state: UpdateLifecycleState = .idle

    /// 待执行的安装回调（Sparkle 提供的 `immediateInstallationBlock`）
    private var pendingInstallHandler: (@Sendable () -> Void)?

    /// 当前生效的 feed URL（由 `FeedURLDetector` 提供）
    private let feedURLDetector: FeedURLDetector?

    /// 最近一次检查到的更新版本号（用于 UI 显示）
    public private(set) var latestVersion: String?

    /// 本地缓存的 feed URL（供 Sparkle delegate 同步查询）
    /// 
    /// 当 `FeedURLDetector` 探测完成后，会将结果同步到此属性，
    /// 供 `SPUUpdaterDelegate.feedURLString(for:)` 同步返回。
    public private(set) var cachedFeedURL: URL?

    // MARK: - 初始化

    /// 创建状态机实例
    /// - Parameter feedURLDetector: Feed URL 探测器（可选，用于查询当前生效的 feed URL）
    public init(feedURLDetector: FeedURLDetector? = nil) {
        self.feedURLDetector = feedURLDetector
    }

    // MARK: - 状态转换

    /// 标记开始检查更新
    public func beginChecking() {
        state = .checking
    }

    /// 标记开始下载更新
    public func beginDownloading() {
        state = .downloading
    }

    /// 标记更新已准备好，记录安装回调和版本号
    /// - Parameters:
    ///   - version: Sparkle 返回的 `SUAppcastItem.displayVersionString`。
    ///   - installHandler: Sparkle 提供的 `immediateInstallationBlock`。
    public func markReadyToInstall(
        version: String,
        installHandler: @escaping @Sendable () -> Void
    ) {
        state = .readyToInstall
        latestVersion = version
        pendingInstallHandler = installHandler
    }

    /// 标记开始安装（退出时）
    public func beginInstalling() {
        state = .installing
    }

    /// 标记检查或下载失败
    public func markError() {
        state = .error
    }

    /// 重置为空闲状态
    public func reset() {
        state = .idle
        latestVersion = nil
        pendingInstallHandler = nil
    }

    // MARK: - Feed URL 管理

    /// 同步获取当前缓存的 feed URL
    /// 
    /// 供 `SPUUpdaterDelegate.feedURLString(for:)` 同步调用。
    /// - Returns: 当前缓存的 feed URL，如果尚未探测则返回 nil。
    public nonisolated func syncGetCurrentFeedURL() async -> URL? {
        return await self.cachedFeedURL
    }

    /// 更新本地 feed URL 缓存
    /// 
    /// 当 `FeedURLDetector` 探测完成后，调用此方法同步结果。
    /// - Parameter url: 探测到的可用 feed URL
    public func updateCachedFeedURL(_ url: URL) {
        cachedFeedURL = url
    }

    /// 从 FeedURLDetector 同步最新的 feed URL 到本地缓存
    /// 
    /// 供 App 层在探测完成后调用，确保缓存与探测器一致。
    public func syncFromDetector() async {
        guard let detector = feedURLDetector else { return }
        let url = await detector.resolvedFeedURL
        cachedFeedURL = url
    }

    // MARK: - 安装回调管理

    /// 执行待安装的回调（如果存在）
    /// - Returns: 是否成功执行了安装回调。
    public func executePendingInstallHandler() -> Bool {
        guard let handler = pendingInstallHandler else { return false }
        state = .installing
        pendingInstallHandler = nil
        handler()
        return true
    }

    /// 是否有待安装的更新
    public var hasPendingInstall: Bool {
        pendingInstallHandler != nil
    }
}
