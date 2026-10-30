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

        // 文本变化**不能**走 refresh()：refresh 会重写整张状态表（附件、错误、
        // 焦点、高度、光标），而 @Published 不做等值比较，于是每个字符都要广播
        // 十几次失效，把输入框与附件预览整段拖进重建。
        //
        // 能力层的 didSet 已经通知过发送按钮（ActionBarInputObserver 也订阅了
        // 同一个通知），所以这里传 notifyActionBar: false，避免重复回调。
        textHandle = capability.addTextObserver { [weak viewModel] text in
            viewModel?.updateText(text, notifyActionBar: false)
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
