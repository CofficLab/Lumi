import Foundation
import os

/// State machine for the update service lifecycle.
///
/// States: `.idle` → `.checking` → `.available` | `.unavailable` | `.error`
@MainActor
final class UpdateServiceStateMachine {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "update.state")

    enum State {
        case idle
        case checking
        case available(version: String)
        case unavailable
        case error(SendableError)

        var isChecking: Bool {
            if case .checking = self { return true }
            return false
        }

        var hasUpdate: Bool {
            if case .available = self { return true }
            return false
        }
    }

    @Published var state: State = .idle

    /// Transitions from `.idle` to `.checking`. Returns `false` if already checking.
    func startChecking() -> Bool {
        guard case .idle = state else { return false }
        state = .checking
        return true
    }

    /// Transitions from `.checking` to `.available`.
    func updateAvailable(version: String) {
        guard state.isChecking else { return }
        state = .available(version: version)
    }

    /// Transitions from `.checking` to `.unavailable`.
    func noUpdateAvailable() {
        guard state.isChecking else { return }
        state = .unavailable
    }

    /// Transitions from `.checking` to `.error`.
    func encounteredError(_ error: Error) {
        guard state.isChecking else { return }
        state = .error(SendableError(error))
    }

    /// Resets to `.idle`.
    func reset() {
        state = .idle
    }
}

/// Wraps an `Error` as `Sendable` for state machine use.
struct SendableError: Error, @unchecked Sendable {
    let localizedDescription: String

    init(_ error: Error) {
        localizedDescription = error.localizedDescription
    }
}
