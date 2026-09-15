import Foundation
import ProviderConversation

/// 会话外部事件 → VerbosityViewModel 的桥梁。
///
/// 在插件组装层创建，初始化时写入初值并订阅对话事件；收到事件后
/// **直接修改** ViewModel，不向外传回调、不注册多观察者分发。
@MainActor
final class VerbosityObserver {
    private let viewModel: VerbosityViewModel
    private var conversationObserver: (any ConversationObserverHandle)?

    init(
        capability: any ConversationVerbosityCapability,
        viewModel: VerbosityViewModel
    ) {
        self.viewModel = viewModel
        viewModel.refresh()
        conversationObserver = capability.addConversationObserver { [weak self] event in
            guard let self else { return }
            // Refresh UI on verbosity changes, selection changes, or structural changes.
            switch event {
            case .verbosityChanged, .selected, .created, .deleted, .listChanged:
                self.viewModel.refresh()
            default:
                break
            }
        }
    }

    func cancel() {
        conversationObserver?.cancel()
        conversationObserver = nil
    }
}
