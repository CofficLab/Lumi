import Foundation
import KernelCore
import ProviderConversation
import ProviderMessage
import ProviderMessageSender

/// 截图流程写回挂起池所需的最小外部能力。
///
/// 收敛 `ConversationManaging` / `MessageSendingProviding` 的调用面，流程编排只通过
/// 本能力读选中会话、写图片附件，便于单元测试注入替身锁定会话绑定（#422）。
@MainActor
protocol ScreenshotFlowCapability: AnyObject {
    /// 当前选中会话；截图写回前必须比对流程启动时捕获的会话身份（#422）。
    var selectedConversationID: UUID? { get }

    /// 把图片附件加入发送器挂起池。
    func addImageAttachment(_ attachment: UserImageAttachment)
}

/// 将内核 Provider 收窄为截图流程能力。
///
/// 两个 Provider 都在**调用时**惰性解析，而非 init 时捕获：编码是异步窗口，
/// 期间发送器可能被替换，写回必须落到当前发送器（沿用 #1265 的晚解析约定）。
@MainActor
final class ScreenshotFlowCapabilityAdapter: ScreenshotFlowCapability {
    private let kernel: KernelCoreContainer

    init(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    var selectedConversationID: UUID? {
        kernel.resolveProvider((any ConversationManaging).self)?.selectedConversationID
    }

    func addImageAttachment(_ attachment: UserImageAttachment) {
        kernel.resolveProvider((any MessageSendingProviding).self)?.addImageAttachment(attachment)
    }
}