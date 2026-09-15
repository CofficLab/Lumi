import Foundation

/// Observes cross-plugin update commands and forwards them to UpdateService.
@MainActor
final class UpdateRequestObserver {
    typealias Handler = @MainActor @Sendable () -> Void

    private var tokens: [NSObjectProtocol] = []

    init(onCheckForUpdates: @escaping Handler, onInstallPreparedUpdate: @escaping Handler) {
        tokens = [
            NotificationCenter.default.addObserver(
                forName: .checkForUpdates,
                object: nil,
                queue: .main
            ) { _ in Task { @MainActor in onCheckForUpdates() } },
            NotificationCenter.default.addObserver(
                forName: .installPreparedAppUpdate,
                object: nil,
                queue: .main
            ) { _ in Task { @MainActor in onInstallPreparedUpdate() } },
        ]
    }

    func cancel() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens.removeAll()
    }
}
