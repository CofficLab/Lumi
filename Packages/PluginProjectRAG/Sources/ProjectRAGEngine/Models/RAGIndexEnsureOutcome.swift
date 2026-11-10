import Foundation

/// `RAGService.ensureIndexed` 的结果。
///
/// 调用方（尤其是 idle scheduler）必须区分「真正完成索引」「索引已新鲜」
/// 与「因近期尝试/暂停而跳过」，后两者不能当作索引成功（回归 #1116）。
public enum RAGIndexEnsureOutcome: Sendable, Equatable {
    case indexed
    case fresh
    case throttled
    case paused

    /// 只有完成索引或确认索引新鲜，才代表一次调度切片取得了进展。
    public var confirmsProgress: Bool {
        switch self {
        case .indexed, .fresh:
            return true
        case .throttled, .paused:
            return false
        }
    }
}
