import LumiUI
import os
import SwiftUI

/// 在用户首条消息发送时，根据内容自动生成会话标题（发送管线中间件），
/// 并在工具栏右侧显示当前对话的标题。
actor AutoConversationTitlePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let verbose: Bool = true
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-conversation-title")

    static let id = "AutoConversationTitlePlugin"
    static let displayName: String = String(localized: "Auto Conversation Title", table: "AutoConversationTitlePlugin")
    static let description: String = String(localized: "After the first user message is sent, generate a short title by calling the model according to the default title rule.", table: "AutoConversationTitlePlugin")
    static let iconName: String = "textformat.size"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .agent }
    static let enable: Bool = true
    static var order: Int { 8 }

    static let shared = AutoConversationTitlePlugin()

    private init() {}

    // MARK: - Middlewares

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(AutoConversationTitleSuperSendMiddleware())]
    }

    // MARK: - Toolbar

    @MainActor
    func addToolBarTrailingView(activeIcon: String?) -> AnyView? {
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(ConversationTitleToolbarView())
    }
}

/// 对话标题工具栏视图
private struct ConversationTitleToolbarView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @State private var currentTitle: String = ""

    // 标题最大显示长度
    private let maxTitleLength = 30

    var body: some View {
        if currentTitle.isEmpty {
            EmptyView()
        } else {
            Text(currentTitle)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 200, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .onChange(of: conversationVM.selectedConversationId) { _, newId in
            updateTitle(for: newId)
        }
        .onAppear {
            updateTitle(for: conversationVM.selectedConversationId)
        }
    }

    private func updateTitle(for conversationId: UUID?) {
        guard let conversationId = conversationId else {
            currentTitle = ""
            return
        }

        if let conversation = conversationVM.fetchConversation(id: conversationId) {
            let title = conversation.title
            if title.count > maxTitleLength {
                let index = title.index(title.startIndex, offsetBy: maxTitleLength)
                currentTitle = String(title[..<index]) + "..."
            } else {
                currentTitle = title
            }
        } else {
            currentTitle = ""
        }
    }
}
