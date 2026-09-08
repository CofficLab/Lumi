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
        // 空态由独立的 PluginMessageListEmptyPlugin 接管；列表插件只在有选中
        // 会话时注册自己的消息列表内容项。
        let shouldShow = verbosity == expectedVerbosity && selectedID != nil

        if shouldShow, !isRegistered {
            chat.addItems([
                ChatSectionItem(
                    id: pluginID,
                    order: 82,
                    scope: .global,
                    exclusiveGroup: "message-list",
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
