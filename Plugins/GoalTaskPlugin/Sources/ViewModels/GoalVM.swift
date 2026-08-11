import Foundation
import os
import SuperLogKit

/// GoalTaskPlugin 的通用视图模型。
///
/// 目前为空,作为预留入口承载后续需要在 Plugin 生命周期内共享、与 Goal 相关的
/// 视图状态。具体职责暂未定义,待使用时按需扩展。
///
/// 并发:与 `Plugin` 同处 `MainActor`,由 Plugin 持有并管理生命周期。
@MainActor
final class GoalVM: ObservableObject, SuperLog {
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = GoalTaskPlugin.logger
    public nonisolated static let emoji = "🇫🇯"

    @Published var currentConversationID: UUID?
    /// 当前对话的所有 Goal(每个携带自己的任务),按创建时间升序。
    @Published public var goals: [GoalListItem] = []
    
    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    public init() {}

    /// 更新当前对话 ID。
    ///
    /// - 当传入值与当前值一致时,跳过发布以避免触发不必要的 SwiftUI 重渲染。
    /// - 传入 `nil` 时表示清空当前对话上下文(例如对话被关闭或切换)。
    public func updateCurrentConversationID(_ id: UUID?) {
        guard currentConversationID != id else {
            if Self.verbose {
                Self.logger.info("\(Self.t)currentConversationID 未变化,跳过更新:\(id?.uuidString ?? "nil")")
            }
            return
        }
        let previous = currentConversationID
        currentConversationID = id
        if Self.verbose {
            Self.logger.info("\(Self.t)currentConversationID 更新:\(previous?.uuidString ?? "nil") -> \(id?.uuidString ?? "nil")")
        }
    }
}
