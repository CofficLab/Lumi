import Foundation

// MARK: - Legacy Data Migration Types

/// 迁移范围
///
/// 当前仅覆盖聊天核心数据 (Conversation + Message)。其余插件数据库
/// (GoalTask / AppManager / RAG / Clipboard 等) 在 v4→v5 间 schema 零变化,
/// 暂不纳入本次迁移。
public enum LumiLegacyDataKind: String, Sendable {
    case conversations
    case messages
}

/// 迁移数据快照
///
/// 描述一次「读取旧库副本」所建立的只读快照。实现类用它跟踪快照生命周期
/// (创建 / 复用 / 释放),消费插件无需关心细节。
public struct LumiLegacyDataSnapshot: Sendable {
    /// 快照对应的旧数据根目录 (副本所在)
    public let snapshotURL: URL
    /// 源旧数据根目录 (原件所在,只读,迁移后保留作降级兜底)
    public let sourceURL: URL

    public init(snapshotURL: URL, sourceURL: URL) {
        self.snapshotURL = snapshotURL
        self.sourceURL = sourceURL
    }
}
