import Foundation

/// Activity tracking and inferred rest-window capability.
///
/// The implementation is supplied by `IdleTimePlugin`; consumers should resolve
/// this provider from the kernel instead of depending on that plugin directly.
public protocol IdleTimeProviding: AnyObject, Sendable {
    func record(_ kind: IdleActivityKind, at date: Date) async
    func currentSnapshot(for date: Date) async -> IdleInferenceSnapshot
    func idlePrediction(for duration: TimeInterval, at date: Date) async -> IdlePrediction
}

public extension IdleTimeProviding {
    static var defaultIdlePredictionDuration: TimeInterval { 10 * 60 }

    func record(_ kind: IdleActivityKind) async {
        await record(kind, at: Date())
    }

    func currentSnapshot() async -> IdleInferenceSnapshot {
        await currentSnapshot(for: Date())
    }

    func idlePrediction(
        for duration: TimeInterval = Self.defaultIdlePredictionDuration
    ) async -> IdlePrediction {
        await idlePrediction(for: duration, at: Date())
    }
}
