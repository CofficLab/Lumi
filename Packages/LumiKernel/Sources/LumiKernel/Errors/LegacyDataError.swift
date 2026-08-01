import Foundation

/// 旧版本 (v4) 数据迁移相关的错误。
///
/// 由 ``LegacyDataProviding`` 的实现抛出,在消费插件 (如
/// `ConversationStorePlugin`) 的迁移逻辑中应被 `do/catch` 捕获并记录日志,
/// **绝不向上抛** —— 因为 `onReady` 是串行调度,抛错会阻塞后续所有插件的
/// 初始化。
public enum LegacyDataError: Error, LocalizedError {
    /// 未找到旧版本数据根目录 (全新安装,或已被标记为已消费)
    case legacyDataNotFound
    /// 复制旧库副本失败 (磁盘满 / 权限 / 路径异常)
    case snapshotCopyFailed(underlying: Error)
    /// 打开旧库失败 (schema 不匹配 / 文件损坏 / SwiftData 错误)
    case openFailed(underlying: Error)
    /// 读取旧数据失败 (查询 / 解码错误)
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
