import LumiKernel
import LumiUI
import SwiftUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let kernel: LumiKernel

    /// ChatSection 是否可见；不可见时整个按钮不渲染。
    @State private var isChatSectionVisible: Bool = true

    /// 创建失败时的错误信息；非空时弹出 alert。
    @State private var errorMessage: String?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        Group {
            if isChatSectionVisible {
                AppIconButton(
                    systemImage: "plus",
                ) {
                    createConversation()
                }
            }
        }
        .onAppear {
            isChatSectionVisible = kernel.layoutManager?.isChatVisible ?? true
        }
        .onChatSectionVisibleDidChange { visible in
            isChatSectionVisible = visible
        }
        .alert(
            LumiPluginLocalization.string("Cannot Create Conversation", bundle: .module),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    func createConversation() {
        guard let conv = kernel.conversations else { return }
        do {
            _ = try conv.createConversation(title: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
