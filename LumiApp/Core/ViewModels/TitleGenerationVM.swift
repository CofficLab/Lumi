import Foundation
import OSLog
import MagicKit

/// 标题生成 ViewModel
/// 专门管理会话标题生成状态，避免与消息管理逻辑耦合
@MainActor
final class TitleGenerationVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🏷️"
    nonisolated static let verbose = true

    /// 标记每个会话是否已生成标题
    /// Key: 会话 ID, Value: 是否已生成标题
    @Published private var titleGeneratedStatus: [UUID: Bool] = [:]

    /// 检查指定会话是否已生成标题
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 是否已生成标题
    func hasGeneratedTitle(for conversationId: UUID) -> Bool {
        titleGeneratedStatus[conversationId] ?? false
    }

    /// 设置会话的标题生成状态
    /// - Parameters:
    ///   - generated: 是否已生成
    ///   - conversationId: 会话 ID
    func setTitleGenerated(_ generated: Bool, for conversationId: UUID) {
        let oldValue = titleGeneratedStatus[conversationId] ?? false
        titleGeneratedStatus[conversationId] = generated

        if Self.verbose && oldValue != generated {
            os_log("\(Self.t)🏷️ 会话 [\(conversationId)] 标题生成状态: \(oldValue) → \(generated)")
        }
    }

    /// 根据消息列表自动判断并设置标题生成状态
    /// 如果会话中已存在用户消息，则标记为已生成标题
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - conversationId: 会话 ID
    func updateTitleGenerationStatus(from messages: [ChatMessage], for conversationId: UUID) {
        let hasUserMessage = messages.contains { $0.role == .user }
        setTitleGenerated(hasUserMessage, for: conversationId)
    }

    /// 清除指定会话的标题生成状态
    /// - Parameter conversationId: 会话 ID
    func clearTitleGenerationStatus(for conversationId: UUID) {
        let oldValue = titleGeneratedStatus.removeValue(forKey: conversationId)

        if Self.verbose && oldValue != nil {
            os_log("\(Self.t)🗑️ 清除会话 [\(conversationId)] 的标题生成状态")
        }
    }

    /// 重置所有标题生成状态
    func resetAll() {
        let count = titleGeneratedStatus.count
        titleGeneratedStatus.removeAll()

        if Self.verbose && count > 0 {
            os_log("\(Self.t)🗑️ 重置所有标题生成状态，共清除 \(count) 个会话")
        }
    }
}
