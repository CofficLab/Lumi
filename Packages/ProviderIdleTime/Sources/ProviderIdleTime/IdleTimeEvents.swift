import Foundation

/// Idle Time 相关的系统通知。
///
/// 由旧版 `KernelLumi/Events/IdleTimeEvents.swift` 迁移而来；
/// 迁移后的 `IdleTimeService` 在快照刷新后发布，UI（状态栏、设置卡片等）订阅刷新。
public extension Notification.Name {
    static let idleTimeSnapshotDidChange = Notification.Name("idleTime.snapshotDidChange")
}
