import Foundation
import LumiUI
import os
import SwiftUI

/// 对话标题工具栏插件
///
/// 在工具栏右侧显示当前对话的标题，并控制其长度。
actor ConversationTitleToolbarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-title-toolbar")
    nonisolated static let emoji = "💬"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "ConversationTitleToolbar"
    static let displayName: String = "Conversation Title Toolbar"
    static let description: String = "Display the current conversation title in the toolbar"
    static let iconName: String = "textformat.size"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .agent }
    static var order: Int { 77 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ConversationTitleToolbarPlugin()
    nonisolated func onRegister() {
        Self.logger.info("\(Self.emoji) ConversationTitleToolbarPlugin registered")
    }

    // MARK: - Toolbar

    @MainActor
    func addToolBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(ConversationTitleToolbarView())
    }
}

/// 对话标题工具栏视图
private struct ConversationTitleToolbarView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @State private var currentTitle: String = ""
    
    // 标题最大显示长度
    private let maxTitleLength = 30
    
    var body: some View {
        Text(currentTitle)
            .font(.caption)
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 200, alignment: .trailing) // 限制最大宽度
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
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
        
        // 通过 conversationVM 获取对话
        if let conversation = conversationVM.fetchConversation(id: conversationId) {
            let title = conversation.title
            // 控制标题长度
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