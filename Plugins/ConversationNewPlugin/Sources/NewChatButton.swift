import LumiKernel
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: LumiPluginLocalization.string("Start New Conversation", bundle: .module)
        ) {
            createConversation()
        }
    }

    func createConversation() {
        guard let conv = kernel.conversations else { return }
        do {
            _ = try conv.createConversation(title: nil)
        } catch {
            // Log error silently
        }
    }
}
