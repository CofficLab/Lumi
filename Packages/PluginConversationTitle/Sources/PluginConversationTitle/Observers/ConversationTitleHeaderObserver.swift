import Foundation
import ProviderConversation

/// Observes the conversation events that can change the visible header title.
///
/// 在插件组装层创建，初始化时传入 ViewModel；收到事件后**直接修改**
/// `ConversationTitleViewModel.title`，不向外传回调。
@MainActor
final class ConversationTitleHeaderObserver {
    private let viewModel: ConversationTitleViewModel
    private var handle: (any ConversationObserverHandle)?

    init(
        conversations: any ConversationManaging,
        viewModel: ConversationTitleViewModel
    ) {
        self.viewModel = viewModel
        viewModel.update(title: conversations.currentTitle)
        handle = conversations.addConversationObserver { [weak self] event in
            guard let self else { return }
            switch event {
            case .created, .listChanged, .selected, .deleted, .updated,
                 .markedActive, .providerChanged, .verbosityChanged,
                 .reasoningChanged, .automationChanged, .languageChanged:
                self.viewModel.update(title: conversations.currentTitle)
            }
        }
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}
