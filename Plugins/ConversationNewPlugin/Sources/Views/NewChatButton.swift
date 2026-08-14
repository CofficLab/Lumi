import Combine
import KernelLumi
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let kernel: KernelLumi
    @StateObject private var selectionObserver: ConversationSelectionObserver

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true

    public init(kernel: KernelLumi) {
        self.kernel = kernel
        _selectionObserver = StateObject(
            wrappedValue: ConversationSelectionObserver(conversations: kernel.conversations)
        )
    }

    public var body: some View {
        Group {
            if isChatSectionVisible && selectionObserver.hasSelectedConversation {
                AppIconButton(
                    systemImage: "plus",
                ) {
                    kernel.conversations?.deselectConversation()
                }
            }
        }
        .onAppear {
            isChatSectionVisible = kernel.workspace?.isChatVisible ?? true
        }
        .onChatSectionVisibleDidChange { visible in
            isChatSectionVisible = visible
        }
    }
}

/// Bridges the conversation service's published state to SwiftUI.
///
/// `NewChatButton` can be mounted after conversation restoration has already
/// posted its selection event, so listening only to the notification can leave
/// the button with a stale initial value. Observing the service itself makes
/// the view resilient to that ordering.
@MainActor
private final class ConversationSelectionObserver: ObservableObject {
    let conversations: (any ConversationManaging)?
    private var cancellable: AnyCancellable?

    init(conversations: (any ConversationManaging)?) {
        self.conversations = conversations
        cancellable = conversations?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var hasSelectedConversation: Bool {
        conversations?.selectedConversationID != nil
    }
}
