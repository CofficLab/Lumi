import SwiftUI
import LumiCoreKit
import LumiUI

/// 新会话按钮视图组件
public struct NewChatButton: View {
    let context: PluginContext

    @State private var showUnavailableAlert = false
    @State private var unavailableAlertMessage = ""

    public init(context: PluginContext) {
        self.context = context
    }

    public var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: String(localized: "Start New Conversation", bundle: .module)
        ) {
            Task {
                await handleTap()
            }
        }
        .onAppear {
            context.conversationCreationContext?.syncDefaultChatMode()
        }
        .alert(
            String(localized: "Cannot Create Conversation", bundle: .module),
            isPresented: $showUnavailableAlert
        ) {
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(unavailableAlertMessage)
        }
    }

    @MainActor
    private func handleTap() async {
        guard let creationContext = context.conversationCreationContext else {
            unavailableAlertMessage = String(
                localized: "New conversation is unavailable in the current environment.",
                bundle: .module
            )
            showUnavailableAlert = true
            return
        }
        await creationContext.createConversation()
    }
}
