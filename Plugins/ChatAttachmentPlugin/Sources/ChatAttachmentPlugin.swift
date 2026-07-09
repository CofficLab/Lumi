import LumiCoreKit
import LumiUI
import SwiftUI
import os

/// 聊天附件插件
///
/// 负责右侧栏中的待发送附件列表，以及右侧栏范围内的文件拖放入口。
public actor ChatAttachmentPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-attachment")

    public nonisolated static let emoji = "📎"
    public nonisolated static let verbose: Bool = true
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let id = "ChatAttachment"
    public static let displayName = LumiPluginLocalization.string("Chat Attachment", bundle: .module)
    public static let description = LumiPluginLocalization.string("Pending chat attachments and sidebar drop handling", bundle: .module)
    public static let iconName = "paperclip"
    public static let category: LumiPluginCategory = .agent
    public static let order = 94

    public static func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.showChat.isVisible else { return [] }
        return [AnyView(ChatAttachmentSectionView())]
    }

    public static func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView {
        guard context.showChat.isVisible else { return content }
        return AnyView(ChatAttachmentDropRootView(content: content))
    }

    public static func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.showChat.isVisible else { return [] }
        return [
            SidebarToolbarItem(
                id: "image-upload",
                title: LumiPluginLocalization.string("Upload Image", bundle: .module),
                systemImage: "photo",
                priority: 40
            )
        ]
    }

    public static func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "image-upload" else { return nil }
        return AnyView(ImageUploadToolbarButton())
    }
}

// MARK: - Toolbar Button View

/// 图片上传工具栏按钮
///
/// 弹出 NSOpenPanel 选择本地图片，添加到聊天附件。
private struct ImageUploadToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var conversationVM: WindowConversationVM

    public var body: some View {
        Button(action: {
            selectImage()
        }) {
            Image(systemName: "photo")
                .font(.appCallout)
                .foregroundColor(theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.textPrimary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .disabled(!conversationVM.canAttachToCurrentConversation)
        .help(LumiPluginLocalization.string("Upload Image", bundle: .module))
        .accessibilityLabel(LumiPluginLocalization.string("Upload Image", bundle: .module))
        .accessibilityHint(LumiPluginLocalization.string("Upload Image Hint", bundle: .module))
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                conversationVM.handleImageUpload(url: url)
            }
        }
    }
}
