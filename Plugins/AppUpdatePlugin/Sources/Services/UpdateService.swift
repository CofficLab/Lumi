import AppKit
import LumiKernel
import Sparkle
import SuperLogKit
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
public final class UpdateService: NSObject, SPUUpdaterDelegate, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.updater")
    nonisolated public static let emoji = "⬆️"
    nonisolated public static let verbose = false

    public static let shared = UpdateService()

    /// Lazy-initialized Sparkle controller.
    /// Created on first use to avoid blocking app startup.
    public private(set) var updaterController: SPUStandardUpdaterController?

    /// Feed URL detector (actor). Network probes run off the main actor.
    private var feedURLDetector: FeedURLDetector?

    /// Update lifecycle state machine (tracks state + version only).
    private let stateMachine = UpdateServiceStateMachine()

    /// Currently effective feed URL.
    ///
    /// Initial value is the primary feed; updated to the reachable URL after
    /// `setupFeedURLIfNeeded()` completes. Kept as a plain stored property so
    /// `feedURLString(for:)` (synchronous delegate callback) can read it directly.
    private var resolvedFeedURL: URL = UpdateFeedURLProvider.primary

    /// Pending install callback provided by Sparkle via
    /// `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)`.
    /// Stored on the MainActor-isolated service because the closure itself
    /// is non-Sendable (it may touch AppKit).
    private var pendingImmediateInstallHandler: (() -> Void)?

    /// Convenience access to the underlying `SPUUpdater`.
    public var updater: SPUUpdater? {
        updaterController?.updater
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdatesRequest),
            name: .checkForUpdates,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInstallPreparedAppUpdateRequest),
            name: .installPreparedAppUpdate,
            object: nil
        )
    }

    // MARK: - Public API

    public func configure(network: any NetworkProviding) {
        feedURLDetector = FeedURLDetector(
            initialURL: UpdateFeedURLProvider.primary,
            reachabilityChecker: KernelNetworkReachabilityChecker(network: network)
        )
    }

    /// Lazily initialize the Sparkle updater controller.
    ///
    /// The original implementation deferred initialization to avoid blocking the
    /// main thread at launch. This method is idempotent.
    public func ensureUpdaterInitialized() {
        guard LumiRuntimeEnvironment.current.allowsAppUpdates else { return }
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
    /// Called once from `MacAgent.applicationDidFinishLaunching`. The network
    /// probe runs on a detached background task; only the Sparkle controller
    /// initialization hops back to the main actor.
    public func setupFeedURLIfNeeded() {
        guard LumiRuntimeEnvironment.current.allowsAppUpdates else { return }
        guard let feedURLDetector else { return }
        Task.detached(priority: .utility) { [feedURLDetector] in
            await feedURLDetector.detectIfNeeded()
            let url = await feedURLDetector.resolvedFeedURL

            await MainActor.run {
                self.resolvedFeedURL = url
                self.ensureUpdaterInitialized()
                if Self.verbose {
                    Self.logger.info("\(Self.t)Feed URL set to: \(url.absoluteString, privacy: .public)")
                }
            }
        }
    }

    /// Trigger an immediate update check.
    public func checkForUpdates() {
        guard LumiRuntimeEnvironment.current.allowsAppUpdates else { return }
        ensureUpdaterInitialized()
        updaterController?.checkForUpdates(nil)
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
        pendingImmediateInstallHandler = immediateInstallHandler
        Task {
            await stateMachine.markReadyToInstall(version: item.displayVersionString)
        }
        NotificationCenter.postAppUpdateReadyToInstall(version: item.displayVersionString)
        return true
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

    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    @objc private func handleInstallPreparedAppUpdateRequest() {
        guard let handler = pendingImmediateInstallHandler else { return }
        pendingImmediateInstallHandler = nil
        Task {
            await stateMachine.beginInstalling()
        }
        handler()
    }
}
