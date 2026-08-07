import Foundation

/// 粘性排序稳定器
///
/// 防止对话列表因高频消息更新而频繁跳动位置。
///
/// 原理：
/// - 每个对话维护一个"锚定排序时间"，在 holdWindow 内即使 updatedAt 变化也不会改变相对顺序。
/// - 用户主动切换到某对话时，刷新其锚点，确保"刚看过的对话"短期内不被顶走。
///
/// 该组件仅在 ConversationListPlugin 内部使用，不污染 Kernel 模型。
@MainActor
public final class ConversationSortStabilizer: ObservableObject {
    /// 每个对话的锚定排序时间：防止在窗口内被新消息顶走
    private var anchorTimes: [UUID: Date] = [:]

    /// 位置保持窗口（秒）。在此时间内，对话的排序位置不会因新消息而改变
    private let holdWindowSeconds: TimeInterval

    /// 时间提供者，用于测试时注入固定时间
    private let now: () -> Date

    public init(holdWindowSeconds: TimeInterval = 30, now: @escaping () -> Date = Date.init) {
        self.holdWindowSeconds = holdWindowSeconds
        self.now = now
    }

    /// 计算有效排序时间
    ///
    /// - Parameters:
    ///   - id: 对话 ID
    ///   - updatedAt: 数据库中的实际更新时间
    /// - Returns: 用于排序的有效时间
    public func effectiveSortTime(for id: UUID, updatedAt: Date) -> Date {
        let currentTime = now()

        // 已有锚定时间且仍在窗口内 → 保持原锚点不变
        // markViewed 也会设置 anchor，所以用户查看后位置同样被保持
        if let anchor = anchorTimes[id],
           currentTime.timeIntervalSince(anchor) < holdWindowSeconds {
            return anchor
        }

        // 超出窗口或首次出现 → 以 updatedAt 建立新锚点
        anchorTimes[id] = updatedAt
        return updatedAt
    }

    /// 用户主动切换到某对话时调用，刷新其锚点
    public func markViewed(conversationID: UUID) {
        let currentTime = now()
        anchorTimes[conversationID] = currentTime
    }

    /// 定期清理过期锚定，避免内存无限增长
    public func cleanup() {
        let cutoff = now().addingTimeInterval(-holdWindowSeconds * 2)
        anchorTimes = anchorTimes.filter { $0.value > cutoff }
    }
}
