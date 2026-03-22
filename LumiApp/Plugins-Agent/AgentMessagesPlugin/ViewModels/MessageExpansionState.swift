import SwiftUI
import Combine

// MARK: - Message Expansion State

/// 消息展开状态管理器
/// 负责管理消息的展开/折叠状态
@MainActor
final class MessageExpansionState: ObservableObject {
    static let shared = MessageExpansionState()

    @Published private var expandedStates: [UUID: Bool] = [:]

    init() {}

    /// 获取消息的展开状态
    /// - Parameter id: 消息 ID
    /// - Returns: 展开状态
    func isExpanded(id: UUID, defaultExpanded: Bool = true) -> Bool {
        expandedStates[id] ?? defaultExpanded
    }

    /// 设置消息的展开状态
    /// - Parameters:
    ///   - id: 消息 ID
    ///   - expanded: 展开状态
    func setExpanded(id: UUID, expanded: Bool) {
        expandedStates[id] = expanded
    }

    /// 切换消息的展开状态
    /// - Parameters:
    ///   - id: 消息 ID
    ///   - defaultExpanded: 必须与 `isExpanded(id:defaultExpanded:)` 一致；默认折叠的长消息应传 `false`，否则首次点击会把 `nil` 当成 `true` 而写成 `false`，表现为要点两次才展开。
    func toggleExpansion(id: UUID, defaultExpanded: Bool = true) {
        let current = isExpanded(id: id, defaultExpanded: defaultExpanded)
        expandedStates[id] = !current
    }
}
