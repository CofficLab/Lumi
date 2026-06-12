import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatMessagesView: View {
    @EnvironmentObject private var conversationVM: LumiCoreKit.WindowConversationVM
    @EnvironmentObject private var projectVM: LumiCoreKit.WindowProjectVM
    @EnvironmentObject private var themeVM: LumiCoreKit.AppThemeVM

    private let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?

    public init(messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }) {
        self.messageRenderer = messageRenderer
    }

    public var body: some View {
        Group {
            if !projectVM.isProjectSelected {
                VStack {}
                    .frame(maxHeight: .infinity)
            } else if conversationVM.hasSelectedConversation {
                MessageListView(messageRenderer: messageRenderer)
            } else {
                EmptyStateView()
            }
        }
        .frame(maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor().opacity(0.6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LumiPluginLocalization.string("Chat Messages Area", bundle: .module))
    }
}
