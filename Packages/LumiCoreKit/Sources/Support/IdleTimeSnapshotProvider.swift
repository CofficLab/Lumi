import Foundation

public typealias IdleTimeSnapshotProviderClosure = @Sendable (Date) async -> IdleInferenceSnapshot?

extension Notification.Name {
    public static let idleTimeSnapshotDidChange = Notification.Name("IdleTimeSnapshotDidChange")
}

public actor IdleTimeSnapshotProvider {
    public static let shared = IdleTimeSnapshotProvider()

    private var provider: IdleTimeSnapshotProviderClosure?

    public init() {}

    public func register(_ provider: @escaping IdleTimeSnapshotProviderClosure) {
        self.provider = provider
    }

    public func currentSnapshot(for date: Date = Date()) async -> IdleInferenceSnapshot {
        if let snapshot = await provider?(date) {
            return snapshot
        }
        return .empty(generatedAt: date)
    }
}
