import LumiCoreKit
import SuperLogKit
import LumiUI
import SwiftUI
import os

/// 聊天附件插件
///
/// 负责右侧栏中的待发送附件列表，以及右侧栏范围内的文件拖放入口。
public actor ChatAttachmentPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.chat-attachment")

    public nonisolated static let emoji = "📎"
    public nonisolated static let verbose: Bool = true
    public static let id = "ChatAttachment"
    public static let displayName = String(localized: "Chat Attachment", table: "AgentChat")
    public static let description = String(localized: "Pending chat attachments and sidebar drop handling", table: "AgentChat")
    public static let iconName = "paperclip"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 94 }
    public static let shared = ChatAttachmentPlugin()

    @MainActor public func addSidebarSections(context: PluginContext) -> [AnyView] {
        guard context.supportsAIChat else { return [] }
        return [AnyView(ChatAttachmentSectionView())]
    }

    @MainActor public func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView {
        guard context.supportsAIChat else { return content }
        return AnyView(ChatAttachmentDropRootView(content: content))
    }

    // MARK: - Sidebar Toolbar

    @MainActor public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.supportsAIChat else { return [] }
        return [
            SidebarToolbarItem(
                id: "image-upload",
                title: String(localized: "Upload Image", table: "AgentChat"),
                systemImage: "photo",
                priority: 40
            )
        ]
    }

    @MainActor public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
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
                ChatAttachmentRuntime.handleImageUpload(url)
            }
        }
    }
}
