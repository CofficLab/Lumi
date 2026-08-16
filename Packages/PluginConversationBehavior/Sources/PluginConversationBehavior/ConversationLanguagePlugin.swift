import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderAgentLoop
import ProviderMessage
import SwiftUI

/// 会话回复语言控制插件（中文 / English）。
///
/// 复刻自旧版 `Plugins/ConversationLanguagePlugin`：
/// - 在 Chat 分区工具栏注册语言 chip；
/// - 向 AgentLoop 注册消息准备钩子：注入瞬态 system 语言指令（不落库）。
@MainActor
public final class ConversationLanguagePlugin: SuperPlugin {
    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-language"
    public let order = 83

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Conversation Language",
            description: "Response language preference (Chinese / English)",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            return
        }

        if let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) {
            agentLoop.addMessagePreparer { [weak conversations] messages in
                guard let conversations else { return messages }
                return await LanguagePreparer(conversations: conversations).prepare(messages)
            }
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 83,
                placement: .toolbarLeading
            ) {
                LanguageToolbarView(conversations: conversations)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

/// 语言消息准备器：注入瞬态 system 语言指令。
@MainActor
struct LanguagePreparer {
    private static let promptMarker = "languagePrompt"

    let conversations: any ConversationManaging

    func prepare(_ messages: [Message]) async -> [Message] {
        guard let conversationID = messages.first?.conversationID else { return messages }
        let language = conversations.language(for: conversationID)

        let withoutPreviousPrompt = messages.filter {
            $0.metadata[Self.promptMarker] != "true"
        }
        let prompt = Message(
            conversationID: conversationID,
            role: .system,
            content: Self.languagePrompt(for: language),
            metadata: [Self.promptMarker: "true"]
        )
        return [prompt] + withoutPreviousPrompt
    }

    static func languagePrompt(for language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return "## 语言偏好\n请用中文回复用户。"
        case .english:
            return "## Language Preference\nPlease respond in English."
        }
    }
}

/// 语言 chip：显示当前会话语言，点击切换。
struct LanguageToolbarView: View {
    let conversations: any ConversationManaging

    @State private var isPopoverPresented = false

    private var selectedLanguage: LumiConversationLanguage {
        if let id = conversations.selectedConversationID {
            return conversations.language(for: id)
        }
        return conversations.globalLanguage
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedLanguage.iconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(selectedLanguage.shortCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Response Language")
                    .font(.system(size: 12, weight: .semibold))
                ForEach(LumiConversationLanguage.allCases) { language in
                    Button {
                        if let conversationID = conversations.selectedConversationID {
                            conversations.setLanguage(language, for: conversationID)
                        }
                        conversations.setGlobalLanguage(language)
                        isPopoverPresented = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: language.iconName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(language == selectedLanguage ? .accentColor : .secondary)
                            Text(language.displayName)
                                .font(.system(size: 12))
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(language == selectedLanguage ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .frame(width: 200)
        }
    }
}
