import Combine
import KernelCore
import LumiUI
import ProviderConversation
import ProviderWorkspace
import SwiftUI

/// 新会话按钮视图组件（样式与行为对齐旧版 ConversationNewPlugin 的 NewChatButton）。
public struct NewChatButton: View {
    let kernel: KernelCoreContainer
    @StateObject private var selectionObserver: ConversationSelectionObserver

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
        _selectionObserver = StateObject(
            wrappedValue: ConversationSelectionObserver(kernel: kernel)
        )
    }

    public var body: some View {
        Group {
            if selectionObserver.isChatSectionVisible && selectionObserver.hasSelectedConversation {
                AppIconButton(
                    systemImage: "plus"
                ) {
                    kernel.resolveProvider((any ConversationManaging).self)?.deselectConversation()
                }
            }
        }
    }
}

/// 桥接对话服务与工作区的发布状态到 SwiftUI。
///
/// 新版 `WorkspaceProviding` / `ConversationManaging` 均为 `ObservableObject`
/// 存在类型，直接订阅两者的 `objectWillChange`，等价于旧版对选中状态的通知
/// 监听 + `onChatSectionVisibleDidChange` 的组合，且对挂载时序更健壮。
@MainActor
private final class ConversationSelectionObserver: ObservableObject {
    let conversations: (any ConversationManaging)?
    let workspace: (any WorkspaceProviding)?
    private var cancellables: Set<AnyCancellable> = []

    init(kernel: KernelCoreContainer) {
        conversations = kernel.resolveProvider((any ConversationManaging).self)
        workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        conversations?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        workspace?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    var hasSelectedConversation: Bool {
        conversations?.selectedConversationID != nil
    }

    var isChatSectionVisible: Bool {
        workspace?.isChatVisible ?? true
    }
}
