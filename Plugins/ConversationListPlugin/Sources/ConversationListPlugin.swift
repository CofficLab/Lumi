import AppKit
import LumiKernel
import LumiUI
import SwiftUI
import os

@MainActor
public final class ConversationListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let name = "Conversation List"
    public let order = 76
    public let policy: LumiPluginPolicy = .alwaysOn

    public static let verbose = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    public init() {}

    public func onBoot(kernel: LumiKernel) throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 注册工具栏会话列表按钮
        let toolbarItem = TitleToolbarItem(
            id: "\(id).conversation-list",
            title: "Chats",
            placement: .trailing
        ) {
            ConversationListToolbarButton(kernel: kernel)
        }
        kernel.toolbarProvider?.registerTitleToolbarItem(toolbarItem)
    }


    // MARK: - Panel Rail Tab Items

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "chats",
                title: "Chats",
                systemImage: "message.fill"
            ) {
                ConversationRailView(kernel: kernel)
            },
        ]
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - Toolbar Button

/// 工具栏会话列表按钮
struct ConversationListToolbarButton: View {
    let kernel: LumiKernel
    @State private var isPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppIconButton(
                systemImage: "message.fill",
                label: LumiPluginLocalization.string("Chats", bundle: .module)
            ) {
                isPresented.toggle()
            }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                ConversationListPopoverContent(kernel: kernel)
                    .frame(width: 300, height: 480)
            }
        }
    }
}

// MARK: - Popover Content

/// 会话列表弹窗内容
struct ConversationListPopoverContent: View {
    let kernel: LumiKernel
    @State private var refreshTrigger = 0

    private static let notifications = Notification.Name("com.coffic.lumi.conversationsDidChange")

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        _ = refreshTrigger
        return conversations?.conversations ?? []
    }

    private var dataDirectory: URL? {
        conversations?.dataDirectory
    }

    private func openDataDirectory() {
        guard let url = dataDirectory else { return }
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        contentView
    }

    @ViewBuilder
    private var contentView: some View {
        if let conv = conversations {
            conversationListView(conv)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Conversations")
                .font(.headline)
            Text("Service not available")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private func conversationListView(_ conv: any ConversationManaging) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
                Button(action: openDataDirectory) {
                    Image(systemName: "folder")
                }
                .help("Open data directory")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            let list = conversationList
            if list.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(list) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        isProcessing: conv.isSending(for: conversation.id),
                        llmProvider: kernel.llmProvider,
                        isSelected: conv.selectedConversationID == conversation.id,
                        onSelect: {
                            conv.selectConversation(id: conversation.id)
                            refreshTrigger += 1
                        },
                        onDelete: {
                            conv.deleteConversation(id: conversation.id)
                            refreshTrigger += 1
                        }
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.notifications)) { _ in
            refreshTrigger += 1
        }
    }
}
