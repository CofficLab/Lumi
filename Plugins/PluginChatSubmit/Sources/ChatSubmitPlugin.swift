import LumiCoreKit
import LumiUI
import SwiftUI
import SuperLogKit
import os

public actor ChatSubmitPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-submit")
    public nonisolated static let emoji = "🚀"
    public nonisolated static let verbose: Bool = true

    public static let id = "ChatSubmit"
    public static let displayName = String(localized: "Chat Submit", table: "AgentChat")
    public static let description = String(localized: "Send or stop chat messages", table: "AgentChat")
    public static let iconName = "paperplane"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 86 }
    public static let shared = ChatSubmitPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    @MainActor
    public func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.supportsAIChat else { return [] }
        return [
            SidebarToolbarItem(
                id: "chat-submit",
                title: String(localized: "Send Message", table: "AgentChat"),
                systemImage: "paperplane.fill",
                priority: 50
            )
        ]
    }

    @MainActor
    public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "chat-submit" else { return nil }
        return AnyView(ChatSubmitToolbarButton())
    }
}

private struct ChatSubmitToolbarButton: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        sidebarToolbarButton(
            id: "chat-submit",
            tooltip: String(localized: "Send Message", table: "AgentChat")
        ) {
            submit()
        } content: {
            Image(systemName: "paperplane.fill")
                .font(.appCaptionEmphasized)
                .foregroundColor(canSubmit ? theme.primary : theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(theme.textPrimary.opacity(0.06))
                .clipShape(Circle())
        }
        .disabled(!canSubmit)
        .accessibilityLabel(String(localized: "Send Message", table: "AgentChat"))
    }

    private var canSubmit: Bool {
        conversationVM.canSubmitText && !conversationVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let draftText = conversationVM.draftText
        Task {
            await conversationVM.submitDraftText(draftText)
        }
    }
}
