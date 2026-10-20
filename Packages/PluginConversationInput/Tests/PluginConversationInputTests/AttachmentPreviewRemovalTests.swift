import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationInput
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 附件预览上「✕ 关闭按钮」的完整作用链路。
///
/// `AttachmentThumbnail` / `FileAttachmentChip` 上的 ✕ 只是把 `onRemove` 闭包
/// 交给 `ConversationInputViewModel.removeImageAttachment(id:)` /
/// `removeFileAttachment(id:)`，真正让缩略图消失的是这条链：
///
/// ```
/// ✕ → ViewModel.remove…(id:) → ConversationInputCapabilityAdapter
///   → DefaultMessageSender.remove…(id:) → notify(.attachmentsChanged)
///   → ConversationInputObserver → viewModel.refresh() → 预览行重绘
/// ```
///
/// **既有测试的盲区**：`ConversationInputViewModelAttachmentTests` 用的是
/// `SendActionBarTestCapability`——直接改数组、且需要手动 `refresh()`。它证明了
/// 「给定正确 ID，移除逻辑正确」，却完全没覆盖上面这条真实链路：只要
/// Adapter 少转发一个方法、Sender 少发一次 `.attachmentsChanged`、或 Observer
/// 漏了这个事件分支，**按钮点了没反应而旧测试依然全绿**。
///
/// 因此本套件一律装配真实实现（`DefaultMessageSender` +
/// `ConversationInputCapabilityAdapter` + `ConversationInputObserver`），
/// 只把 AgentLoop 换成不跑回合的替身。
@MainActor
@Suite("附件预览关闭按钮")
struct AttachmentPreviewRemovalTests {
    // MARK: - 图片 ✕

    @Test("点图片 ✕ 后缩略图立即消失，无需手动刷新")
    func closingImageUpdatesPreviewWithoutManualRefresh() {
        let chain = AttachmentRemovalChain()
        let first = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let second = UserImageAttachment(mimeType: "image/png", base64Data: "BBBB")
        chain.sender.addImageAttachment(first)
        chain.sender.addImageAttachment(second)
        chain.refresh()

        #expect(chain.viewModel.imageAttachments.count == 2)

        // 模拟点第二个缩略图右上角的 ✕。
        chain.viewModel.removeImageAttachment(id: second.id)

        // 关键断言：**不调 refresh()**，列表就已经是移除后的结果——
        // 证明 `.attachmentsChanged` 真的从 Sender 走到了 Observer。
        #expect(chain.viewModel.imageAttachments.map(\.id) == [first.id])
        #expect(chain.sender.pendingImageAttachments.map(\.id) == [first.id])
    }

    @Test("关闭最后一张图片后预览行整体消失")
    func closingLastImageHidesPreviewRow() {
        let chain = AttachmentRemovalChain()
        let only = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        chain.sender.addImageAttachment(only)
        chain.refresh()

        #expect(chain.viewModel.hasAttachments)

        chain.viewModel.removeImageAttachment(id: only.id)

        // `AttachmentPreviewView` 的显示条件是「图片或文件任一非空」，
        // 两者都空时整行不渲染。
        #expect(!chain.viewModel.hasAttachments)
        #expect(chain.viewModel.imageAttachments.isEmpty)
    }

    @Test("关闭图片不影响文件附件")
    func closingImageKeepsFileAttachments() {
        let chain = AttachmentRemovalChain()
        let image = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let file = UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        chain.sender.addImageAttachment(image)
        chain.sender.addFileAttachment(file)
        chain.refresh()

        chain.viewModel.removeImageAttachment(id: image.id)

        #expect(chain.viewModel.imageAttachments.isEmpty)
        #expect(chain.viewModel.fileAttachments.map(\.id) == [file.id])
        // 文件还在，预览行必须继续渲染。
        #expect(chain.viewModel.hasAttachments)
    }

    @Test("连点同一个 ✕ 幂等，不会误删其他图片")
    func closingSameImageTwiceIsIdempotent() {
        let chain = AttachmentRemovalChain()
        let first = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let second = UserImageAttachment(mimeType: "image/png", base64Data: "BBBB")
        chain.sender.addImageAttachment(first)
        chain.sender.addImageAttachment(second)
        chain.refresh()

        chain.viewModel.removeImageAttachment(id: first.id)
        // 视图刷新前用户又点了一次同一个 ✕（双击 / 事件重放）。
        chain.viewModel.removeImageAttachment(id: first.id)

        #expect(chain.viewModel.imageAttachments.map(\.id) == [second.id])
        #expect(chain.sender.pendingImageAttachments.map(\.id) == [second.id])
    }

    @Test("附件池被外部清空后再点陈旧 ✕ 是安全空操作")
    func closingStaleThumbnailIsSafeNoOp() {
        let chain = AttachmentRemovalChain()
        let stale = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        chain.sender.addImageAttachment(stale)
        chain.refresh()

        // 切换会话会清空挂起池，但 SwiftUI 视图可能还持有一帧旧缩略图；
        // 用户此刻点 ✕ 走的是已被清空的 ID。
        chain.viewModel.handleConversationSwitched()
        #expect(chain.viewModel.imageAttachments.isEmpty)

        chain.viewModel.removeImageAttachment(id: stale.id)

        #expect(chain.viewModel.imageAttachments.isEmpty)
        #expect(chain.sender.pendingImageAttachments.isEmpty)
    }

    @Test("关闭图片后发送按钮状态随之回落")
    func closingLastImageDisablesSend() {
        let chain = AttachmentRemovalChain()
        let only = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        chain.sender.addImageAttachment(only)
        chain.refresh()

        // 正文为空、仅有附件 → 仍可发送（预览里只有图也能直接发）。
        #expect(chain.viewModel.canSend)

        chain.viewModel.removeImageAttachment(id: only.id)

        #expect(!chain.viewModel.canSend)
    }

    // MARK: - 文件 chip ✕

    @Test("点文件 chip 的 ✕ 后立即移除")
    func closingFileChipUpdatesPreview() {
        let chain = AttachmentRemovalChain()
        let first = UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "a")
        let second = UserFileAttachment(fileName: "b.txt", mimeType: "text/plain", textContent: "b")
        chain.sender.addFileAttachment(first)
        chain.sender.addFileAttachment(second)
        chain.refresh()

        chain.viewModel.removeFileAttachment(id: first.id)

        #expect(chain.viewModel.fileAttachments.map(\.id) == [second.id])
        #expect(chain.sender.pendingFileAttachments.map(\.id) == [second.id])
    }

    // MARK: - 退订回归

    @Test("Observer 退订后 ✕ 仍移除附件，但预览列表不再刷新")
    func removalAfterObserverCancelStopsRefreshingPreview() {
        let chain = AttachmentRemovalChain()
        let first = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let second = UserImageAttachment(mimeType: "image/png", base64Data: "BBBB")
        chain.sender.addImageAttachment(first)
        chain.sender.addImageAttachment(second)
        chain.refresh()

        chain.observer.cancel()
        chain.viewModel.removeImageAttachment(id: second.id)

        // 能力层照样删掉了——按钮的动作本身没坏。
        #expect(chain.sender.pendingImageAttachments.map(\.id) == [first.id])
        // 但没人再把变化推回 ViewModel：预览停在旧状态。
        // 这条断言锁住「句柄必须显式 cancel」的既有约定——若将来 Observer
        // 被重新装配，cancel 失效会表现为「按钮时灵时不灵」而非崩溃。
        #expect(chain.viewModel.imageAttachments.count == 2)
    }
}

// MARK: - Support

/// 关闭按钮的真实链路装配：真实 Sender + 真实 Adapter + 真实 Observer。
@MainActor
private final class AttachmentRemovalChain {
    let sender: DefaultMessageSender
    let viewModel: ConversationInputViewModel
    let observer: ConversationInputObserver

    init() {
        sender = DefaultMessageSender(
            conversations: DefaultConversationManager(),
            messages: DefaultMessageManager(),
            agentLoop: AttachmentRemovalTestAgentLoop()
        )
        let capability = ConversationInputCapabilityAdapter(
            input: DefaultConversationInputProvider(),
            sender: sender,
            conversations: nil,
            conversationState: nil,
            metrics: nil
        )
        viewModel = ConversationInputViewModel(capability: capability)
        observer = ConversationInputObserver(capability: capability, viewModel: viewModel)
    }

    /// 把当前 Sender 状态同步进 ViewModel（等价于 Observer 收到一次事件）。
    func refresh() {
        viewModel.refresh()
    }
}

/// 只提供构造所需的最小面，关闭按钮不触发任何回合。
@MainActor
private final class AttachmentRemovalTestAgentLoop: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        AttachmentRemovalTestObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome { .completed }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class AttachmentRemovalTestObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
