import SwiftUI
import Combine
import OSLog
import MagicKit

// MARK: - Message Expansion State

/// 消息展开状态管理器
/// 负责管理消息的展开/折叠状态
@MainActor
final class MessageExpansionState: ObservableObject, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📝"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    static let shared = MessageExpansionState()

    @Published private var expandedStates: [UUID: Bool] = [:]

    init() {}

    /// 获取消息的展开状态
    /// - Parameter id: 消息 ID
    /// - Returns: 展开状态
    func isExpanded(id: UUID) -> Bool {
        expandedStates[id] ?? true  // 默认展开
    }

    /// 设置消息的展开状态
    /// - Parameters:
    ///   - id: 消息 ID
    ///   - expanded: 展开状态
    func setExpanded(id: UUID, expanded: Bool) {
        expandedStates[id] = expanded
    }

    /// 切换消息的展开状态
    /// - Parameter id: 消息 ID
    func toggleExpansion(id: UUID) {
        let current = isExpanded(id: id)
        expandedStates[id] = !current
    }
}
