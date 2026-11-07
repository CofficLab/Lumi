import AppKit
import Foundation
import ProviderIdleTime

/// Translates application activity notifications into idle-time provider events.
@MainActor
final class IdleTimeEventObserver {
    private var tokens: [NSObjectProtocol] = []

    init(provider: any IdleTimeProviding) {
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { await provider.record(.appBecameActive) }
            },
            center.addObserver(
                forName: .lumiEditorSave,
                object: nil,
                queue: .main
            ) { _ in
                Task { await provider.record(.fileSave) }
            },
        ]
    }

    func cancel() {
        let center = NotificationCenter.default
        tokens.forEach(center.removeObserver)
        tokens.removeAll()
    }
}
