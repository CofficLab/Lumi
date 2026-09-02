import Foundation

/// Observes cross-plugin update commands and forwards them to UpdateService.
@MainActor
final class UpdateRequestObserver {
    private var tokens: [NSObjectProtocol] = []

    init(onCheckForUpdates: @escaping () -> Void, onInstallPreparedUpdate: @escaping () -> Void) {
        tokens = [
            NotificationCenter.default.addObserver(
                forName: .checkForUpdates,
                object: nil,
                queue: .main
            ) { _ in onCheckForUpdates() },
            NotificationCenter.default.addObserver(
                forName: .installPreparedAppUpdate,
                object: nil,
                queue: .main
            ) { _ in onInstallPreparedUpdate() },
        ]
    }

    func cancel() {
        tokens.forEach(NotificationCenter.default.removeObserver)
        tokens.removeAll()
    }
}
