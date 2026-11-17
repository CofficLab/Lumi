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

    /// Feed URL detector (actor). Network probes run off the main actor.
    private var feedURLDetector: FeedURLDetector?

    /// In-flight feed URL preparation shared by startup and manual checks.
    private var feedPreparationTask: Task<Void, Never>?

    /// In-flight channel update that must complete before feed detection starts.
    private var feedConfigurationTask: Task<Void, Never>?

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
            updaterController?.checkForUpdates(nil)
            return
        }

        Task { @MainActor [weak self] in
            await preparationTask.value
            guard let self, AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }
            self.ensureUpdaterInitialized()
            self.updaterController?.checkForUpdates(nil)
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
        resolvedFeedURL.absoluteString
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
