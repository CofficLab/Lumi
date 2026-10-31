import Foundation
import ProviderMessage

/// 把「用户切换模型」这件事写进当前会话的时间线。
///
/// ## 为什么需要它
///
/// 模型切换是用户明确表达的意图，却没有任何可见反馈：用户点了新模型，
/// 按钮标签变了，但对话里看不出「接下来的回答换了个模型」。历史会话
/// 重新打开时更是一片空白，完全无法还原当时用的是哪个模型。
///
/// ## 触发时机
///
/// 由 `ModelSelectionCapability` 在**选择真正生效之后**调用
/// （即模型已写入会话或全局选中态），避免「点了但没选上」也留下痕迹。
///
/// ## 边界
///
/// - 没有选中会话时不插入：模型切换只改了全局默认，没有「这个会话换了模型」
///   这件事可写，强行写入会造出一条指向不明的时间线消息。
/// - 切换前后模型相同则不插入：`select` 幂等地写入同一个模型不算「切换」。
/// - 插入失败只记日志：时间线提示是辅助信息，不应让模型切换本身失败。
@MainActor
final class ModelSwitchTimelineRecorder {
    /// 记录一次模型切换所需的信息。
    struct Transition: Equatable {
        let fromProviderID: String?
        let fromModelName: String?
        let toProviderID: String?
        let toModelName: String?

        /// 切换前后是否指向同一个模型。
        ///
        /// 供应商与模型都相同才算「没变」——只比较模型名会把
        /// 「同模型不同供应商」误判成切换。
        var isSameModel: Bool {
            fromProviderID == toProviderID && fromModelName == toModelName
        }
    }

    private let messages: (any MessageManaging)?

    init(messages: (any MessageManaging)?) {
        self.messages = messages
    }

    /// 记录一次模型切换，向会话插入一条时间线消息。
    ///
    /// - Parameters:
    ///   - conversationID: 目标会话。
    ///   - transition: 切换前后的供应商与模型。
    func record(conversationID: UUID, transition: Transition) {
        guard let messages else { return }
        guard !transition.isSameModel else { return }
        guard transition.toProviderID != nil || transition.toModelName != nil else { return }

        let message = ModelSwitchTimeline.message(
            conversationID: conversationID,
            fromProviderID: transition.fromProviderID,
            fromModelName: transition.fromModelName,
            toProviderID: transition.toProviderID,
            toModelName: transition.toModelName
        )
        messages.insertMessage(message, to: conversationID)
    }
}
