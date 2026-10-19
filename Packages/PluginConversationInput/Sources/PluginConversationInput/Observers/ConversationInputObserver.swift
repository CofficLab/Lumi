import Combine
import Foundation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderMessageSender

/// Bridges input and attachment provider changes into the input view model.
@MainActor
final class ConversationInputObserver {
    private weak var viewModel: ConversationInputViewModel?
    private var textHandle: (any TextInputObserverHandle)?
    private var blockHandle: (any ConversationInputBlockObserverHandle)?
    private var inputObserver: (any ConversationInputProvidingObserverHandle)?
    private var senderObserver: (any MessageSenderObserverHandle)?

    init(
        capability: any ConversationInputCapability,
        viewModel: ConversationInputViewModel
    ) {
        self.viewModel = viewModel
        viewModel.refresh()

        textHandle = capability.addTextObserver { [weak viewModel] _ in
            viewModel?.refresh()
        }
        blockHandle = capability.addBlockObserver { [weak viewModel] event in
            guard case let .blockSubmitted(block) = event else { return }
            viewModel?.enqueue(block)
        }
        inputObserver = capability.addInputObserver { [weak viewModel] event in
            guard case .errorMessageChanged = event else { return }
            viewModel?.refresh()
        }
        senderObserver = capability.addMessageSenderObserver { [weak viewModel] event in
            switch event {
            case .attachmentsChanged:
                viewModel?.refresh()
            case .started, .turnCompleted, .turnFailed, .pendingMessagesChanged:
                break
            }
        }
    }

    func cancel() {
        textHandle?.cancel()
        textHandle = nil
        blockHandle?.cancel()
        blockHandle = nil
        // - Important: 这两个必须 `cancel()` 而不是直接置 nil。句柄由 Provider 持有，
        //   丢弃本地引用并不会退订，Provider 侧的观察者表仍留着回调。每次
        //   `onBoot` 都会新建一个 Observer（插件重启 / 重复装配），不真正退订
        //   会让注册表无限增长，且退订后仍能改动 ViewModel。
        inputObserver?.cancel()
        inputObserver = nil
        senderObserver?.cancel()
        senderObserver = nil
        viewModel = nil
    }
}
