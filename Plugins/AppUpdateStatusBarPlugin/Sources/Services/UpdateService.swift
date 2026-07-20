import Combine
import Foundation
import LumiKernel
import os

/// App update service.
///
/// Orchestrates update checking, download, and installation.
/// Integrates with the state machine, feed URL provider, and Sparkle (if available).
@MainActor
public final class UpdateService: ObservableObject {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.update")
    nonisolated static let verbose = false

    @Published public var isCheckingForUpdates = false
    @Published public var updateAvailable = false
    @Published public var updateVersion: String = ""
    @Published public var lastUpdateCheckError: String?

    private let stateMachine = UpdateServiceStateMachine()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Observe state machine changes
        stateMachine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        if Self.verbose {
            Self.logger.info("UpdateService initialized")
        }
    }

    /// Check for updates.
    public func checkForUpdates() async {
        guard stateMachine.startChecking() else {
            if Self.verbose {
                Self.logger.info("Already checking for updates")
            }
            return
        }

        isCheckingForUpdates = true
        lastUpdateCheckError = nil

        do {
            // Resolve feed URL
            guard let feedURL = await UpdateFeedURLProvider.resolveFeedURL() else {
                stateMachine.noUpdateAvailable()
                return
            }

            if Self.verbose {
                Self.logger.info("Checking for updates at \(feedURL)")
            }

            // Fetch the appcast/feed
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                stateMachine.noUpdateAvailable()
                return
            }

            // Parse the feed and check for a newer version
            let latestVersion = parseLatestVersion(from: data)
            if let latestVersion, isVersionNewer(latestVersion) {
                stateMachine.updateAvailable(version: latestVersion)
            } else {
                stateMachine.noUpdateAvailable()
            }
        } catch {
            stateMachine.encounteredError(error)
        }

        isCheckingForUpdates = false
    }

    /// Install the downloaded update.
    public func installUpdate() {
        // Post notification for the app-level handler to pick up
        NotificationCenter.default.post(name: .appUpdateReadyToInstall, object: nil)
    }

    // MARK: - Private

    private func handleStateChange(_ state: UpdateServiceStateMachine.State) {
        switch state {
        case .idle:
            isCheckingForUpdates = false
            updateAvailable = false
            updateVersion = ""
        case .checking:
            isCheckingForUpdates = true
            updateAvailable = false
            updateVersion = ""
        case .available(let version):
            isCheckingForUpdates = false
            updateAvailable = true
            updateVersion = version
            if Self.verbose {
                Self.logger.info("Update available: \(version)")
            }
        case .unavailable:
            isCheckingForUpdates = false
            updateAvailable = false
            if Self.verbose {
                Self.logger.info("No update available")
            }
        case .error(let error):
            isCheckingForUpdates = false
            lastUpdateCheckError = error.localizedDescription
            Self.logger.error("Update check failed: \(error)")
        }
    }

    /// Parse the latest version from the appcast/feed data.
    private func parseLatestVersion(from data: Data) -> String? {
        // Simple XML parsing for Sparkle appcast
        guard let xml = String(data: data, encoding: .utf8) else { return nil }

        // Look for <enclosure url="..." sparkle:version="X.Y.Z" />
        let pattern = #"sparkle:version="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: xml,
                range: NSRange(xml.startIndex..., in: xml)
              ),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }

        return String(xml[range])
    }

    /// Check if the given version is newer than the current app version.
    private func isVersionNewer(_ version: String) -> Bool {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }
        return version.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}
