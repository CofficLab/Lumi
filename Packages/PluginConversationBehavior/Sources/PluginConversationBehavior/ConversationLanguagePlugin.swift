import Foundation
import os
import KitLLM
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderLifecycleHooks
import ProviderToast
import LumiLoggingKit
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

    /// `willSendToLLM` 语言注入钩子（见 `Hooks/ConversationLanguageHook.swift`）。
    private var conversationLanguageHook: ConversationLanguageHook?
    private var conversationLanguageHookHandle: (any LifecycleHookHandle)?

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }

        conversationLanguageHookHandle?.cancel()
        conversationLanguageHookHandle = nil
        conversationLanguageHook = nil

        if let hooks = kernel.resolveProvider((any LifecycleHooksProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            let hook = ConversationLanguageHook(conversations: conversations)
            conversationLanguageHook = hook
            conversationLanguageHookHandle = hooks.addWillSendToLLMHook { [weak hook] context in
                guard let hook else { return context }
                return hook.apply(to: context)
            }
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 83,
                placement: .toolbarTrailing
            ) {
                LanguageToolbarView(
                    conversations: conversations,
                    toast: kernel.resolveProvider((any ToastProviding).self)
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        conversationLanguageHookHandle?.cancel()
        conversationLanguageHookHandle = nil
        conversationLanguageHook = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

/// 语言 chip：显示当前会话语言，点击切换。
struct LanguageToolbarView: View {
    let conversations: any ConversationManaging
    let toast: (any ToastProviding)?

    @State private var isPopoverPresented = false
    @State private var refreshToken = 0
    @State private var observer: (any ConversationObserverHandle)?

    init(conversations: any ConversationManaging, toast: (any ToastProviding)? = nil) {
        self.conversations = conversations
        self.toast = toast
    }

    private var selectedLanguage: ConversationLanguage {
        // 依赖 refreshToken：切换会话或语言偏好变化后必须重新读取，
        // 否则 chip 与弹窗会停留在上一个会话的语言（#846）。
        _ = refreshToken
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
                Text(pluginLocalization.string("Response Language"))
                    .font(.system(size: 12, weight: .semibold))
                ForEach(ConversationLanguage.allCases) { language in
                    Button {
                        select(language)
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
        .onAppear {
            // 与 ReasoningActionBarButton 一致：订阅会话事件驱动刷新。
            // 仅在切换会话/语言变化时 bump，避免无关事件触发重渲染。
            observer = conversations.addConversationObserver { event in
                switch event {
                case .providerChanged, .selected, .languageChanged, .created, .listChanged:
                    refreshToken += 1
                case .deleted, .updated, .markedActive, .verbosityChanged,
                     .automationChanged, .reasoningChanged:
                    break
                }
            }
        }
        .onDisappear {
            observer?.cancel()
            observer = nil
        }
    }

    func select(_ language: ConversationLanguage) {
        // 选中会话时只改该会话；只有 New Chat（无选中会话）才改全局默认值，
        // 否则调整一个已有会话会连带改掉之后新建会话的默认语言。
        if let conversationID = conversations.selectedConversationID {
            conversations.setLanguage(language, for: conversationID)
        } else {
            conversations.setGlobalLanguage(language)
        }
        ConversationBehaviorToast.show(
            toast,
            title: pluginLocalization.string("Response Language"),
            detail: language.shortCode,
        )
    }
}
