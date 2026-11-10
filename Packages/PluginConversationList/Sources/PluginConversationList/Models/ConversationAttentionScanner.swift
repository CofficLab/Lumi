import Foundation

/// 一次 attention 轮询的判定结果。
struct ConversationAttentionScanResult: Equatable {
    /// 本轮结束后仍需继续跟踪「正在运行」的会话。
    let stillRunning: Set<UUID>
    /// 本轮观测到 running → 非 running 边缘的会话。
    let finished: Set<UUID>
}

/// 回合结束检测的纯逻辑。
///
/// 候选集合必须包含「上一轮仍在运行」的 ID，而不能只取有界摘要缓存：
/// 后台会话可能已被缓存裁剪，它的回合却仍在运行。只按缓存求交集会把这类
/// ID 从跟踪表里抹掉，等到回合真正结束时就凑不出 running → 非 running
/// 边缘，未读提示随之丢失（#993）。
enum ConversationAttentionScanner {
    static func scan(
        cachedIDs: Set<UUID>,
        previouslyRunning: Set<UUID>,
        isRunning: (UUID) -> Bool
    ) -> ConversationAttentionScanResult {
        let candidates = cachedIDs.union(previouslyRunning)
        var stillRunning: Set<UUID> = []
        var finished: Set<UUID> = []

        for id in candidates {
            if isRunning(id) {
                stillRunning.insert(id)
            } else if previouslyRunning.contains(id) {
                finished.insert(id)
            }
        }

        return ConversationAttentionScanResult(
            stillRunning: stillRunning,
            finished: finished
        )
    }
}
