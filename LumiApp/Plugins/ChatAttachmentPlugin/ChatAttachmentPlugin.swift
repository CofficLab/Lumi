import LumiUI
import SwiftUI
import os

/// 聊天附件插件
///
/// 负责右侧栏中的待发送附件列表，以及右侧栏范围内的文件拖放入口。
actor ChatAttachmentPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-attachment")

    nonisolated static let emoji = "📎"
    nonisolated static let verbose: Bool = true
    static let id = "ChatAttachment"
    static let displayName = String(localized: "Chat Attachment", table: "AgentChat")
    static let description = String(localized: "Pending chat attachments and sidebar drop handling", table: "AgentChat")
    static let iconName = "paperclip"
    static var category: PluginCategory { .agent }
    static var order: Int { 94 }
    nonisolated static let enable: Bool = true
    static let shared = ChatAttachmentPlugin()

    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [AnyView(ChatAttachmentSectionView())]
    }

    @MainActor func wrapRightSidebarRoot(_ content: AnyView, activeIcon: String?) -> AnyView {
        guard activeIcon == EditorPlugin.iconName else { return content }
        return AnyView(ChatAttachmentDropRootView(content: content))
    }

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "image-upload",
                title: String(localized: "Upload Image", table: "AgentChat"),
                systemImage: "photo",
                priority: 40
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
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

    @EnvironmentObject private var attachmentsVM: WindowAttachmentsVM

    var body: some View {
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
        .help(String(localized: "Upload Image", table: "AgentChat"))
        .accessibilityLabel(String(localized: "Upload Image", table: "AgentChat"))
        .accessibilityHint(String(localized: "Upload Image Hint", table: "AgentChat"))
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                attachmentsVM.handleImageUpload(url: url)
            }
        }
    }
}
