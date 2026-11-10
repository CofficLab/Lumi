import Foundation
import ProviderMessage

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
    /// 上一次构建历史投影时使用的输入指纹。
    private var cachedHistorySignature: HistorySignature?
    /// 历史 O(n) 重建次数；仅供测试断言「重建次数」这一性能不变式。
    private(set) var historyRebuildCount = 0

    // MARK: - 初始化

    init() {}

    // MARK: - 公开方法

    /// 取当前快照。
    ///
    /// - Parameters:
    ///   - history: 稳定历史展示行。
    ///   - streaming: 流式临时行。
    ///   - activity: 会话活动行。
    func snapshot(
        history: [Message],
        streaming: Message?,
        activity: Message?
    ) -> ZCodeTurnProjection {
        let signature = HistorySignature(history: history)

        if signature != cachedHistorySignature {
            cachedHistoryTurns = ZCodeTurnProjector.project(history)
            cachedHistorySignature = signature
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
        cachedHistorySignature = nil
    }

    // MARK: - 私有

    /// 历史输入的指纹。
    ///
    /// 只比较「决定轮次划分」的字段：行 id、role、turnID 与是否 tool-only。
    /// 这些字段变化才可能改变轮次边界或轮尾正文；
    /// 纯正文内容变化不影响轮次划分（正文只在构建时读取一次）。
    ///
    /// - Note: 但正文变化会影响 `assistantCopyText` 与 `completedAt`，
    ///   因此指纹必须包含内容哈希，否则整轮复制会拿到过期文本。
    private struct HistorySignature: Equatable {
        let fingerprints: [RowFingerprint]

        init(history: [Message]) {
            fingerprints = history.map { RowFingerprint(message: $0) }
        }
    }

    private struct RowFingerprint: Equatable {
        let id: UUID
        let role: MessageRole
        let turnID: UUID?
        let isToolExecutionOnly: Bool
        let contentHash: Int

        init(message: Message) {
            id = message.id
            role = message.role
            turnID = message.turnID
            isToolExecutionOnly = message.isToolExecutionOnly
            contentHash = Self.hash(message.content)
        }

        /// FNV-1a 32 位哈希：等长替换也必须被识别为「内容已变」。
        private static func hash(_ string: String) -> Int {
            var hash: UInt32 = 2_166_136_261
            for byte in string.utf8 {
                hash ^= UInt32(byte)
                hash = hash &* 16_777_619
            }
            return Int(hash)
        }
    }
}
