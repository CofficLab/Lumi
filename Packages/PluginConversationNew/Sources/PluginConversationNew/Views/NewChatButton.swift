import KernelCore
import LumiUI
import ProviderConversation
import SwiftUI

/// 新会话按钮视图组件。
///
/// 是否挂载由 ``ConversationNewPlugin`` 根据外部状态管理；视图本身只负责
/// 执行取消当前会话选择的动作。
public struct NewChatButton: View {
    let kernel: KernelCoreContainer

    public init(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    public var body: some View {
        AppIconButton(systemImage: "plus") {
            kernel.resolveProvider((any ConversationManaging).self)?.deselectConversation()
        }
    }
}
