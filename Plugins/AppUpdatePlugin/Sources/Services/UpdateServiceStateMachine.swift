import Foundation

/// Update lifecycle state.
///
/// Ported from `LumiAppKit/Updates/UpdateServiceStateMachine.swift` (v4.19.0).
public enum UpdateLifecycleState: String, Sendable {
    /// Idle (no check started)
    case idle
    /// Checking for updates
    case checking
    /// Downloading an update
    case downloading
    /// Update ready, waiting to install
    case readyToInstall
    /// Installing the update (on quit)
    case installing
    /// Check or download failed
    case error
}

/// Update lifecycle state machine.
///
/// Manages `UpdateLifecycleState` transitions and records the pending install handler.
/// It is an `actor` for concurrency safety.
///
/// ## Responsibilities
/// - Manage update state transitions (idle → checking → downloading → readyToInstall → installing)
/// - Manage the pending install callback (Sparkle's `immediateInstallationBlock`)
/// - Track the most recently detected update version
/// - Manage the local feed URL cache (for the Sparkle delegate's synchronous queries)
public actor UpdateServiceStateMachine {

    // MARK: - Storage

    /// Current update state.
    public private(set) var state: UpdateLifecycleState = .idle

    /// Most recently detected update version (for UI display).
    public private(set) var latestVersion: String?

    /// Locally cached feed URL (for Sparkle delegate's synchronous queries).
    ///
    /// After `FeedURLDetector` finishes probing, the result is synced here
    /// for `SPUUpdaterDelegate.feedURLString(for:)` to return synchronously.
    public private(set) var cachedFeedURL: URL?

    // MARK: - Init

    /// Create a state machine instance.
    public init() {}

    // MARK: - State Transitions

    /// Mark the beginning of an update check.
    public func beginChecking() {
        state = .checking
    }

    /// Mark the beginning of an update download.
    public func beginDownloading() {
        state = .downloading
    }

    /// Mark the update as ready to install; record the version.
    /// - Parameter version: `SUAppcastItem.displayVersionString` from Sparkle.
    public func markReadyToInstall(version: String) {
        state = .readyToInstall
        latestVersion = version
    }

    /// Mark the beginning of installation (on quit).
    public func beginInstalling() {
        state = .installing
    }

    /// Mark a check or download failure.
    public func markError() {
        state = .error
    }

    /// Reset to idle state.
    public func reset() {
        state = .idle
        latestVersion = nil
    }

    // MARK: - Feed URL Management

    /// Update the local feed URL cache.
    ///
    /// Called after `FeedURLDetector` finishes probing to sync the result.
    /// - Parameter url: The detected available feed URL.
    public func updateCachedFeedURL(_ url: URL) {
        cachedFeedURL = url
    }
}
