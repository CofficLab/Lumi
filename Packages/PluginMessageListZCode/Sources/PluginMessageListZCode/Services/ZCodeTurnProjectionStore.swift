import Foundation
import ProviderMessage
import KitMessageList

/// V4（ZCode）轮次投影缓存。
///
/// **只把历史轮次做 O(n) 重建**：历史 `historyRows` 变化时才重新投影；
/// 流式 / 活动行更新只重做 live tail。
///
/// - Important: 这是性能红线。流式每个 token 都会调用 `snapshot`，
///   若每次都扫描整段长会话重建全部历史轮次，长列表会持续掉帧。
///   因此历史投影必须被缓存，只有历史真正变化时才失效。
@MainActor
final class ZCodeTurnProjectionStore: ObservableObject {

    // MARK: - 状态

    /// 已缓存的历史轮次。
    private var cachedHistoryTurns: [ZCodeTurn] = []
    /// 上一次构建历史投影时使用的历史版本号。
    ///
    /// - Important: 用**版本号**而不是内容哈希。内容哈希需要对每条历史消息
    ///   的完整 `content` 逐字节做 FNV-1a，代价是 O(总历史字节)，
    ///   而流式刷新每帧都要做一次 —— 长会话下每帧都在主 actor 上
    ///   重扫整段历史，内容完全没变也一样（issue #1183）。
    private var cachedHistoryRevision: UInt64?
    /// 历史 O(n) 重建次数；仅供测试断言「重建次数」这一性能不变式。
    private(set) var historyRebuildCount = 0

    // MARK: - 初始化

    init() {}

    // MARK: - 公开方法

    /// 取当前快照。
    ///
    /// - Parameters:
    ///   - history: 稳定历史展示行。
    ///   - historyRevision: 历史版本号。由 ViewModel 在 `historyRows`
    ///     真正被替换时递增；值不变即代表历史内容未变。
    ///   - streaming: 流式临时行。
    ///   - activity: 会话活动行。
    func snapshot(
        history: [Message],
        historyRevision: UInt64,
        streaming: Message?,
        activity: Message?
    ) -> ZCodeTurnProjection {
        if cachedHistoryRevision != historyRevision {
            cachedHistoryTurns = ZCodeTurnProjector.project(history)
            cachedHistoryRevision = historyRevision
            historyRebuildCount += 1
        }

        // Live tail 每次都重建（它只有 1 行，成本可忽略）。
        let liveTurns: [ZCodeTurn] = {
            if let streaming {
                return [ZCodeTurnProjector.project(history: [], streaming: streaming, activity: nil).turns[0]]
            }
            if let activity {
                return [ZCodeTurnProjector.project(history: [], streaming: nil, activity: activity).turns[0]]
            }
            return []
        }()

        let turns = cachedHistoryTurns + liveTurns

        return ZCodeTurnProjection(
            turns: turns,
            historyTurnCount: cachedHistoryTurns.count,
            historyTurnIDs: cachedHistoryTurns.map(\.id)
        )
    }

    /// 清空缓存（切换会话时调用）。
    func reset() {
        cachedHistoryTurns = []
        cachedHistoryRevision = nil
    }
}
