import Foundation
import ProviderConversationInput
import ProviderProject
import ProviderToast

/// 文件树视图所需的项目/内核能力上下文。
///
/// 旧版 `TreeView` / `FileTreeNSViewBridge` / `FileTreeCollectionViewController`
/// 直接持有 `KernelLumi`，为适配新架构（KernelCore + Provider 注入），这里把
/// 视图真正需要的几项能力收敛为轻量上下文对象，避免视图层耦合整个内核。
@MainActor
public final class FileTreeContext {
    /// 项目能力（当前项目路径、更新当前文件等）。
    public let project: (any ProjectProviding)?
    /// 对话输入能力（「发送到对话」）。
    public let conversationInput: (any ConversationInputProviding)?
    /// Toast 提示能力（替代旧版 MagicAlert）。
    public let toast: (any ToastProviding)?

    public init(
        project: (any ProjectProviding)?,
        conversationInput: (any ConversationInputProviding)?,
        toast: (any ToastProviding)?
    ) {
        self.project = project
        self.conversationInput = conversationInput
        self.toast = toast
    }
}
