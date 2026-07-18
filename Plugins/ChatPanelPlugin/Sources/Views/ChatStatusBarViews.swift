import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatTimelineStatusBarView: View {
    @ObservedObject private var chatService: ChatService

    init(chatService: ChatService) {
        self._chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        let conversationID = chatService.selectedConversationID
        let count = conversationID.map { chatService.messages(for: $0).count } ?? 0

        StatusBarHoverContainer(
            detailView: ChatTimelineDetailView(chatService: chatService),
            popoverWidth: 520,
            id: "chat-timeline"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "timeline.selection")
                    .font(.appMicroEmphasized)
                Text("\(count)")
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

private struct ChatTimelineDetailView: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService

    init(chatService: ChatService) {
        self._chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        let contextUsage = chatService.selectedConversationID.map {
            chatService.conversationContextUsage(for: $0)
        }

        StatusBarPopoverScaffold(
            title: "Conversation Timeline",
            systemImage: "timeline.selection",
            subtitle: timelineSubtitle(contextUsage: contextUsage),
            headerAccessory: { EmptyView() },
            content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if let conversationID = chatService.selectedConversationID {
                        ForEach(chatService.messages(for: conversationID).suffix(30)) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role.rawValue.capitalized)
                                    .font(.appCaptionEmphasized)
                                    .foregroundColor(theme.textSecondary)
                                Text(message.content)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(minHeight: 280, maxHeight: 420)
            },
            footer: { EmptyView() }
        )
    }

    private func timelineSubtitle(contextUsage: LumiConversationContextUsage?) -> String {
        guard let contextUsage, contextUsage.currentTokens > 0 else {
            return "Recent messages"
        }
        if contextUsage.limit > 0 {
            return "Context \(contextUsage.label)"
        }
        return "Context \(LumiConversationContextUsage.formatToken(contextUsage.currentTokens))"
    }
}

struct ChatAvailableToolsStatusBarView: View {
    let lumiCore: any LumiCoreAccessing

    var body: some View {
        let tools = buildTools()
        StatusBarHoverContainer(
            detailView: ChatAvailableToolsDetailView(tools: tools),
            popoverWidth: 620,
            id: "chat-available-tools"
        ) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.appMicroEmphasized)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }

    private func buildTools() -> [any LumiAgentTool] {
        let context = lumiCore.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core",
            chatSection: .none,
            showsRail: false,
            showsPanelChrome: false,
            isChatSectionVisible: nil,
            additionalDependencies: { _ in }
        )
        return lumiCore.agentToolComponent.buildToolSet(
            context: context,
            builtInTools: ChatService.builtInTools
        ).tools
    }
}

private struct ChatAvailableToolsDetailView: View {
    @LumiTheme private var theme
    let tools: [any LumiAgentTool]

    var body: some View {
        StatusBarPopoverScaffold(
            title: "Available Tools",
            systemImage: "wrench.and.screwdriver",
            subtitle: "\(tools.count) tools",
            headerAccessory: { EmptyView() },
            content: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(tools, id: \.name) { tool in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.name)
                                .font(.appMonoCaption)
                            Text(tool.toolDescription)
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        Divider()
                    }
                }
            }
            .frame(minHeight: 280, maxHeight: 420)
            },
            footer: { EmptyView() }
        )
    }
}
