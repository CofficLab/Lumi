import Combine
import Foundation
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// 观察当前会话详细程度变化，匹配时注册 ChatSectionItem，不匹配时移除。
///
/// 每个 MessageList 子插件（Brief/Standard/Detailed）各持一个实例，
/// 仅在自己的 expectedVerbosity 下展示 ChatSectionItem。
@MainActor
final class VerbosityObservationBox {
    private let conversations: (any ConversationManaging)?
    private let chat: any ChatSectionProviding
    private let pluginID: String
    private let expectedVerbosity: ResponseVerbosity
    private let makeView: @MainActor @Sendable () -> AnyView
    private var conversationHandle: (any ConversationObserverHandle)?
    /// 当前是否在 chat 中注册了 item
    private var isRegistered = false

    init(
        conversations: (any ConversationManaging)?,
        chat: any ChatSectionProviding,
        pluginID: String,
        expectedVerbosity: ResponseVerbosity,
        makeView: @escaping @MainActor @Sendable () -> AnyView
    ) {
        self.conversations = conversations
        self.chat = chat
        self.pluginID = pluginID
        self.expectedVerbosity = expectedVerbosity
        self.makeView = makeView

        // 初始注册
        reevaluate()

        // 监听 verbosity 变化和会话选择变化
        conversationHandle = conversations?.addConversationObserver { [weak self] event in
            switch event {
            case .verbosityChanged, .selected:
                self?.reevaluate()
            default:
                break
            }
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        if isRegistered {
            chat.removeItem(id: pluginID)
            isRegistered = false
        }
    }

    private func reevaluate() {
        let selectedID = conversations?.selectedConversationID
        let verbosity = conversations?.verbosity(for: selectedID) ?? .standard
        // 始终注册当前详细程度对应的内容项。会话选择可能在启动后异步恢复；
        // 如果此时因为 selectedID == nil 不注册，Chat 区会暂时没有消息列表，
        // 且后续若选择值没有发生变化也无法触发补注册。具体视图负责展示
        // NoConversationSelectedView。
        let shouldShow = verbosity == expectedVerbosity

        if shouldShow, !isRegistered {
            chat.addItems([
                ChatSectionItem(
                    id: pluginID,
                    order: 82,
                    scope: .global,
                    fillsRemainingHeight: true,
                    content: makeView
                )
            ])
            isRegistered = true
        } else if !shouldShow, isRegistered {
            chat.removeItem(id: pluginID)
            isRegistered = false
        }
    }
}
