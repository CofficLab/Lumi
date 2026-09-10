import AppKit
import ProviderAppUpdate
import ProviderNetwork
import Sparkle
import KitSuperLog
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

    /// Feed URL detector (actor). Network probes run off the main actor.
    private var feedURLDetector: FeedURLDetector?

    /// In-flight feed URL preparation shared by startup and manual checks.
    private var feedPreparationTask: Task<Void, Never>?

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

    private static func loadChannel() -> AppUpdateChannel {
        guard let rawValue = UserDefaults.standard.string(forKey: AppUpdateChannel.userDefaultsKey),
              let channel = AppUpdateChannel(rawValue: rawValue) else {
            return .stable
        }
        return channel
    }

    /// Convenience access to the underlying `SPUUpdater`.
    public var updater: SPUUpdater? {
        updaterController?.updater
    }

    override init() {
        channel = Self.loadChannel()
        super.init()
    }

    // MARK: - Public API

    public func configure(network: any NetworkProviding) {
        feedURLDetector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary(for: channel),
            reachabilityChecker: ProviderNetworkReachabilityChecker(network: network),
            fallbackURL: UpdateFeedURLProvider.fallback(for: channel)
        )
    }

    /// Persist and immediately apply the selected update channel.
    public func setChannel(_ channel: AppUpdateChannel) {
        guard self.channel != channel else { return }

        self.channel = channel
        UserDefaults.standard.set(channel.rawValue, forKey: AppUpdateChannel.userDefaultsKey)
        resolvedFeedURL = UpdateFeedURLProvider.primary(for: channel)
        feedPreparationTask?.cancel()
        feedPreparationTask = nil

        if let feedURLDetector {
            Task {
                await feedURLDetector.updateFeedURLs(
                    primary: UpdateFeedURLProvider.primary(for: channel),
                    fallback: UpdateFeedURLProvider.fallback(for: channel)
                )
            }
        }
    }

    /// Lazily initialize the Sparkle updater controller.
    ///
    /// The original implementation deferred initialization to avoid blocking the
    /// main thread at launch. This method is idempotent.
    public func ensureUpdaterInitialized() {
        guard AppUpdateRuntimeEnvironment.current.allowsAppUpdates else { return }
        guard updaterController == nil else { return }

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
        let task = Task { @MainActor [weak self, feedURLDetector, channel] in
            await feedURLDetector.detectIfNeeded()
            guard let self, self.channel == channel else { return }

            let url = await feedURLDetector.resolvedFeedURL
            self.resolvedFeedURL = url
            self.feedPreparationTask = nil
            if Self.verbose {
                Self.logger.info("\(Self.t)Feed URL set to: \(url.absoluteString, privacy: .public)")
            }
        }
        feedPreparationTask = task
        return task
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
