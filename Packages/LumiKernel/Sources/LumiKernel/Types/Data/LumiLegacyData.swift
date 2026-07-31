import Foundation

// MARK: - Legacy Data Migration Types

/// 旧版本(v4)数据迁移相关的错误
///
/// 由 `LegacyDataProviding` 的实现抛出,在消费插件(如 ConversationStorePlugin)的
/// 迁移逻辑中应被 `do/catch` 捕获并记录日志,**绝不向上抛** —— 因为 `onReady` 是
/// 串行调度,抛错会阻塞后续所有插件的初始化。
public enum LegacyDataError: Error, LocalizedError {
    /// 未找到旧版本数据根目录(全新安装,或已被标记为已消费)
    case legacyDataNotFound
    /// 复制旧库副本失败(磁盘满 / 权限 / 路径异常)
    case snapshotCopyFailed(underlying: Error)
    /// 打开旧库失败(schema 不匹配 / 文件损坏 / SwiftData 错误)
    case openFailed(underlying: Error)
    /// 读取旧数据失败(查询 / 解码错误)
    case fetchFailed(entity: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .legacyDataNotFound:
            return "Legacy data directory not found (fresh install or already consumed)"
        case .snapshotCopyFailed(let underlying):
            return "Failed to snapshot legacy database: \(underlying.localizedDescription)"
        case .openFailed(let underlying):
            return "Failed to open legacy database: \(underlying.localizedDescription)"
        case .fetchFailed(let entity, let underlying):
            return "Failed to fetch legacy '\(entity)': \(underlying.localizedDescription)"
        }
    }
}

/// 迁移范围
///
/// 当前仅覆盖聊天核心数据(Conversation + Message)。其余插件数据库
/// (GoalTask / AppManager / RAG / Clipboard 等)在 v4→v5 间 schema 零变化,
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
    /// 快照对应的旧数据根目录(副本所在)
    public let snapshotURL: URL
    /// 源旧数据根目录(原件所在,只读,迁移后保留作降级兜底)
    public let sourceURL: URL

    public init(snapshotURL: URL, sourceURL: URL) {
        self.snapshotURL = snapshotURL
        self.sourceURL = sourceURL
    }
}
