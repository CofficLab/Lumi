import Foundation

/// 历史时间范围的统一契约。
///
/// 不同指标各自定义了时间范围枚举(CPU / GPU / 内存),但语义完全一致:
/// 1 小时用高频(秒级)缓冲,更长范围用分钟级聚合缓冲。
/// 该协议把「时长」与「缓冲层选择」收敛成同一份约定,
/// 供视图模型按范围裁剪数据时使用。
public protocol DeviceHistoryRange {
    /// 范围时长(秒)。
    var duration: TimeInterval { get }

    /// 是否使用高频缓冲。
    ///
    /// `true` 表示取秒级高频缓冲(覆盖 1 小时),
    /// `false` 表示取分钟级聚合缓冲(覆盖 30 天)。
    var usesHighResolutionBuffer: Bool { get }
}
