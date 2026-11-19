import AppKit
import ProviderAppUpdate
import ProviderNetwork
import Sparkle
import LumiLoggingKit
import os

/// Core update service integrating Sparkle.
///
/// Ported from `LumiAppKit/Services/UpdateService.swift` (v4.19.0).
/// Owns the `SPUStandardUpdaterController`, manages feed URL detection via
/// `FeedURLDetector`, and exposes public entry points for the rest of the app:
///
/// - `setupFeedURLIfNeeded()` — called once from `MacAgent.applicationDidFinishLaunching`
/// - `checkForUpdates()` — invoked from the app menu, menu bar popover, or About page
/// - `ensureUpdaterInitialized()` — lazy init of the Sparkle controller
///
/// Cross-plugin communication uses `NotificationCenter` so callers (e.g.
/// `MenuBarManagerPlugin`) do not need a hard dependency on `AppUpdatePlugin`.
@MainActor
public final class UpdateService: NSObject, SPUUpdaterDelegate, SuperLog, AppUpdateChannelProviding {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.updater")
    nonisolated public static let emoji = "⬆️"
    nonisolated public static let verbose = false

    public static let shared = UpdateService()

    /// Lazy-initialized Sparkle controller.
    /// Created on first use to avoid blocking app startup.
    public private(set) var updaterController: SPUStandardUpdaterController?

    /// Sparkle 初始化替身（#234）。生产为 nil，走真实创建；测试注入后
    /// `ensureUpdaterInitialized()` 只记录调用，不在测试进程里拉起 Sparkle。
    var updaterInitializationStub: (() -> Void)?

    /// Sparkle 检查替身（#235）。生产为 nil，走真实 `updaterController`；
    /// 测试注入后 `checkForUpdates` 只记录调用，用于断言检查是否真的发生。
    var sparkleCheckStub: (() -> Void)?

    /// Feed URL detector (actor). Network probes run off the main actor.
    private var feedURLDetector: FeedURLDetector?

    /// In-flight feed URL preparation shared by startup and manual checks.
    private var feedPreparationTask: Task<Void, Never>?

    /// In-flight channel update that must complete before feed detection starts.
    private var feedConfigurationTask: Task<Void, Never>?

    /// Feed 准备代次：通道切换/重配置都会递增（#235）。
    /// 等待旧准备的检查用它识别「我等的准备已经被作废」。
    private var feedPreparationGeneration = 0

    /// Update lifecycle state machine (tracks state + version only).
    private let stateMachine = UpdateServiceStateMachine()

    /// Currently effective feed URL.
    ///
    /// Initial value is the primary feed; updated to the reachable URL after
    /// `setupFeedURLIfNeeded()` completes. Kept as a plain stored property so
    /// `feedURLString(for:)` (synchronous delegate callback) can read it directly.
    private var resolvedFeedURL: URL = UpdateFeedURLProvider.primary

    /// Selected release channel. Persisted independently from Sparkle's own
    /// preferences so switching channels never changes updater internals.
    public private(set) var channel: AppUpdateChannel

    /// 通道持久化存储。可注入隔离实例以测试落盘失败路径（#524）。
    private let store: AppUpdatePluginLocalStore

    /// 暂存安装目录解析用的缓存根注入点（#522）。测试传临时目录；
    /// 生产为 nil，走真实用户缓存目录。
    var stagedInstallationCachesRootOverride: URL?

    /// Sparkle 最近一次请求 feed URL 时生效的通道（#522）。
    ///
    /// Sparkle 的检查会话以该次请求的 feed 发现更新，之后才下载并暂存；
    /// 若在「检查 → 暂存」窗口内切换通道，暂存的便是被放弃通道的更新。
    /// `willInstallUpdateOnQuit` 用它与当前通道比对，识别这类迟到暂存。
    private var channelAtLastFeedURLRequest: AppUpdateChannel?

    /// Convenience access to the underlying `SPUUpdater`.
    public var updater: SPUUpdater? {
        updaterController?.updater
    }

    init(
        store: AppUpdatePluginLocalStore = .shared,
        feedURLDetector: FeedURLDetector? = nil
    ) {
        self.store = store
        channel = store.channel
        self.feedURLDetector = feedURLDetector
        super.init()
    }

    // MARK: - Public API

    public func configure(network: any NetworkProviding) {
        feedPreparationTask?.cancel()
        feedPreparationTask = nil
        feedConfigurationTask?.cancel()
        feedConfigurationTask = nil
        feedPreparationGeneration &+= 1
        resolvedFeedURL = UpdateFeedURLProvider.primary(for: channel)
        feedURLDetector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary(for: channel),
            reachabilityChecker: ProviderNetworkReachabilityChecker(network: network),
            fallbackURL: UpdateFeedURLProvider.fallback(for: channel)
        )
    }

    /// Persist and immediately apply the selected update channel.
    ///
    /// 先落盘再应用：持久化失败时保留旧选择并记录错误，UI（绑定 `channel`）
    /// 不会把未保存的通道当作已生效，重启后也不会悄悄回退（#524）。
    public func setChannel(_ channel: AppUpdateChannel) {
        guard self.channel != channel else { return }

        do {
            try store.setChannel(channel)
        } catch {
            Self.logger.error("\(Self.t)Failed to persist update channel: \(error.localizedDescription, privacy: .public)")
            return
        }

        self.channel = channel
        resolvedFeedURL = UpdateFeedURLProvider.primary(for: channel)
        feedPreparationTask?.cancel()
        feedPreparationTask = nil
        feedConfigurationTask?.cancel()
        feedConfigurationTask = nil
        feedPreparationGeneration &+= 1

        if let feedURLDetector {
            let primaryURL = UpdateFeedURLProvider.primary(for: channel)
            let fallbackURL = UpdateFeedURLProvider.fallback(for: channel)
            feedConfigurationTask = Task { [feedURLDetector] in
                await feedURLDetector.updateFeedURLs(
                    primary: primaryURL,
                    fallback: fallbackURL
                )
            }
        }

        // 通道切换后必须重新准备 feed（#236）：上面只把 resolvedFeedURL 置为
        // 新通道主源，尚未探测。Sparkle 的后台检查会同步读取该 URL，若不在
        // 这里排入探测任务，新通道主源不可达时会一直用不可达的主源，直到
        // 手动检查或重启。prepareFeedURLIfNeeded 会先等 updateFeedURLs 完成
        // 再探测（updateFeedURLs 已清除缓存窗口）。
        _ = prepareFeedURLIfNeeded()

        // 作废旧通道已暂存的安装（#522）：Sparkle 暂存后总是会在应用终止时
        // 尝试安装（公开 API 无法取消，见 removeSparkleStagedInstallation），
        // 切换通道后必须移除暂存产物，否则用户刚放弃的通道仍会被装上。
        removeSparkleStagedInstallation()
    }

    /// Lazily initialize the Sparkle updater controller.
    ///
    /// The original implementation deferred initialization to avoid blocking the
    /// main thread at launch. This method is idempotent.
    public func ensureUpdaterInitialized() {
        guard AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }
        guard updaterController == nil else { return }

        if let updaterInitializationStub {
            updaterInitializationStub()
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        // Clear any legacy `setFeedURL` residue so the delegate-provided URL takes effect.
        _ = controller.updater.clearFeedURLFromUserDefaults()
        if Self.verbose {
            Self.logger.info("\(Self.t)Initial feed URL: \(self.resolvedFeedURL.absoluteString, privacy: .public)")
        }
        controller.startUpdater()
        self.updaterController = controller
    }

    /// Detect the reachable feed URL and start the updater.
    ///
    /// Called once from `MacAgent.applicationDidFinishLaunching`. The
    /// preparation task is shared with manual checks so a check requested
    /// during startup cannot race feed selection.
    public func setupFeedURLIfNeeded() {
        guard AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }
        _ = prepareFeedURLIfNeeded()
    }

    /// Start feed URL preparation once and reuse it while it is in flight.
    ///
    /// The detector is an actor, so awaiting it does not block the main actor.
    /// Once the task finishes, the cached URL is copied to the synchronous
    /// Sparkle delegate property and the task slot is released.
    @discardableResult
    private func prepareFeedURLIfNeeded() -> Task<Void, Never>? {
        guard let feedURLDetector else { return nil }
        if let feedPreparationTask {
            return feedPreparationTask
        }

        let channel = self.channel
        let configurationTask = feedConfigurationTask
        let task = Task { @MainActor [weak self, feedURLDetector, channel, configurationTask] in
            await configurationTask?.value
            guard !Task.isCancelled else { return }
            await feedURLDetector.detectIfNeeded()
            guard let self, self.channel == channel else { return }

            let url = await feedURLDetector.resolvedFeedURL
            self.resolvedFeedURL = url
            self.feedPreparationTask = nil
            if Self.verbose {
                Self.logger.info("\(Self.t)Feed URL set to: \(url.absoluteString, privacy: .public)")
            }
            // Feed 就绪后确保 Sparkle 已启动（#234）：此前只有手动检查才会
            // 初始化 updater，配置的自动检查在用户手动触发前永远不会运行。
            // 这里是「feed 可用」的唯一汇聚点，启动/手动检查/通道切换三条
            // 路径共用；ensureUpdaterInitialized 幂等，重复调用无害。
            self.ensureUpdaterInitialized()
        }
        feedPreparationTask = task
        return task
    }

    /// 等待在途的 feed 配置与探测任务结束后，返回当前生效的 feed URL。
    /// 仅供测试观察通道切换后的最终状态（#236）。
    func feedURLAfterPendingPreparation() async -> URL {
        if let feedConfigurationTask {
            await feedConfigurationTask.value
        }
        if let feedPreparationTask {
            await feedPreparationTask.value
        }
        return resolvedFeedURL
    }

    /// Trigger an immediate update check.
    public func checkForUpdates() {
        guard AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }

        guard let preparationTask = prepareFeedURLIfNeeded() else {
            ensureUpdaterInitialized()
            performSparkleCheck()
            return
        }

        let generation = feedPreparationGeneration
        Task { @MainActor [weak self] in
            await preparationTask.value
            guard let self, AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }
            // 等待期间通道可能已切走（#235）：迟到的旧准备结果不得驱动
            // 新通道的 Sparkle 检查——此时 resolvedFeedURL 是新通道尚未
            // 探测的主源，备用源选择会被绕过。旧检查直接丢弃。
            guard self.feedPreparationGeneration == generation else { return }
            self.ensureUpdaterInitialized()
            self.performSparkleCheck()
        }
    }

    private func performSparkleCheck() {
        if let sparkleCheckStub {
            sparkleCheckStub()
        } else {
            updaterController?.checkForUpdates(nil)
        }
    }

    /// Current update lifecycle state (for UI display).
    public var currentState: UpdateLifecycleState {
        get async {
            await stateMachine.state
        }
    }

    /// Most recently detected update version (for UI display).
    public var latestVersion: String? {
        get async {
            await stateMachine.latestVersion
        }
    }

    // MARK: - SPUUpdaterDelegate

    public func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        // 迟到的旧通道暂存（#522）：检查发起后、暂存完成前切走通道，这里的
        // 暂存产物属于被放弃的通道，必须在终止安装前作废。
        invalidateStagedInstallIfChannelChanged()
        Task {
            await stateMachine.markReadyToInstall(version: item.displayVersionString)
        }
        NotificationCenter.postAppUpdateReadyToInstall(version: item.displayVersionString)
        // Let Sparkle's standard user driver own installation and relaunch UI.
        // Returning true would make this service responsible for invoking the
        // callback, but there is no custom install UI here.
        return false
    }

    /// Sparkle's recommended way to provide the feed URL dynamically.
    /// Called on every update check; returns the currently detected reachable URL.
    ///
    /// Synchronous because `SPUUpdaterDelegate` requires it. `resolvedFeedURL`
    /// is a plain `@MainActor` stored property, and this delegate method runs
    /// on the main actor, so the read is safe and cheap.
    public func feedURLString(for updater: SPUUpdater) -> String? {
        noteFeedURLRequested()
        return resolvedFeedURL.absoluteString
    }

    // MARK: - 暂存安装作废（#522）

    /// 记录 Sparkle 请求 feed URL 时生效的通道（供暂存归属比对）。
    /// 测试直接调用以模拟检查发起时刻。
    func noteFeedURLRequested() {
        channelAtLastFeedURLRequest = channel
    }

    /// 暂存产物属于被放弃通道时移除之；通道一致时保持不动，
    /// 正常静默安装不受影响。
    func invalidateStagedInstallIfChannelChanged() {
        guard let requested = channelAtLastFeedURLRequest, requested != channel else { return }
        Self.logger.info("\(Self.t)Staged update belongs to abandoned channel; invalidating it")
        removeSparkleStagedInstallation()
    }

    /// Sparkle 2.x 的暂存安装目录约定（SPULocalCacheDirectory）：
    /// `<Caches>/<hostBundleID>/org.sparkle-project.Sparkle/Installation`。
    ///
    /// 暂存后 Sparkle 总会在应用终止时尝试安装（公开 API 无法取消，取消消息
    /// `SPUCancelInstallation` 仅内部可达）；移除该目录后工具的 stage-2 找不到
    /// 暂存产物会报错退出，不执行安装。目录不存在时为 no-op——Sparkle 未来
    /// 改变缓存布局时，本作废机制随之失效但不会产生新的破坏。
    static func sparkleStagedInstallationDirectory(
        inCachesRoot cachesRoot: URL,
        hostBundleIdentifier: String
    ) -> URL {
        cachesRoot
            .appendingPathComponent(hostBundleIdentifier, isDirectory: true)
            .appendingPathComponent("org.sparkle-project.Sparkle", isDirectory: true)
            .appendingPathComponent("Installation", isDirectory: true)
    }

    /// 移除 Sparkle 已暂存的安装产物（目录不存在时静默跳过）。
    func removeSparkleStagedInstallation() {
        let cachesRoot: URL?
        if let override = stagedInstallationCachesRootOverride {
            cachesRoot = override
        } else {
            cachesRoot = try? FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
        }
        guard let cachesRoot else { return }
        let hostBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        let directory = Self.sparkleStagedInstallationDirectory(
            inCachesRoot: cachesRoot,
            hostBundleIdentifier: hostBundleIdentifier
        )
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        do {
            try FileManager.default.removeItem(at: directory)
            Self.logger.info("\(Self.t)Removed staged Sparkle installation at \(directory.path, privacy: .public)")
        } catch {
            Self.logger.error("\(Self.t)Failed to remove staged Sparkle installation: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notification Handlers

    @objc func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    @objc func handleInstallPreparedAppUpdateRequest() {
        // Keep this notification endpoint for compatibility with older callers.
        // Installation and relaunch are owned by Sparkle's standard user driver.
    }
}
