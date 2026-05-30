import PluginChatAttachment
import SwiftUI

actor ChatAttachmentPlugin: SuperPlugin {
    nonisolated static let logger = PluginChatAttachment.ChatAttachmentPlugin.logger
    nonisolated static let emoji = PluginChatAttachment.ChatAttachmentPlugin.emoji
    nonisolated static let verbose = PluginChatAttachment.ChatAttachmentPlugin.verbose
    static let id = PluginChatAttachment.ChatAttachmentPlugin.id
    static let displayName = PluginChatAttachment.ChatAttachmentPlugin.displayName
    static let description = PluginChatAttachment.ChatAttachmentPlugin.description
    static let iconName = PluginChatAttachment.ChatAttachmentPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginChatAttachment.ChatAttachmentPlugin.category) }
    static var order: Int { PluginChatAttachment.ChatAttachmentPlugin.order }
    static let shared = ChatAttachmentPlugin()

    private let packaged = PluginChatAttachment.ChatAttachmentPlugin.shared

    @MainActor
    func addSidebarSections(context: PluginContext) -> [AnyView] {
        packaged.addSidebarSections(context: context)
    }

    @MainActor
    func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView {
        guard context.supportsAIChat else { return content }
        return AnyView(ChatAttachmentRuntimeBridge(content: content))
    }

    @MainActor
    func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        packaged.addSidebarLeadingToolbarItems(context: context).map(SidebarToolbarItem.init(package:))
    }

    @MainActor
    func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        packaged.addSidebarToolbarItemView(itemId: itemId, context: context)
    }
}

@MainActor
private struct ChatAttachmentRuntimeBridge: View {
    let content: AnyView

    @EnvironmentObject private var attachmentsVM: WindowAttachmentsVM
    @EnvironmentObject private var chatDraftVM: WindowChatDraftVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @Environment(\.windowContainer) private var windowContainer

    var body: some View {
        PluginChatAttachment.ChatAttachmentDropRootView(content: content)
            .onAppear(perform: sync)
            .onChange(of: attachmentsVM.pendingAttachments) { _, _ in sync() }
            .onChange(of: conversationVM.selectedConversationId) { _, _ in sync() }
            .onFileDroppedToChat(windowId: windowContainer?.id) { fileURL in
                handleFileDrop(fileURL)
            }
            .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured)) { notification in
                if let currentId = windowContainer?.id {
                    guard let senderId = notification.userInfo?["windowId"] as? UUID,
                          senderId == currentId else {
                        return
                    }
                }
                guard let data = notification.userInfo?["data"] as? Data else { return }
                attachmentsVM.handleScreenshotData(data)
                sync()
            }
    }

    private func sync() {
        PluginChatAttachment.ChatAttachmentRuntime.pendingAttachmentsProvider = {
            attachmentsVM.pendingAttachments
        }
        PluginChatAttachment.ChatAttachmentRuntime.removeAttachment = { id in
            attachmentsVM.removeAttachment(id: id)
        }
        PluginChatAttachment.ChatAttachmentRuntime.handleImageUpload = { url in
            attachmentsVM.handleImageUpload(url: url)
        }
        PluginChatAttachment.ChatAttachmentRuntime.handleScreenshotData = { data in
            attachmentsVM.handleScreenshotData(data)
        }
        PluginChatAttachment.ChatAttachmentRuntime.appendDraftText = { text in
            chatDraftVM.append(text)
        }
        PluginChatAttachment.ChatAttachmentRuntime.canChatProvider = {
            conversationVM.selectedConversationId != nil
        }
    }

    private func handleFileDrop(_ fileURL: URL) {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
            attachmentsVM.handleImageUpload(url: fileURL)
        } else {
            chatDraftVM.append(fileURL.path)
        }
        sync()
    }
}
