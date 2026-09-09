import Combine
import Foundation
import ProviderChatSection
import ProviderConversation
import SwiftUI

/// 观察当前会话详细程度变化，并刷新消息列表 slot 的可见性。
///
/// 每个 MessageList 子插件（Brief/Standard/Detailed）各持一个实例，
/// 常驻注册自己的 ChatSectionItem，仅在自己的 expectedVerbosity 下参与渲染。
@MainActor
final class VerbosityObservationBox {
    private let conversations: (any ConversationManaging)?
    private let chat: any ChatSectionProviding
    private let pluginID: String
    private let expectedVerbosity: ResponseVerbosity
    private let makeView: @MainActor @Sendable () -> AnyView
    private var conversationHandle: (any ConversationObserverHandle)?
    /// 当前是否在 chat 中注册了 item。注册状态与可见状态刻意分离，
    /// 避免详细程度切换时修改 ChatSection 的布局贡献集合。
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

        register()

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
        chat.refreshItems()
    }

    private func register() {
        guard !isRegistered else { return }
        let conversations = conversations
        let expectedVerbosity = expectedVerbosity
        chat.addItems([
            ChatSectionItem(
                id: pluginID,
                order: 82,
                scope: .global,
                exclusiveGroup: "message-list",
                fillsRemainingHeight: true,
                isActive: { @MainActor in
                    guard let selectedID = conversations?.selectedConversationID else { return false }
                    return conversations?.verbosity(for: selectedID) == expectedVerbosity
                },
                content: makeView
            )
        ])
        isRegistered = true
    }
}
