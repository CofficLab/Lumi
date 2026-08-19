import Foundation
import os
import KitLLM
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import SuperLogKit
import SwiftUI

/// 会话回复语言控制插件（中文 / English）。
///
/// 复刻自旧版 `Plugins/ConversationLanguagePlugin`：
/// - 在 Chat 分区工具栏注册语言 chip；
/// - 向 AgentLoop 注册消息准备钩子：注入瞬态 system 语言指令（不落库）。
@MainActor
public final class ConversationLanguagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-language", category: "ConversationLanguage")

    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.conversation-language"
    public let order = 83
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-language",
        name: "Conversation Language",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }

        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            hooks.addWillSendToLLMHook { [weak conversations] context in
                guard let conversations else { return context }
                let language = conversations.language(for: context.conversationID)
                let prompt: String
                switch language {
                case .chinese: prompt = "## 语言偏好\n请用中文回复用户。"
                case .english: prompt = "## Language Preference\nPlease respond in English."
                }
                var ctx = context
                ctx.messages = [LLMMessage(role: .system, content: prompt)] + ctx.messages
                return ctx
            }
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 83,
                placement: .toolbarTrailing
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
